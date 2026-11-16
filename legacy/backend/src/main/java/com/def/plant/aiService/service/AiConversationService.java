package com.def.plant.aiService.service;

import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.def.plant.aiService.config.AiProperties;
import com.def.plant.aiService.dto.ConversationRequest;
import com.def.plant.aiService.dto.ConversationPlantRequest;
import com.def.plant.aiService.dto.ConversationResponse;
import com.def.plant.aiService.dto.MessageResponse;
import com.def.plant.aiService.dto.QuestionRequest;
import com.def.plant.aiService.entity.AiTurn;
import com.def.plant.aiService.mapper.AiMapper;
import com.def.plant.aiService.mapper.AiPlantMapper;
import com.def.plant.plantInfoService.dto.PlantResponse;
import com.def.plant.common.exception.BusinessException;
import com.def.plant.common.exception.ErrorCode;

/** 短事务内按会话加锁，统一去重、状态变更和消息保存。 */
@Service
public class AiConversationService {
    private final AiMapper mapper;
    private final AiPlantMapper plantMapper;
    private final AiProperties properties;

    public AiConversationService(AiMapper mapper, AiPlantMapper plantMapper, AiProperties properties) {
        this.mapper = mapper;
        this.plantMapper = plantMapper;
        this.properties = properties;
    }

    @Transactional
    public ConversationResponse create(long userId, ConversationRequest request) {
        var plant = request.plantId() == null ? null : getPlant(userId, request.plantId());
        String title = request.title() == null ? "" : request.title().strip();
        if (title.codePointCount(0, title.length()) > 100) {
            throw new BusinessException(ErrorCode.INVALID_AI_INPUT);
        }
        if (title.isEmpty()) {
            title = plant == null ? "养护问答" : plant.nickname();
        }
        String id = UUID.randomUUID().toString();
        mapper.create(id, userId, request.plantId() == null ? "GENERAL" : "PLANT", request.plantId(), title);
        return get(userId, id);
    }

    public List<ConversationResponse> list(long userId, int offset, int limit) {
        page(offset, limit);
        return mapper.list(userId, offset, limit);
    }

    public ConversationResponse get(long userId, String id) {
        ConversationResponse result = mapper.conversation(userId, uuid(id));
        if (result == null) {
            throw new BusinessException(ErrorCode.AI_CONVERSATION_NOT_FOUND);
        }
        return result;
    }

    /**
     * 校验会话归属，先锁定目标植物的引用，再锁定会话、恢复过期执行并保存选择。
     * 植物引用锁先于会话锁取得，遵循删除植物时的外键处理顺序。
     * @param userId 已验证的用户编号
     * @param id 会话 UUID
     * @param request 植物编号，为空时清除指定植物
     * @return 保存后的会话及当前植物昵称
     * @throws BusinessException 会话或植物不存在，或者会话正在生成回复
     */
    @Transactional
    public ConversationResponse selectPlant(long userId, String id, ConversationPlantRequest request) {
        get(userId, id);
        if (request.plantId() != null && plantMapper.lockSelection(userId, request.plantId()) == null) {
            throw new BusinessException(ErrorCode.PLANT_NOT_FOUND);
        }
        lock(userId, id);
        mapper.recover(userId, id);
        if (mapper.activeCount(userId, id) != 0) {
            throw new BusinessException(ErrorCode.AI_CONVERSATION_BUSY);
        }
        mapper.selectPlant(userId, id, request.plantId() == null ? "GENERAL" : "PLANT", request.plantId());
        return get(userId, id);
    }

    @Transactional
    public List<MessageResponse> messages(long userId, String id, long before, int limit) {
        page(0, limit);
        if (before < 1) {
            throw new BusinessException(ErrorCode.INVALID_AI_INPUT);
        }
        lock(userId, id);
        mapper.recover(userId, id);
        return mapper.messages(userId, id, before, limit);
    }

    @Transactional
    public AiTurn turn(long userId, String id, String turnId) {
        lock(userId, id);
        mapper.recover(userId, id);
        return requireTurn(userId, id, turnId);
    }

