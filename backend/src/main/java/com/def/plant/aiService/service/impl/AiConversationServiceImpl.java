package com.def.plant.aiService.service.impl;

import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.def.plant.aiService.config.AiProperties;
import com.def.plant.aiService.dto.ConversationRequest;
import com.def.plant.aiService.dto.ConversationResponse;
import com.def.plant.aiService.dto.MessageResponse;
import com.def.plant.aiService.dto.QuestionRequest;
import com.def.plant.aiService.entity.AiTurn;
import com.def.plant.aiService.mapper.AiMapper;
import com.def.plant.aiService.service.AiConversationService;
import com.def.plant.aiService.tools.PlantTools;
import com.def.plant.common.exception.BusinessException;
import com.def.plant.common.exception.ErrorCode;

/** 短事务内按会话加锁，统一去重、状态变更和消息保存。 */
@Service
public class AiConversationServiceImpl implements AiConversationService {
    private final AiMapper mapper;
    private final PlantTools plants;
    private final AiProperties properties;

    public AiConversationServiceImpl(AiMapper mapper, PlantTools plants, AiProperties properties) {
        this.mapper = mapper;
        this.plants = plants;
        this.properties = properties;
    }

    @Override
    @Transactional
    public ConversationResponse create(long userId, ConversationRequest request) {
        if (request == null) throw new BusinessException(ErrorCode.INVALID_AI_INPUT);
        if (request.plantId() != null) plants.get(userId, request.plantId());
        String title = request.title() == null ? "" : request.title().strip();
        if (title.codePointCount(0, title.length()) > 100) throw new BusinessException(ErrorCode.INVALID_AI_INPUT);
        if (title.isEmpty()) title = request.plantId() == null ? "养护问答" : "植物养护问答";
        String id = UUID.randomUUID().toString();
        mapper.create(id, userId, request.plantId() == null ? "GENERAL" : "PLANT", request.plantId(), title);
        return get(userId, id);
    }

    @Override
    public List<ConversationResponse> list(long userId, int offset, int limit) {
        page(offset, limit);
        return mapper.list(userId, offset, limit);
    }

    @Override
    public ConversationResponse get(long userId, String id) {
        ConversationResponse result = mapper.conversation(userId, uuid(id));
        if (result == null) throw new BusinessException(ErrorCode.AI_CONVERSATION_NOT_FOUND);
        return result;
    }

    @Override
    @Transactional
    public List<MessageResponse> messages(long userId, String id, long before, int limit) {
        page(0, limit);
        if (before < 1) throw new BusinessException(ErrorCode.INVALID_AI_INPUT);
        lock(userId, id);
        mapper.recover(userId, id);
        return mapper.messages(userId, id, before, limit);
    }

    @Override
    @Transactional
    public AiTurn turn(long userId, String id, String turnId) {
        lock(userId, id);
        mapper.recover(userId, id);
        return requireTurn(userId, id, turnId);
    }

    /**
     * 校验问题，恢复过期执行，按请求编号去重；同一会话仅创建一轮进行中的问答。
     * @param userId 已验证的用户编号
     * @param id 会话编号
     * @param request 问题和去重编号
     * @return 已保存问答及创建标记
     * @throws BusinessException 输入不合法、会话不存在、植物已删除、重复编号内容冲突或已有生成
     */
    @Override
    @Transactional
    public Accepted accept(long userId, String id, QuestionRequest request) {
        if (request == null || request.content() == null) throw new BusinessException(ErrorCode.INVALID_AI_INPUT);
        String requestId = uuid(request.requestId());
        String question = request.content().strip();
        if (question.isEmpty() || question.codePointCount(0, question.length()) > 4000) {
            throw new BusinessException(ErrorCode.INVALID_AI_INPUT);
        }
        ConversationResponse conversation = lock(userId, id);
        mapper.recover(userId, id);
        AiTurn existing = mapper.byRequest(userId, id, requestId);
        if (existing != null) {
            if (!existing.question().equals(question)) throw new BusinessException(ErrorCode.AI_REQUEST_CONFLICT);
            return new Accepted(existing, false);
        }
        if (conversation.scope().equals("PLANT")) {
            if (conversation.plantId() == null) throw new BusinessException(ErrorCode.PLANT_NOT_FOUND);
            plants.get(userId, conversation.plantId());
        }
        if (mapper.activeCount(userId, id) != 0) throw new BusinessException(ErrorCode.AI_CONVERSATION_BUSY);
        String turnId = UUID.randomUUID().toString();
        mapper.createTurn(turnId, id, requestId, UUID.randomUUID().toString(), properties.model());
        mapper.createMessage(UUID.randomUUID().toString(), turnId, 0, "USER", question);
        mapper.createMessage(UUID.randomUUID().toString(), turnId, 1, "ASSISTANT", "");
        mapper.touch(userId, id);
        return new Accepted(requireTurn(userId, id, turnId), true);
    }

    @Override
    public List<AiTurn> recent(long userId, String id) {
        get(userId, id);
        return mapper.recent(userId, id, properties.memoryTurns()).reversed();
    }

    /**
     * 在会话短事务中保存正文与状态，终态、过期或执行编号不一致时停止写入。
     * @param userId 已验证用户
     * @param turn 执行标识
     * @param content 完整累计正文
     * @param metadata JSON 扩展信息
     * @param status STREAMING 或终态
     * @param errorCode 可预期失败代号
     * @return 本次执行仍有效且保存成功
     */
    @Override
    @Transactional
    public boolean save(long userId, AiTurn turn, String content, String metadata, String status, String errorCode) {
        if (mapper.lock(userId, turn.conversationId()) == null) return false;
        mapper.recover(userId, turn.conversationId());
        AiTurn current = mapper.turn(userId, turn.conversationId(), turn.id());
        if (current == null || !current.active() || !current.runId().equals(turn.runId())) return false;
        mapper.saveContent(userId, turn.id(), content, metadata);
        if (mapper.transition(userId, turn.id(), turn.runId(), status, errorCode) != 1) {
            throw new IllegalStateException("问答状态未按执行编号更新");
        }
        return true;
    }

    @Override
    @Transactional
    public AiTurn cancel(long userId, String id, String turnId) {
        lock(userId, id);
        mapper.recover(userId, id);
        AiTurn turn = requireTurn(userId, id, turnId);
        if (turn.active()) mapper.transition(userId, turn.id(), turn.runId(), "CANCELLED", "AI_CANCELLED");
        return requireTurn(userId, id, turnId);
    }

    @Override
    @Transactional
    public void delete(long userId, String id) {
        lock(userId, id);
        if (mapper.delete(userId, id) != 1) throw new IllegalStateException("会话未删除");
    }

    private ConversationResponse lock(long userId, String id) {
        ConversationResponse conversation = mapper.lock(userId, uuid(id));
        if (conversation == null) throw new BusinessException(ErrorCode.AI_CONVERSATION_NOT_FOUND);
        return conversation;
    }

    private AiTurn requireTurn(long userId, String id, String turnId) {
        AiTurn turn = mapper.turn(userId, id, uuid(turnId));
        if (turn == null) throw new BusinessException(ErrorCode.AI_TURN_NOT_FOUND);
        return turn;
    }

    private static String uuid(String value) {
        if (value == null || !value.matches("[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}")) {
            throw new BusinessException(ErrorCode.INVALID_AI_INPUT);
        }
        return UUID.fromString(value).toString();
    }

    private static void page(int offset, int limit) {
        if (offset < 0 || offset > 10000 || limit < 1 || limit > 50) throw new BusinessException(ErrorCode.INVALID_AI_INPUT);
    }
}
