package com.def.plant.plantKnowledgeService.service;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;

import org.springframework.stereotype.Service;

import com.def.plant.common.exception.BusinessException;
import com.def.plant.common.exception.ErrorCode;
import com.def.plant.plantKnowledgeService.client.NcStateClient;
import com.def.plant.plantKnowledgeService.dto.CareTopic;
import com.def.plant.plantKnowledgeService.dto.PlantCareResult;
import com.def.plant.plantKnowledgeService.dto.PlantCareResult.Source;
import com.def.plant.plantKnowledgeService.service.NcStatePageParser.Candidate;

/** 按俗名查询公共资料，搜索和正文访问全部在数据库事务之外完成。 */
@Service
public class PlantKnowledgeService {
    private static final int MAX_SOURCES = 3;
    private static final int MAX_RESULT_BYTES = 16_000;
    private static final com.fasterxml.jackson.databind.ObjectMapper JSON = new com.fasterxml.jackson.databind.ObjectMapper()
            .findAndRegisterModules().disable(com.fasterxml.jackson.databind.SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    private final NcStateClient client;
    private final NcStatePageParser parser;
    private final PlantNameCatalog catalog;

    public PlantKnowledgeService(NcStateClient client, NcStatePageParser parser, PlantNameCatalog catalog) {
        this.client = client;
        this.parser = parser;
        this.catalog = catalog;
    }

    /**
     * 校验请求，独立搜索英文名称、去重排序候选，再读取最多三页的主题证据。
     * 已收录俗名使用目录中核实的英文名称，未知俗名使用 Agent 提供的翻译。
     * @param plantName 用户俗名，去除首尾空白后 1–100 字符
     * @param searchTerms Agent 翻译的英文名称，1–3 项，每项 2–80 字符
     * @param requestedTopics 1–6 项主题；省略为 GENERAL_CARE，允许组合，重复主题合并
     * @param question 当前问题，最多 500 字符，仅用于证据排序，不传给网站
     * @return 带来源的英文证据，未匹配返回 NOT_FOUND
     * @throws BusinessException 参数无效、来源不可用、结构变化或内容超出预算
     */
    public PlantCareResult query(String plantName, List<String> searchTerms, List<String> requestedTopics, String question) {
        String name = plantName == null ? "" : plantName.strip();
        if (name.isEmpty() || name.length() > 100 || searchTerms == null || searchTerms.isEmpty()
                || searchTerms.size() > 3 || (question != null && question.length() > 500)) throw invalid();
        var terms = new LinkedHashSet<String>();
        for (String term : searchTerms) {
            if (term == null || term.strip().length() < 2 || term.strip().length() > 80
                    || !term.matches("[A-Za-z0-9 '\u2019().-]+") || !term.matches(".*[A-Za-z].*")) throw invalid();
            terms.add(term.strip().replaceAll("\\s+", " "));
        }
        List<CareTopic> topics = topics(requestedTopics);
        var known = catalog.find(name);
        List<String> effectiveTerms = known.map(PlantNameCatalog.Entry::englishNames).orElse(List.copyOf(terms));
        List<String> preferred = known.map(PlantNameCatalog.Entry::preferredPaths).orElse(List.of());
        var candidates = new LinkedHashMap<String, Candidate>();
        boolean more = false;
        for (String term : effectiveTerms) {
            String path = "/find_a_plant/?q=" + URLEncoder.encode(term, StandardCharsets.UTF_8);
            var page = parser.search(client.fetch(path));
            more |= page.total() > page.candidates().size();
            page.candidates().forEach(candidate -> candidates.putIfAbsent(candidate.path(), candidate));
        }
        List<Candidate> ranked = candidates.values().stream().sorted(Comparator.comparingInt(candidate -> {
            int index = preferred.indexOf(candidate.path());
            if (index >= 0) return index;
            boolean contains = effectiveTerms.stream().anyMatch(term -> candidate.commonNames().toLowerCase(Locale.ROOT)
                    .contains(term.toLowerCase(Locale.ROOT)));
            return contains ? 100 : 200;
        })).toList();
        // 已收录类别只采用审核过的来源页面，避免同名的其他植物混入养护建议。
        List<Candidate> selected = ranked.stream().filter(candidate -> preferred.isEmpty() || preferred.contains(candidate.path()))
                .limit(MAX_SOURCES).toList();
        more |= ranked.size() > selected.size();
        List<Source> sources = new ArrayList<>();
        for (Candidate candidate : selected) {
            var page = parser.detail(client.fetch(candidate.path()), topics, question);
            sources.add(new Source("source-" + (sources.size() + 1), page.title(), NcStateClient.ORIGIN + candidate.path(),
                    "en", page.evidence()));
        }
        List<CareTopic> missing = topics.stream().filter(topic -> sources.stream()
                .flatMap(source -> source.evidence().stream()).noneMatch(evidence -> evidence.topic() == topic)).toList();
        PlantCareResult result = new PlantCareResult(sources.isEmpty() ? "NOT_FOUND" : "FOUND", name,
                effectiveTerms, "CATEGORY_REFERENCE", List.copyOf(sources), missing, more, Instant.now());
        try {
            if (JSON.writeValueAsBytes(result).length > MAX_RESULT_BYTES) {
                throw new BusinessException(ErrorCode.PLANT_KNOWLEDGE_TOO_LARGE);
            }
        } catch (com.fasterxml.jackson.core.JsonProcessingException error) {
            throw new IllegalStateException("植物资料结果序列化失败", error);
        }
        return result;
    }

    private List<CareTopic> topics(List<String> requested) {
        if (requested == null) return List.of(CareTopic.GENERAL_CARE);
        if (requested.isEmpty() || requested.size() > 6) throw invalid();
        var result = new LinkedHashSet<CareTopic>();
        for (String topic : requested) {
            if (topic == null) throw invalid();
            try { result.add(CareTopic.valueOf(topic)); }
            catch (IllegalArgumentException unknown) { throw invalid(); }
        }
        return List.copyOf(result);
    }

    private BusinessException invalid() { return new BusinessException(ErrorCode.INVALID_PLANT_KNOWLEDGE_QUERY); }
}
