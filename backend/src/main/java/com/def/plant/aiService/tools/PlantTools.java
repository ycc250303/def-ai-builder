package com.def.plant.aiService.tools;

import java.util.List;

import org.springframework.ai.chat.model.ToolContext;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Component;

import com.def.plant.aiService.service.AiConversationService;
import com.def.plant.plantInfoService.dto.PlantResponse;
import com.def.plant.common.exception.BusinessException;

/** 只读植物工具，用户身份始终取自服务端注入的工具上下文。 */
@Component
public class PlantTools {
    private final AiConversationService conversations;
    public PlantTools(AiConversationService conversations) {
        this.conversations = conversations;
    }

    /**
     * 分页查询当前账号的植物，避免工具结果无限增加。
     * @param offset 从零开始的偏移，最多 10000
     * @param context 服务端校验过的用户身份
     * @return 最多 20 株植物的档案
     */
    @Tool(description = "查询主人自己的植物列表，每次最多20株，offset从0开始")
    public List<PlantResponse> listPlants(@ToolParam(description = "从0开始的偏移") int offset, ToolContext context) {
        return conversations.listPlants(owner(context), offset);
    }

    /**
     * 按用户和植物编号共同查询档案。
     * @param plantId 植物编号
     * @param context 服务端校验过的用户身份
     * @return 植物档案
     * @throws BusinessException 植物不存在或不属于当前账号
     */
    @Tool(description = "查询主人指定植物的档案，品种为用户填写，当前尚无环境监测数据")
    public PlantResponse getPlant(long plantId, ToolContext context) {
        return conversations.getPlant(owner(context), plantId);
    }

    private long owner(ToolContext context) {
        return (Long) context.getContext().get("userId");
    }
}
