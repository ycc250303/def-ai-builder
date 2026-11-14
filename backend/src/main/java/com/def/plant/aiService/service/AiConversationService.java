package com.def.plant.aiService.service;

import java.util.List;

import com.def.plant.aiService.dto.ConversationRequest;
import com.def.plant.aiService.dto.ConversationResponse;
import com.def.plant.aiService.dto.MessageResponse;
import com.def.plant.aiService.dto.QuestionRequest;
import com.def.plant.aiService.entity.AiTurn;

/** 受登录身份约束的会话、消息与问答状态管理。 */
public interface AiConversationService {
    ConversationResponse create(long userId, ConversationRequest request);
    List<ConversationResponse> list(long userId, int offset, int limit);
    ConversationResponse get(long userId, String id);
    List<MessageResponse> messages(long userId, String id, long before, int limit);
    AiTurn turn(long userId, String id, String turnId);
    Accepted accept(long userId, String id, QuestionRequest request);
    List<AiTurn> recent(long userId, String id);
    boolean save(long userId, AiTurn turn, String content, String metadata, String status, String errorCode);
    AiTurn cancel(long userId, String id, String turnId);
    void delete(long userId, String id);

    /** @param turn 已保存的问答 @param fresh 是否由本次请求创建 */
    record Accepted(AiTurn turn, boolean fresh) { }
}
