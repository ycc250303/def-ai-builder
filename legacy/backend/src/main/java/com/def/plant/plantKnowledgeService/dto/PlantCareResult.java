package com.def.plant.plantKnowledgeService.dto;

import java.time.Instant;
import java.util.List;

/**
 * 公共养护资料查询结果，不包含用户私有信息。
 * @param status FOUND 或 NOT_FOUND；未匹配属于正常查询结果
 * @param plantName 用户使用的植物俗名
 * @param searchedTerms 实际发送给来源网站的英文名称
 * @param scope 固定 CATEGORY_REFERENCE，不代表个体物种已确认
 * @param sources 已获取的来源与英文证据，最多三页
 * @param topicsWithoutExplicitEvidence 未提取到明确说明的请求主题
 * @param moreSourcesAvailable 是否有未读取的搜索结果
 * @param retrievedAt 本次查询完成的 UTC 时间
 */
public record PlantCareResult(String status, String plantName, List<String> searchedTerms, String scope,
        List<Source> sources, List<CareTopic> topicsWithoutExplicitEvidence, boolean moreSourcesAvailable,
        Instant retrievedAt) {

    /**
     * 单个来源页面。
     * @param id 本次结果内稳定的来源编号
     * @param title 来源网页标题，保留原文以便核对
     * @param url 来源网站的规范详情地址
     * @param language 原文语言，固定 en
     * @param evidence 按主题读取的原文段落和字段
     */
    public record Source(String id, String title, String url, String language, List<Evidence> evidence) { }

    /**
     * 可引用的原文材料，禁止当作已经执行的养护事件。
     * @param topic 养护主题；GENERAL_CARE 的 Description 为整体介绍
     * @param section 原网页的字段名称或 Description
     * @param text 完整字段或完整段落，保留季节与条件
     */
    public record Evidence(CareTopic topic, String section, String text) { }
}
