package com.def.plant.aiService.entity;

/**
 * 问答执行记录，联合 ai_turns 和该轮用户、助手消息读取。
 * @param id 问答 UUID，对应 ai_turns.id
 * @param conversationId 会话 UUID
 * @param requestId 客户端去重 UUID
 * @param runId 服务端执行 UUID
 * @param status 问答状态，终态不可继续生成
 * @param errorCode 失败或中断原因
 * @param question 本轮用户消息正文
 * @param content 已保存的助手正文
 * @param assistantMessageId 助手消息 UUID
 * @param sequence 会话内递增问答编号
 */
public record AiTurn(String id, String conversationId, String requestId, String runId,
        String status, String errorCode, String question, String content, String assistantMessageId, long sequence) {
    public boolean active() { return status.equals("ACCEPTED") || status.equals("STREAMING"); }
}