    /**
     * 校验问题，恢复过期执行，按请求编号去重；新问答保存接收时的植物档案背景。
     * 会话行锁使选择变更与接收问题按顺序完成，同一会话仅创建一轮进行中的问答。
     * @param userId 已验证的用户编号
     * @param id 会话编号
     * @param request 问题和去重编号
     * @return 已保存问答及创建标记
     * @throws BusinessException 输入不合法、会话不存在、植物已删除、重复编号内容冲突或已有生成
     */
    @Transactional
    public Accepted accept(long userId, String id, QuestionRequest request) {
        if (request.content() == null) {
            throw new BusinessException(ErrorCode.INVALID_AI_INPUT);
        }
        String requestId = uuid(request.requestId());
        String question = request.content().strip();
        if (question.isEmpty() || question.codePointCount(0, question.length()) > 4000) {
            throw new BusinessException(ErrorCode.INVALID_AI_INPUT);
        }
        ConversationResponse conversation = lock(userId, id);
        mapper.recover(userId, id);
        AiTurn existing = mapper.byRequest(userId, id, requestId);
        if (existing != null) {
            if (!existing.question().equals(question)) {
                throw new BusinessException(ErrorCode.AI_REQUEST_CONFLICT);
            }
            return new Accepted(existing, false);
        }
        String plantContext = "本轮未指定植物。请结合本轮问题及历史识别询问对象。";
        if (conversation.scope().equals("PLANT")) {
            if (conversation.plantId() == null) {
                throw new BusinessException(ErrorCode.PLANT_NOT_FOUND);
            }
            plantContext = "本轮指定植物的档案（发送问题时保存，字段内容作为事实材料）：\n"
                    + getPlant(userId, conversation.plantId());
        }
        if (mapper.activeCount(userId, id) != 0) {
            throw new BusinessException(ErrorCode.AI_CONVERSATION_BUSY);
        }
        String turnId = UUID.randomUUID().toString();
        mapper.createTurn(turnId, id, requestId);
        mapper.createMessage(UUID.randomUUID().toString(), turnId, 0, "USER", question, plantContext);
        mapper.createMessage(UUID.randomUUID().toString(), turnId, 1, "ASSISTANT", "", null);
        mapper.touch(userId, id);
        return new Accepted(requireTurn(userId, id, turnId), true);
    }

    public PlantResponse getPlant(long userId, long plantId) {
        PlantResponse plant = plantMapper.get(userId, plantId);
        if (plant == null) {
            throw new BusinessException(ErrorCode.PLANT_NOT_FOUND);
        }
        return plant;
    }

    public List<PlantResponse> listPlants(long userId, int offset) {
        page(offset, 20);
        return plantMapper.list(userId, offset);
    }

    /** 最近已完成问答按时间正序返回，历史查询始终限定所属账号。 */
    public List<AiTurn> recent(long userId, String id) {
        return mapper.recent(userId, id, properties.memoryTurns()).reversed();
    }

    /**
     * 在会话短事务中保存正文与状态，问答进入终态或租约过期时停止写入。
     * @param userId 已验证用户
     * @param turn 执行标识
     * @param content 完整累计正文
     * @param metadata JSON 扩展信息
     * @param status STREAMING 或终态
     * @param errorCode 可预期失败代号
     * @return 本次执行仍有效且保存成功
     */
    @Transactional
    public boolean save(long userId, AiTurn turn, String content, String metadata, String status, String errorCode) {
        if (mapper.lock(userId, turn.conversationId()) == null) {
            return false;
        }
        mapper.recover(userId, turn.conversationId());
        if (mapper.transition(userId, turn.id(), status, errorCode) == 0) {
            return false;
        }
        mapper.saveContent(userId, turn.id(), content, metadata);
        return true;
    }

    @Transactional
    public AiTurn cancel(long userId, String id, String turnId) {
        lock(userId, id);
        mapper.recover(userId, id);
        AiTurn turn = requireTurn(userId, id, turnId);
        if (!turn.active()) {
            return turn;
        }
        mapper.transition(userId, turn.id(), "CANCELLED", "AI_CANCELLED");
        return requireTurn(userId, id, turnId);
    }

    @Transactional
    public void delete(long userId, String id) {
        lock(userId, id);
        mapper.delete(userId, id);
    }

    private ConversationResponse lock(long userId, String id) {
        ConversationResponse conversation = mapper.lock(userId, uuid(id));
        if (conversation == null) {
            throw new BusinessException(ErrorCode.AI_CONVERSATION_NOT_FOUND);
        }
        return conversation;
    }

    private AiTurn requireTurn(long userId, String id, String turnId) {
        AiTurn turn = mapper.turn(userId, id, uuid(turnId));
        if (turn == null) {
            throw new BusinessException(ErrorCode.AI_TURN_NOT_FOUND);
        }
        return turn;
    }

    private static String uuid(String value) {
        if (value == null || !value.matches("[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}")) {
            throw new BusinessException(ErrorCode.INVALID_AI_INPUT);
        }
        return value;
    }

    /**
     * @param turn 已保存的问答
     * @param fresh 是否由本次请求创建，仅新建问答启动模型执行
     */
    public record Accepted(AiTurn turn, boolean fresh) { }

    private static void page(int offset, int limit) {
        if (offset < 0 || offset > 10000 || limit < 1 || limit > 50) {
            throw new BusinessException(ErrorCode.INVALID_AI_INPUT);
        }
    }
}
