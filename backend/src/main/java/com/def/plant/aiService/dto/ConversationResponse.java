package com.def.plant.aiService.dto;

import java.time.OffsetDateTime;

/**
 * 会话展示信息，对应 ai_conversations。
 * @param id 服务端生成的 UUID
 * @param scope GENERAL 普通问答，PLANT 指定植物问答
 * @param plantId 关联植物编号，删除植物后为空
 * @param title 会话名称
 * @param createdAt 创建时间
 * @param updatedAt 最近提问时间
 */
public record ConversationResponse(String id, String scope, Long plantId, String title,
        OffsetDateTime createdAt, OffsetDateTime updatedAt) {
}
