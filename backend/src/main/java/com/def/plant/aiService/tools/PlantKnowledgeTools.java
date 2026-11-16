package com.def.plant.aiService.tools;

import java.util.List;

import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Component;

import com.def.plant.plantKnowledgeService.dto.PlantCareResult;
import com.def.plant.plantKnowledgeService.dto.CareTopic;
import com.def.plant.plantKnowledgeService.service.PlantKnowledgeService;

/** 公共植物资料工具，参数只包含名称与查询意图，不接受任意网址。 */
@Component
public class PlantKnowledgeTools {
    private final PlantKnowledgeService service;

    public PlantKnowledgeTools(PlantKnowledgeService service) { this.service = service; }

    /**
     * 查询 NC State 植物养护原文，交由当前 Agent 翻译并结合用户事实解释。
     * @param plantName 用户输入的俗名，无需学名
     * @param searchTerms Agent 翻译的 1–3 个英文植物名称，不包含 watering 等查询主题
     * @param topics 最多六项养护主题，省略为综合养护；支持综合养护与具体主题组合并去重
     * @param question 当前问题摘要，不包含账号、令牌或完整对话
     * @return 原文证据、资料适用范围、缺失主题及可引用来源
     */
    @Tool(description = "查询NC State权威植物养护资料。直接使用中文俗名，无需细分物种。"
            + "先把俗名翻译成英文常用植物名称，名称和主题分别传入。返回英文证据，请据此翻译回答并引用实际来源。"
            + "支持绿萝、龟背竹、吊兰、虎皮兰、金钱树、玉树、芦荟、橡皮树、仙人球，也可搜索其他俗名。")
    public PlantCareResult queryPlantCare(
            @ToolParam(description = "用户使用的植物俗名，1到100字符，如仙人球、绿箩") String plantName,
            @ToolParam(description = "1到3个英文植物名称，每项2到80字符，如ball cactus、ZZ plant；不拼接养护问题") List<String> searchTerms,
            @ToolParam(required = false, description = "最多6项养护主题。省略为GENERAL_CARE（介绍、光照、浇水和基质），可与具体主题组合，重复主题合并") List<CareTopic> topics,
            @ToolParam(required = false, description = "当前问题摘要，最多500字符，用于证据排序；无需传完整对话") String question) {
        return service.query(plantName, searchTerms,
                topics == null ? null : topics.stream().map(topic -> topic == null ? null : topic.name()).toList(), question);
    }
}
