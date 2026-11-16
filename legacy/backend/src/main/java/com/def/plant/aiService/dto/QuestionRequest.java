package com.def.plant.aiService.dto;

/**
 * 单次提问输入。
 * @param requestId 客户端 UUID，同一次提交重试时保持一致
 * @param content 问题正文，去除首尾空白后 1 到 4000 字
 */
public record QuestionRequest(String requestId, String content) {
    @Override
    public String toString() { return "QuestionRequest[requestId=" + requestId + "]"; }
}
