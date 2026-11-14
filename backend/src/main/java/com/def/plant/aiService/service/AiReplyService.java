package com.def.plant.aiService.service;

import java.io.IOException;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
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
    private final java.util.concurrent.ExecutorService workers = Executors.newVirtualThreadPerTaskExecutor();
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
        if (!capacity.tryAcquire()) throw new BusinessException(ErrorCode.AI_CAPACITY_EXCEEDED);
        AiConversationService.Accepted accepted;
        try { accepted = conversations.accept(userId, id, request); }
        catch (RuntimeException exception) { capacity.release(); throw exception; }
        SseEmitter emitter = new SseEmitter((properties.timeoutSeconds() + 10L) * 1000);
        Run run = new Run(userId, accepted.turn(), emitter);
        emitter.onCompletion(() -> disconnect(run));
        emitter.onTimeout(() -> stop(run, ErrorCode.AI_TIMEOUT, "FAILED"));
        emitter.onError(error -> disconnect(run));
        if (accepted.fresh()) runs.put(run.turn.id(), run);
        workers.submit(() -> execute(run, accepted.fresh()));
        return emitter;
    }

    private void execute(Run run, boolean fresh) {
        run.thread = Thread.currentThread();
        try {
            if (run.stopping.get()) return;
            event(run, "accepted", Map.of("turnId", run.turn.id(), "conversationId", run.turn.conversationId(),
                    "assistantMessageId", run.turn.assistantMessageId()));
            if (!fresh) {
                event(run, run.turn.status().equals("COMPLETED") ? "done" : "snapshot", run.turn);
                return;
            }
            try (var responses = agent.stream(run.userId, run.turn).toStream(1)) {
                var iterator = responses.iterator();
                while (iterator.hasNext()) {
                    if (run.stopping.get()) return;
                    ChatResponse response = iterator.next();
                    if (response.getResult() != null) {
                        String reason = response.getResult().getMetadata().getFinishReason();
                        if (reason != null && !reason.isBlank()) run.finishReason = reason;
                        String text = response.getResult().getOutput().getText();
                        if (text != null && !text.isEmpty()) {
                            synchronized (run) { run.text.append(text); }
                            if (run.text.length() > 200000) throw new BusinessException(ErrorCode.AI_OUTPUT_INCOMPLETE);
                            if (System.nanoTime() - run.lastSave > Duration.ofMillis(500).toNanos()) {
                                if (!save(run, "STREAMING", null)) {
                                    event(run, "snapshot", conversations.turn(run.userId, run.turn.conversationId(), run.turn.id()));
                                    return;
                                }
                                run.lastSave = System.nanoTime();
                            }
                            event(run, "delta", Map.of("turnId", run.turn.id(), "sequence", ++run.sequence, "text", text));
                        }
                    }
                    var usage = response.getMetadata().getUsage();
                    if (usage != null && usage.getTotalTokens() > 0) {
                        run.metadata = encode(Map.of("model", properties.model(), "promptVersion", "plant-care-v1",
                                "inputTokens", usage.getPromptTokens(), "outputTokens", usage.getCompletionTokens()));
                    }
                }
            }
            if (run.stopping.get()) return;
            if (!"stop".equalsIgnoreCase(run.finishReason) || run.text.isEmpty()) {
                throw new BusinessException(ErrorCode.AI_OUTPUT_INCOMPLETE);
            }
            if (save(run, "COMPLETED", null)) {
                event(run, "done", Map.of("turnId", run.turn.id(), "status", "COMPLETED", "content", run.content()));
            } else {
                event(run, "snapshot", conversations.turn(run.userId, run.turn.conversationId(), run.turn.id()));
            }
        }
        catch (Exception exception) {
            if (!run.stopping.get()) {
                ErrorCode code = classify(exception);
                if (code == null) {
                    log.error("问答执行缺陷: turnId={}", run.turn.id(), exception);
                    fail(run, "AI_INTERNAL_ERROR", "回复生成出现内部错误");
                } else {
                    log.warn("问答执行终止: turnId={}, code={}", run.turn.id(), code.code());
                    fail(run, code.code(), code.detail());
                }
            }
        }
        finally {
            run.finished.set(true);
            runs.remove(run.turn.id(), run);
            capacity.release();
            run.emitter.complete();
        }
    }

    private ErrorCode classify(Exception exception) {
        boolean upstream = false;
        for (Throwable cause = exception; cause != null; cause = cause.getCause()) {
            if (cause instanceof BusinessException business) return business.errorCode();
            if (cause instanceof DataAccessException) return ErrorCode.DATA_STORE_UNAVAILABLE;
            if (cause instanceof TimeoutException || cause instanceof java.io.InterruptedIOException) return ErrorCode.AI_TIMEOUT;
            if (cause instanceof OpenAIException || cause instanceof IOException) upstream = true;
        }
        return upstream ? ErrorCode.AI_UPSTREAM_FAILED : null;
    }

    private void fail(Run run, String code, String detail) {
        try {
            save(run, "FAILED", code);
            event(run, "error", Map.of("turnId", run.turn.id(), "code", code, "detail", detail, "content", run.content()));
        }
        catch (Exception persistenceOrTransportError) {
            log.error("问答失败状态或事件无法保存: turnId={}", run.turn.id(), persistenceOrTransportError);
            run.emitter.completeWithError(persistenceOrTransportError);
        }
    }

    private boolean save(Run run, String status, String code) {
        return conversations.save(run.userId, run.turn, run.content(), run.metadata, status, code);
    }

    private void event(Run run, String name, Object data) throws IOException {
        synchronized (run.outputLock) {
            if (run.terminalSent) return;
            if (name.equals("done") || name.equals("error") || name.equals("snapshot")) run.terminalSent = true;
            run.emitter.send(SseEmitter.event().name(name).data(data, MediaType.APPLICATION_JSON));
        }
    }

    /** 显式取消先持久化终态，再终止当前实例上的上游订阅。 */
    public AiTurn cancel(long userId, String id, String turnId) {
        AiTurn current = conversations.turn(userId, id, turnId);
        Run run = runs.get(turnId);
        if (run != null && current.active()) stop(run, ErrorCode.AI_CANCELLED, "CANCELLED");
        return conversations.cancel(userId, id, turnId);
    }

    public void delete(long userId, String id) {
        conversations.delete(userId, id);
        runs.values().stream().filter(run -> run.userId == userId && run.turn.conversationId().equals(id))
                .forEach(run -> stop(run, ErrorCode.AI_CANCELLED, "CANCELLED"));
    }

    private void disconnect(Run run) {
        if (!run.finished.get()) stop(run, ErrorCode.AI_CANCELLED, "CANCELLED");
    }

    private void stop(Run run, ErrorCode code, String status) {
        if (run.finished.get() || !run.stopping.compareAndSet(false, true)) return;
        try {
            if (save(run, status, code.code())) {
                event(run, "error", Map.of("turnId", run.turn.id(), "code", code.code(), "detail", code.detail()));
            } else {
                try {
                    AiTurn current = conversations.turn(run.userId, run.turn.conversationId(), run.turn.id());
                    event(run, current.status().equals("COMPLETED") ? "done" : "snapshot", current);
                } catch (BusinessException deleted) {
                    if (deleted.errorCode() != ErrorCode.AI_CONVERSATION_NOT_FOUND) throw deleted;
                    event(run, "error", Map.of("turnId", run.turn.id(), "code", code.code(), "detail", code.detail()));
                }
            }
        }
        catch (Exception exception) {
            run.emitter.completeWithError(exception);
        }
        finally {
            Thread thread = run.thread;
            if (thread != null && thread != Thread.currentThread()) thread.interrupt();
        }
    }

    private void heartbeat() {
        for (Run run : runs.values()) {
            try {
                if (System.nanoTime() - run.started > Duration.ofSeconds(properties.timeoutSeconds()).toNanos()) {
                    stop(run, ErrorCode.AI_TIMEOUT, "FAILED");
                } else if (mapper.renew(run.userId, run.turn.id(), run.turn.runId()) == 0) {
                    stop(run, ErrorCode.AI_CANCELLED, "CANCELLED");
                } else {
                    synchronized (run.outputLock) {
                        if (!run.terminalSent) run.emitter.send(SseEmitter.event().comment("heartbeat"));
                    }
                }
            }
            catch (Exception exception) {
                boolean storage = exception instanceof DataAccessException;
                stop(run, storage ? ErrorCode.DATA_STORE_UNAVAILABLE : ErrorCode.AI_CANCELLED, storage ? "FAILED" : "CANCELLED");
            }
        }
    }

    private String encode(Object data) {
        try { return json.writeValueAsString(data); }
        catch (JsonProcessingException exception) { throw new IllegalStateException("问答元数据序列化失败", exception); }
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
        volatile String metadata = "{}";
        long lastSave;
        int sequence;
        String finishReason;
        Run(long userId, AiTurn turn, SseEmitter emitter) {
            this.userId = userId; this.turn = turn; this.emitter = emitter;
        }
        synchronized String content() { return text.toString(); }
    }
}
