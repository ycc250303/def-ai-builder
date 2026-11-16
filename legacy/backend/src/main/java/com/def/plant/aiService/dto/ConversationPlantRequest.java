package com.def.plant.aiService.dto;

/**
 * 会话当前指定植物输入，植物归属由登录身份校验。
 * @param plantId 当前账号的植物编号，为空时切换为通用问答
 */
public record ConversationPlantRequest(Long plantId) {
}
