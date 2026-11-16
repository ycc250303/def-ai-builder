package com.def.plant.aiService.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 后端模型配置，密钥不进入字符串输出。
 * @param baseUrl 兼容 Chat Completions 的服务根地址
 * @param apiKey 仅后端读取的模型密钥
 * @param model 模型名称，必须使用供应商实际提供的名称
 * @param memoryTurns 每次读取的最近完整问答轮数，1 到 50
 * @param inputBudgetBytes 输入正文的保守 UTF-8 字节预算，包含消息开销预留
 * @param maxOutputTokens 单次模型回复 token 上限
 * @param timeoutSeconds 一轮生成的总超时秒数
 * @param maxConcurrent 全局同时生成数量
 */
@ConfigurationProperties("app.ai")
public record AiProperties(String baseUrl, String apiKey, String model, int memoryTurns,
        int inputBudgetBytes, int maxOutputTokens, int timeoutSeconds, int maxConcurrent) {
    public AiProperties {
        if (memoryTurns < 1 || memoryTurns > 50 || inputBudgetBytes < 1024 || maxOutputTokens < 1
                || timeoutSeconds < 1 || maxConcurrent < 1) {
            throw new IllegalArgumentException("AI 参数超出允许范围");
        }
    }
    @Override
    public String toString() { return "AiProperties[model=" + model + ", memoryTurns=" + memoryTurns + "]"; }
}
