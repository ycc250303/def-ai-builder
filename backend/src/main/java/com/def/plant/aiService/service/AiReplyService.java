package com.def.plant.aiService.service;

import java.io.IOException;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicBoolean;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.model.ChatResponse;
import org.springframework.dao.DataAccessException;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import com.def.plant.aiService.agent.PlantCareAgent;
import com.def.plant.aiService.config.AiProperties;
import com.def.plant.aiService.dto.QuestionRequest;
import com.def.plant.aiService.entity.AiTurn;
import com.def.plant.aiService.mapper.AiMapper;
import com.def.plant.common.exception.BusinessException;
import com.def.plant.common.exception.ErrorCode;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.openai.errors.OpenAIException;
import com.openai.errors.OpenAIServiceException;

import jakarta.annotation.PreDestroy;

/**
 * 流式回复生命周期。内存只保存当前执行句柄和文本缓冲，跨请求上下文从数据库读取。
 * 每次执行持有服务并发名额，取消、失败和正常结束均释放。
 */
@Service
public class AiReplyService {
    private static final Logger log = LoggerFactory.getLogger(AiReplyService.class);
    private final AiConversationService conversations;
    private final AiMapper mapper;
    private final PlantCareAgent agent;
    private final AiProperties properties;
    private final Semaphore capacity;
    private final ExecutorService workers = Executors.newVirtualThreadPerTaskExecutor();
    private final ScheduledExecutorService timer = Executors.newSingleThreadScheduledExecutor();
    private final Map<String, Run> runs = new ConcurrentHashMap<>();
    private final ObjectMapper json = new ObjectMapper();

    public AiReplyService(AiConversationService conversations, AiMapper mapper, PlantCareAgent agent, AiProperties properties) {
        this.conversations = conversations;
        this.mapper = mapper;
        this.agent = agent;
        this.properties = properties;
        this.capacity = new Semaphore(properties.maxConcurrent());
        timer.scheduleWithFixedDelay(this::heartbeat, 1, 1, TimeUnit.SECONDS);
    }

    /**
     * 校验配置与会话，在数据库接收问题后启动一次流式执行。重复提交只回放已保存状态。
     * @param userId 已通过令牌校验的用户身份
     * @param id 会话 UUID
     * @param request 提问和去重 UUID
     * @return accepted、delta、done、snapshot 或 error 事件流
     * @throws BusinessException 配置缺失、容量已满、输入或归属不合法
     */
    public SseEmitter reply(long userId, String id, QuestionRequest request) {
        agent.requireConfigured();
        if (!capacity.tryAcquire()) {
            throw new BusinessException(ErrorCode.AI_CAPACITY_EXCEEDED);
        }
        AiConversationService.Accepted accepted;
        try {
            accepted = conversations.accept(userId, id, request);
        } catch (RuntimeException exception) {
            capacity.release();
            throw exception;
        }
        SseEmitter emitter = new SseEmitter((properties.timeoutSeconds() + 10L) * 1000);
        Run run = new Run(userId, accepted.turn(), emitter, encode(Map.of("model", properties.model())));
        if (accepted.fresh()) {
            emitter.onCompletion(() -> stop(run, ErrorCode.AI_CANCELLED, "CANCELLED"));
            emitter.onTimeout(() -> stop(run, ErrorCode.AI_TIMEOUT, "FAILED"));
            emitter.onError(error -> stop(run, ErrorCode.AI_CANCELLED, "CANCELLED"));
            runs.put(run.turn.id(), run);
        }
        workers.submit(() -> execute(run, accepted.fresh()));
        return emitter;
    }

