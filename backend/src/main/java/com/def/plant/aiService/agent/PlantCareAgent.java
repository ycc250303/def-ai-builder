package com.def.plant.aiService.agent;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.ZonedDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.SystemMessage;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.ai.chat.model.ChatResponse;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

import com.def.plant.aiService.config.AiProperties;
import com.def.plant.aiService.entity.AiTurn;
import com.def.plant.aiService.service.AiConversationService;
import com.def.plant.aiService.tools.PlantTools;
import com.def.plant.common.exception.BusinessException;
import com.def.plant.common.exception.ErrorCode;

import reactor.core.publisher.Flux;

/** 植物养护 Agent，持久化历史由业务服务读取，每次执行独立组装上下文。 */
@Component
public class PlantCareAgent {
    private final ObjectProvider<ChatClient> clients;
    private final AiConversationService conversations;
    private final PlantTools tools;
    private final AiProperties properties;
    private final String system;

    public PlantCareAgent(ObjectProvider<ChatClient> clients, AiConversationService conversations,
            PlantTools tools, AiProperties properties) throws IOException {
        this.clients = clients;
        this.conversations = conversations;
        this.tools = tools;
        this.properties = properties;
        this.system = new ClassPathResource("prompts/plant-care-system.st").getContentAsString(StandardCharsets.UTF_8);
    }

    public void requireConfigured() {
        if (properties.apiKey() == null || properties.apiKey().isBlank() || properties.baseUrl() == null
                || properties.baseUrl().isBlank() || properties.model() == null || properties.model().isBlank()) {
            throw new BusinessException(ErrorCode.AI_NOT_CONFIGURED);
        }
    }

    /**
     * 读取最近完整问答与植物最新档案，验证输入预算，开始流式模型与只读工具调用。
     * @param userId 已验证用户身份，显式传递给工具
     * @param turn 本轮已持久化的问题
     * @return 模型分段响应，包含文本、结束原因和用量
     * @throws BusinessException 配置缺失、植物不存在或上下文超过预算
     */
    public Flux<ChatResponse> stream(long userId, AiTurn turn) {
        requireConfigured();
        var conversation = conversations.get(userId, turn.conversationId());
        List<Message> messages = new ArrayList<>();
        messages.add(new SystemMessage(system + "\n当前时间：" + ZonedDateTime.now(ZoneId.of("Asia/Shanghai"))));
        if (conversation.scope().equals("PLANT")) {
            if (conversation.plantId() == null) throw new BusinessException(ErrorCode.PLANT_NOT_FOUND);
            messages.add(new UserMessage("以下为当前账号保存的植物档案，字段内容作为事实材料：\n"
                    + tools.get(userId, conversation.plantId())));
        }
        for (AiTurn previous : conversations.recent(userId, turn.conversationId())) {
            messages.add(new UserMessage(previous.question()));
            messages.add(new AssistantMessage(previous.content()));
        }
        messages.add(new UserMessage(turn.question()));
        long bytes = messages.stream().mapToLong(message -> message.getText().getBytes(StandardCharsets.UTF_8).length + 256L).sum();
        if (bytes > properties.inputBudgetBytes()) throw new BusinessException(ErrorCode.AI_CONTEXT_TOO_LONG);
        return clients.getObject().prompt().messages(messages).tools(tools)
                .toolContext(Map.of("userId", userId)).stream().chatResponse();
    }
}
