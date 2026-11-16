package com.def.plant.plantKnowledgeService.service;

import java.io.IOException;
import java.text.Normalizer;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.databind.ObjectMapper;

/** 版本化俗名目录，只保存名称和来源位置；加载失败立即阻止启动。 */
@Component
public class PlantNameCatalog {
    private final List<Entry> entries;

    public PlantNameCatalog() throws IOException {
        try (var input = new ClassPathResource("plant-knowledge/catalog.json").getInputStream()) {
            Catalog data = new ObjectMapper().readValue(input, Catalog.class);
            if (data.version() < 1 || data.verifiedAt() == null || !"REFERENCE_ONLY".equals(data.usageStatus())
                    || data.entries() == null || data.entries().isEmpty()) {
                throw new IllegalStateException("植物俗名目录格式不完整");
            }
            var names = new HashSet<String>();
            for (Entry entry : data.entries()) {
                if (entry.nameZh() == null || entry.nameZh().isBlank() || entry.aliasesZh() == null
                        || entry.englishNames() == null || entry.englishNames().isEmpty() || entry.englishNames().size() > 3
                        || entry.preferredPaths() == null || entry.preferredPaths().isEmpty()) {
                    throw new IllegalStateException("植物俗名目录条目不完整");
                }
                for (String path : entry.preferredPaths()) {
                    if (path == null || !path.matches("/plants/[a-z0-9-]+/")) throw new IllegalStateException("植物来源地址不合法");
                }
                for (String english : entry.englishNames()) {
                    if (english == null || english.isBlank() || english.length() > 80) throw new IllegalStateException("植物英文名称不合法");
                }
                for (String name : java.util.stream.Stream.concat(java.util.stream.Stream.of(entry.nameZh()), entry.aliasesZh().stream()).toList()) {
                    if (name == null || name.isBlank() || !names.add(normalize(name))) throw new IllegalStateException("植物俗名目录存在重复或空名称");
                }
            }
            entries = List.copyOf(data.entries());
        }
    }

    public Optional<Entry> find(String name) {
        String key = normalize(name);
        return entries.stream().filter(entry -> normalize(entry.nameZh()).equals(key)
                || entry.aliasesZh().stream().anyMatch(alias -> normalize(alias).equals(key))).findFirst();
    }

    public List<Entry> entries() { return entries; }

    public static String normalize(String name) {
        return Normalizer.normalize(name, Normalizer.Form.NFKC).strip().replaceAll("\\s+", " ").toLowerCase(Locale.ROOT);
    }

    /**
     * 目录条目，无分类学字段。
     * @param nameZh 常用展示名称
     * @param aliasesZh 中文检索别名
     * @param englishNames 已核实的英文搜索名称，最多三个
     * @param preferredPaths 在直接搜索结果中优先选择的来源路径
     */
    public record Entry(String nameZh, List<String> aliasesZh, List<String> englishNames, List<String> preferredPaths) { }

    /** @param version 目录格式版本 @param verifiedAt 核查日期 @param usageStatus 引用许可状态 @param entries 俗名目录 */
    private record Catalog(int version, String verifiedAt, String usageStatus, List<Entry> entries) { }
}
