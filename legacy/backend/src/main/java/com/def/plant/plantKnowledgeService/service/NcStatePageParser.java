package com.def.plant.plantKnowledgeService.service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;

import org.jsoup.Jsoup;
import org.jsoup.nodes.Element;
import org.springframework.stereotype.Component;

import com.def.plant.common.exception.BusinessException;
import com.def.plant.common.exception.ErrorCode;
import com.def.plant.plantKnowledgeService.dto.CareTopic;
import com.def.plant.plantKnowledgeService.dto.PlantCareResult.Evidence;

/** 解析来源网站的直接搜索结果和定义列表，页面结构缺失时立即终止。 */
@Component
public class NcStatePageParser {
    /**
     * 只读取搜索结果容器中的植物标题，忽略零结果页面的推荐链接。
     * @param html 完整搜索页
     * @return 来源匹配数量与本页去重后的详情路径
     * @throws BusinessException 必要结构缺失或有效结果地址不合法
     */
    public SearchPage search(String html) {
        var document = Jsoup.parse(html);
        Element count = document.selectFirst("#plant_object_count");
        if (count == null || !count.attr("value").matches("[0-9]{1,7}")) throw changed();
        int total = Integer.parseInt(count.attr("value"));
        if (total == 0) return new SearchPage(0, List.of());
        Element list = document.selectFirst("#plant_list");
        if (list == null) throw changed();
        Map<String, Candidate> candidates = new LinkedHashMap<>();
        for (Element item : list.select(".plant")) {
            Element link = item.selectFirst("h2 a[href]");
            if (link == null || !link.attr("href").matches("/plants/[a-z0-9-]+/")) throw changed();
            candidates.putIfAbsent(link.attr("href"), new Candidate(link.attr("href"),
                    item.select(".common_names").text()));
        }
        if (candidates.isEmpty()) throw changed();
        return new SearchPage(total, List.copyOf(candidates.values()));
    }

    /**
     * 按主题提取完整字段和段落。保留原文条件，不根据关键词生成新事实。
     * @param html 完整详情页
     * @param topics 已验证的主题，可组合综合养护与具体主题，展开后去重
     * @param question 问题摘要，只用于调整段落顺序
     * @return 页面标题及证据；空主题证据表示未提取到明确说明
     * @throws BusinessException 详情主体、标题或介绍段落缺失
     */
    public DetailPage detail(String html, List<CareTopic> topics, String question) {
        Element root = Jsoup.parse(html).selectFirst("#plant_detail");
        if (root == null) throw changed();
        root.select("script, style, nav, form, button, audio").remove();
        Element heading = root.selectFirst("h1");
        if (heading == null || heading.text().isBlank()) throw changed();
        Map<String, List<Element>> fields = new LinkedHashMap<>();
        for (Element term : root.select("dt")) {
            String label = term.text().replaceAll(":$", "").strip();
            var values = fields.computeIfAbsent(label, ignored -> new ArrayList<>());
            for (Element next = term.nextElementSibling(); next != null && next.tagName().equals("dd"); next = next.nextElementSibling()) {
                values.add(next);
            }
        }
        List<Element> description = fields.get("Description");
        if (description == null || description.isEmpty() || description.stream().allMatch(value -> value.text().isBlank())) throw changed();
        var paragraphs = new LinkedHashSet<String>();
        for (Element value : description) {
            if (value.select("p").isEmpty()) paragraphs.add(value.text());
            else value.select("p").forEach(paragraph -> paragraphs.add(paragraph.text()));
        }
        List<Evidence> evidence = new ArrayList<>();
        var expanded = new LinkedHashSet<>(topics);
        if (topics.contains(CareTopic.GENERAL_CARE)) expanded.addAll(List.of(CareTopic.LIGHT, CareTopic.WATERING, CareTopic.SOIL));
        for (CareTopic topic : expanded) {
            for (String label : topic.labels()) {
                String content = String.join("; ", fields.getOrDefault(label, List.of()).stream().map(Element::text)
                        .filter(text -> !text.isBlank()).distinct().toList());
                if (!content.isBlank()) evidence.add(new Evidence(topic, label, content));
            }
            List<String> ordered = paragraphs.stream().sorted(java.util.Comparator.comparingInt(paragraph ->
                    focused(paragraph, question) ? 0 : 1)).toList();
            for (String paragraph : ordered) {
                boolean includeTopicParagraph = !topics.contains(CareTopic.GENERAL_CARE) || topics.contains(topic);
                if (topic == CareTopic.GENERAL_CARE || (includeTopicParagraph && topic.matches(paragraph))) {
                    evidence.add(new Evidence(topic, "Description", paragraph));
                }
            }
        }
        // 同一段落可能支持多个主题；证据主题保留，正文预算由业务层检查。
        return new DetailPage(heading.text(), List.copyOf(evidence));
    }

    private BusinessException changed() { return new BusinessException(ErrorCode.PLANT_KNOWLEDGE_PAGE_CHANGED); }

    private boolean focused(String paragraph, String question) {
        if (question == null || question.isBlank()) return false;
        String text = paragraph.toLowerCase(java.util.Locale.ROOT);
        if (question.matches(".*(发黄|黄叶).*")) return text.contains("yellow");
        if (question.matches(".*(掉叶|落叶).*")) return text.contains("drop") || text.contains("fall");
        if (question.matches(".*(烂根|根腐).*")) return text.contains("rot");
        return java.util.Arrays.stream(question.toLowerCase(java.util.Locale.ROOT).split("[^a-z]+"))
                .filter(word -> word.length() >= 4).anyMatch(text::contains);
    }

    /** @param path 规范相对路径 @param commonNames 页面显示的英文俗名，用于相关性排序 */
    public record Candidate(String path, String commonNames) { }
    /** @param total 来源直接匹配数量 @param candidates 本页候选，不包含建议列表 */
    public record SearchPage(int total, List<Candidate> candidates) { }
    /** @param title 来源标题 @param evidence 完整字段与段落 */
    public record DetailPage(String title, List<Evidence> evidence) { }
}