    private void execute(Run run, boolean fresh) {
        run.thread = Thread.currentThread();
        try {
            if (run.stopping.get()) {
                return;
            }
            event(run, "accepted", Map.of("turnId", run.turn.id(), "conversationId", run.turn.conversationId(),
                    "assistantMessageId", run.turn.assistantMessageId()));
            if (!fresh) {
                replay(run, run.turn);
                return;
            }
            try (var responses = agent.stream(run.userId, run.turn).toStream(1)) {
                var iterator = responses.iterator();
                while (iterator.hasNext()) {
                    if (run.stopping.get()) {
                        return;
                    }
                    if (!receive(run, iterator.next())) {
                        return;
                    }
                }
            }
            if (run.stopping.get()) {
                return;
            }
            if (!"stop".equalsIgnoreCase(run.finishReason) || run.text.isEmpty()) {
                throw new BusinessException(ErrorCode.AI_OUTPUT_INCOMPLETE);
            }
            if (save(run, "COMPLETED", null)) {
                event(run, "done", Map.of("turnId", run.turn.id(), "status", "COMPLETED", "content", run.content()));
            } else {
                replay(run, conversations.turn(run.userId, run.turn.conversationId(), run.turn.id()));
            }
        } catch (Exception exception) {
            if (!fresh) {
                run.emitter.completeWithError(exception);
            } else if (!run.stopping.get()) {
                ErrorCode code = classify(exception, run.turn.id());
                if (code == null) {
                    log.error("问答执行缺陷: turnId={}", run.turn.id(), exception);
                    fail(run, "AI_INTERNAL_ERROR", "回复生成出现内部错误");
                } else {
                    log.warn("问答执行终止: turnId={}, code={}", run.turn.id(), code.code());
                    fail(run, code.code(), code.detail());
                }
            }
        } finally {
            run.finished.set(true);
            runs.remove(run.turn.id(), run);
            capacity.release();
            run.emitter.complete();
        }
    }

    /** 接收一个模型片段，累计正文、定期保存进度，并记录供应商用量。 */
    private boolean receive(Run run, ChatResponse response) throws IOException {
        // 用量帧可以只有 metadata，没有文本候选。
        var result = response.getResult();
        if (result != null) {
            String reason = result.getMetadata().getFinishReason();
            if (reason != null && !reason.isBlank()) {
                run.finishReason = reason;
            }
            String text = result.getOutput().getText();
            if (text != null && !text.isEmpty()) {
                run.append(text);
                if (System.nanoTime() - run.lastSave > Duration.ofMillis(500).toNanos()) {
                    if (!save(run, "STREAMING", null)) {
                        replay(run, conversations.turn(run.userId, run.turn.conversationId(), run.turn.id()));
                        return false;
                    }
                    run.lastSave = System.nanoTime();
                }
                event(run, "delta", Map.of("turnId", run.turn.id(), "sequence", ++run.sequence, "text", text));
            }
        }
        var usage = response.getMetadata().getUsage();
        if (usage != null && usage.getTotalTokens() > 0) {
            run.metadata = encode(Map.of("model", properties.model(),
                    "inputTokens", usage.getPromptTokens(), "outputTokens", usage.getCompletionTokens()));
        }
        return true;
    }

    private void replay(Run run, AiTurn saved) throws IOException {
        event(run, saved.status().equals("COMPLETED") ? "done" : "snapshot", saved);
    }

    /** 按异常原因识别上游拒绝，日志只记录状态与执行编号，不转发任意上游正文。 */
    private ErrorCode classify(Exception exception, String turnId) {
        boolean upstream = false;
        for (Throwable cause = exception; cause != null; cause = cause.getCause()) {
            if (cause instanceof BusinessException business) {
                return business.errorCode();
            }
            if (cause instanceof DataAccessException) {
                return ErrorCode.DATA_STORE_UNAVAILABLE;
            }
            if (cause instanceof TimeoutException || cause instanceof java.io.InterruptedIOException) {
                return ErrorCode.AI_TIMEOUT;
            }
            if (cause instanceof OpenAIServiceException response) {
                log.warn("模型服务响应异常: turnId={}, status={}", turnId, response.statusCode());
            }
            if (cause instanceof OpenAIException || cause instanceof IOException) {
                upstream = true;
            }
        }
        return upstream ? ErrorCode.AI_UPSTREAM_FAILED : null;
    }

    private void fail(Run run, String code, String detail) {
        try {
            if (save(run, "FAILED", code)) {
                event(run, "error", Map.of("turnId", run.turn.id(), "code", code, "detail", detail, "content", run.content()));
            } else {
                replay(run, conversations.turn(run.userId, run.turn.conversationId(), run.turn.id()));
            }
        } catch (Exception persistenceOrTransportError) {
            log.error("问答失败状态或事件无法保存: turnId={}", run.turn.id(), persistenceOrTransportError);
            run.emitter.completeWithError(persistenceOrTransportError);
        }
    }

    private boolean save(Run run, String status, String code) {
        return conversations.save(run.userId, run.turn, run.content(), run.metadata, status, code);
    }

