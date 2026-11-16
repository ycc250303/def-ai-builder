package com.def.plant.aiService.dto;

import java.time.OffsetDateTime;

/**
 * 历史消息，对应 ai_messages 及所属问答状态。
 * @param id 消息 UUID
 * @param turnId 所属问答 UUID
 * @param sequence 会话内问答顺序，用于分页
 * @param role USER、ASSISTANT 或 TOOL
 * @param content 已保存正文
 * @param status ACCEPTED、STREAMING、COMPLETED、FAILED、CANCELLED 或 INTERRUPTED
 * @param errorCode 失败原因，为空表示没有业务错误
 * @param createdAt 消息创建时间
 */
public record MessageResponse(String id, String turnId, long sequence, String role, String content,
        String status, String errorCode, OffsetDateTime createdAt) {
}
