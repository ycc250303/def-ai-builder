package com.def.plant.aiService.dto;

/**
 * 新会话输入，归属由登录身份决定。
 * @param plantId 植物编号，为空时创建普通问答会话
 * @param title 会话名称，留空时使用默认名称，最多 100 字
 */
public record ConversationRequest(Long plantId, String title) {
}