    private void event(Run run, String name, Object data) throws IOException {
        synchronized (run.outputLock) {
            if (run.terminalSent) {
                return;
            }
            if (name.equals("done") || name.equals("error") || name.equals("snapshot")) {
                run.terminalSent = true;
            }
            run.emitter.send(SseEmitter.event().name(name).data(data, MediaType.APPLICATION_JSON));
        }
    }

    /** 显式取消先持久化终态，再终止当前实例上的上游订阅。 */
    public AiTurn cancel(long userId, String id, String turnId) {
        AiTurn saved = conversations.cancel(userId, id, turnId);
        Run run = runs.get(turnId);
        if (run != null) {
            stop(run, ErrorCode.AI_CANCELLED, "CANCELLED");
        }
        return saved;
    }

    public void delete(long userId, String id) {
        conversations.delete(userId, id);
        runs.values().stream().filter(run -> run.userId == userId && run.turn.conversationId().equals(id))
                .forEach(run -> stop(run, ErrorCode.AI_CANCELLED, "CANCELLED"));
    }

    private void stop(Run run, ErrorCode code, String status) {
        if (run.finished.get() || !run.stopping.compareAndSet(false, true)) {
            return;
        }
        try {
            if (save(run, status, code.code())) {
                event(run, "error", Map.of("turnId", run.turn.id(), "code", code.code(), "detail", code.detail()));
            } else {
                try {
                    AiTurn current = conversations.turn(run.userId, run.turn.conversationId(), run.turn.id());
                    replay(run, current);
                } catch (BusinessException deleted) {
                    if (deleted.errorCode() != ErrorCode.AI_CONVERSATION_NOT_FOUND) {
                        throw deleted;
                    }
                    event(run, "error", Map.of("turnId", run.turn.id(), "code", code.code(), "detail", code.detail()));
                }
            }
        } catch (Exception exception) {
            run.emitter.completeWithError(exception);
        } finally {
            Thread thread = run.thread;
            if (thread != null && thread != Thread.currentThread()) {
                thread.interrupt();
            }
        }
    }

    private void heartbeat() {
        for (Run run : runs.values()) {
            try {
                if (System.nanoTime() - run.started > Duration.ofSeconds(properties.timeoutSeconds()).toNanos()) {
                    stop(run, ErrorCode.AI_TIMEOUT, "FAILED");
                } else if (mapper.renew(run.userId, run.turn.id()) == 0) {
                    stop(run, ErrorCode.AI_CANCELLED, "CANCELLED");
                } else {
                    synchronized (run.outputLock) {
                        if (!run.terminalSent) {
                            run.emitter.send(SseEmitter.event().comment("heartbeat"));
                        }
                    }
                }
            } catch (DataAccessException exception) {
                log.error("问答租约续期失败: turnId={}", run.turn.id(), exception);
                stop(run, ErrorCode.DATA_STORE_UNAVAILABLE, "FAILED");
            } catch (IOException exception) {
                stop(run, ErrorCode.AI_CANCELLED, "CANCELLED");
            } catch (RuntimeException exception) {
                log.error("问答心跳执行缺陷: turnId={}", run.turn.id(), exception);
                if (run.stopping.compareAndSet(false, true)) {
                    fail(run, "AI_INTERNAL_ERROR", "回复生成出现内部错误");
                    Thread thread = run.thread;
                    if (thread != null) {
                        thread.interrupt();
                    }
                }
            }
        }
    }

    private String encode(Object data) {
        try {
            return json.writeValueAsString(data);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("问答元数据序列化失败", exception);
        }
    }

    @PreDestroy
    public void close() {
        runs.values().forEach(run -> stop(run, ErrorCode.AI_INTERRUPTED, "INTERRUPTED"));
        timer.shutdownNow();
        workers.shutdownNow();
    }

    private static final class Run {
        final long userId;
        final AiTurn turn;
        final SseEmitter emitter;
        final StringBuilder text = new StringBuilder();
        final Object outputLock = new Object();
        boolean terminalSent;
        final AtomicBoolean finished = new AtomicBoolean();
        final AtomicBoolean stopping = new AtomicBoolean();
        final long started = System.nanoTime();
        volatile Thread thread;
        volatile String metadata;
        long lastSave;
        int sequence;
        String finishReason;
        Run(long userId, AiTurn turn, SseEmitter emitter, String metadata) {
            this.userId = userId;
            this.turn = turn;
            this.emitter = emitter;
            this.metadata = metadata;
        }

        synchronized void append(String fragment) {
            text.append(fragment);
        }

        synchronized String content() {
            return text.toString();
        }
    }
}
