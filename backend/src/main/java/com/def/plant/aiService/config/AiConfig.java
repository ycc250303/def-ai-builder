package com.def.plant.aiService.config;

import java.time.Duration;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.advisor.ToolCallingAdvisor;
import org.springframework.ai.model.tool.ToolCallingManager;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.ai.tool.execution.DefaultToolExecutionExceptionProcessor;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Lazy;
import io.micrometer.observation.ObservationRegistry;

/** 配置兼容 Chat Completions 的模型与工具调用循环。 */
@Configuration
@EnableConfigurationProperties(AiProperties.class)
public class AiConfig {
    /**
     * 问答请求首次使用时创建模型客户端，关闭自动重试并限制工具调用。
     * @param properties 后端模型配置
     * @return 无会话可变状态的模型调用客户端
     */
    @Bean
    @Lazy
    public ChatClient plantChatClient(AiProperties properties) {
        var model = OpenAiChatModel.builder().options(OpenAiChatOptions.builder()
                .baseUrl(properties.baseUrl()).apiKey(properties.apiKey()).model(properties.model())
                .maxTokens(properties.maxOutputTokens()).maxRetries(0)
                .timeout(Duration.ofSeconds(properties.timeoutSeconds())).build()).build();
        var manager = ToolCallingManager.builder().maxTotalToolCalls(5).maxCallsPerTool(5)
                .toolExecutionExceptionProcessor(new DefaultToolExecutionExceptionProcessor(true)).build();
        return ChatClient.builder(model, ObservationRegistry.NOOP, null, null,
                ToolCallingAdvisor.builder().toolCallingManager(manager)).build();
    }
}
