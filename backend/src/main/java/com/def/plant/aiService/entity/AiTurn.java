package com.def.plant.aiService.entity;

/**
 * 问答执行记录，联合 ai_turns 和该轮用户、助手消息读取。
 * @param id 问答 UUID，对应 ai_turns.id
 * @param conversationId 会话 UUID，对应 ai_turns.conversation_id
 * @param requestId 客户端去重 UUID，对应 ai_turns.request_id，同一会话内唯一
 * @param status 对应 ai_turns.status；活动状态为 ACCEPTED、STREAMING，终态为 COMPLETED、FAILED、CANCELLED、INTERRUPTED
 * @param errorCode 失败或中断原因，对应 ai_turns.error_code，正常完成时为空
 * @param question 本轮用户消息正文，对应序号为 0 的 ai_messages.content
 * @param content 已保存的助手正文，对应序号为 1 的 ai_messages.content
 * @param assistantMessageId 助手消息 UUID，对应 ai_messages.id
 * @param sequence 会话内递增问答编号，对应 ai_turns.sequence，从 1 开始
 */
public record AiTurn(String id, String conversationId, String requestId,
        String status, String errorCode, String question, String content, String assistantMessageId, long sequence) {
    public boolean active() { return status.equals("ACCEPTED") || status.equals("STREAMING"); }
}
