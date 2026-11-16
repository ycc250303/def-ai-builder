package com.def.plant.plantKnowledgeService.dto;

import java.util.List;
import java.util.regex.Pattern;

/** 养护主题码；字段名称对应来源网页的 dt 标签，关键词仅用于筛选完整原文段落。 */
public enum CareTopic {
    /** 综合养护，展开为介绍、光照、浇水和基质四项。 */
    GENERAL_CARE(List.of(), ""),
    /** 光照，读取 Light 字段及光照相关段落。 */
    LIGHT(List.of("Light"), "sun|sunlight|light|shade"),
    /** 浇水，读取 Description 中的浇水和干湿说明。 */
    WATERING(List.of(), "water\\w*|overwater\\w*|underwater\\w*|drought|dry|moist|soggy"),
    /** 基质、排水及酸碱度，对应 Soil Texture、Soil Drainage、Soil pH。 */
    SOIL(List.of("Soil Texture", "Soil Drainage", "Soil pH"), "soil|potting|drain\\w*|substrate|compost|mix"),
    /** 温度和越冬；耐寒分区不作为适宜温度证据。 */
    TEMPERATURE(List.of(), "temperatur\\w*|degrees|cold|frost|freez\\w*|warm|fahrenheit|celsius"),
    /** 空气湿度，保留与土壤干湿的区别。 */
    HUMIDITY(List.of(), "humid\\w*|dry air|moist air"),
    /** 施肥。 */
    FERTILIZING(List.of(), "fertiliz\\w*|fertilis\\w*|feed\\w*"),
    /** 修剪。 */
    PRUNING(List.of(), "prun\\w*|trim\\w*|pinch\\w*"),
    /** 换盆。 */
    REPOTTING(List.of(), "repot\\w*|re-pot\\w*|root.bound|transplant\\w*"),
    /** 繁殖，对应 Recommended Propagation Strategy 及相关段落。 */
    PROPAGATION(List.of("Recommended Propagation Strategy"), "propagat\\w*|cutting\\w*|division|offset\\w*|seed\\w*"),
    /** 病虫害和异常，仅提供资料，不作个体确诊。 */
    PESTS_DISEASES(List.of("Problems"), "insect\\w*|disease\\w*|pest\\w*|rot|fung\\w*|mite\\w*|mealybug\\w*|scale|aphid\\w*|yellow\\w*|browning|scald\\w*"),
    /** 人体与宠物毒性，读取对应毒性字段及段落。 */
    TOXICITY(List.of("Poison Severity", "Poison Symptoms", "Poison Toxic Principle", "Causes Contact Dermatitis", "Poison Part"),
            "toxic\\w*|poison\\w*|dermatitis|ingest\\w*|irritat\\w*|cats|dogs");

    private final List<String> labels;
    private final Pattern paragraphPattern;

    CareTopic(List<String> labels, String words) {
        this.labels = labels;
        this.paragraphPattern = Pattern.compile("\\b(?:" + words + ")\\b", Pattern.CASE_INSENSITIVE);
    }

    public List<String> labels() { return labels; }
    public boolean matches(String paragraph) { return paragraphPattern.matcher(paragraph).find(); }
}
