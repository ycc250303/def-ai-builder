package com.def.plant.plantKnowledgeService;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.*;

import java.util.Arrays;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.def.plant.common.exception.BusinessException;
import com.def.plant.common.exception.ErrorCode;
import com.def.plant.plantKnowledgeService.client.NcStateClient;
import com.def.plant.plantKnowledgeService.dto.CareTopic;
import com.def.plant.plantKnowledgeService.service.NcStatePageParser;
import com.def.plant.plantKnowledgeService.service.PlantKnowledgeService;
import com.def.plant.plantKnowledgeService.service.PlantNameCatalog;

class PlantKnowledgeServiceTest {
    private NcStateClient client;
    private PlantNameCatalog catalog;
    private PlantKnowledgeService service;

    @BeforeEach void prepare() throws Exception {
        client = mock(NcStateClient.class);
        catalog = new PlantNameCatalog();
        service = new PlantKnowledgeService(client, new NcStatePageParser(), catalog);
    }

    @Test
    void nineCommonNamesAndAliasesResolveToReviewedSourcesWithoutTaxonomyInput() {
        assertThat(catalog.entries()).hasSize(9);
        assertThat(catalog.find("  虎尾兰 ").orElseThrow().nameZh()).isEqualTo("虎皮兰");
        assertThat(catalog.find("雪铁芋").orElseThrow().nameZh()).isEqualTo("金钱树");
        when(client.fetch("/find_a_plant/?q=ZZ+plant")).thenReturn(KnowledgeFixtures.search("/plants/zamioculcas-zamiifolia/"));
        when(client.fetch("/plants/zamioculcas-zamiifolia/")).thenReturn(KnowledgeFixtures.detail());
        var result = service.query("金钱树", List.of("money plant"), List.of("WATERING", "HUMIDITY"), "叶片发黄");
        assertThat(result.status()).isEqualTo("FOUND");
        assertThat(result.searchedTerms()).containsExactly("ZZ plant");
        assertThat(result.topicsWithoutExplicitEvidence()).containsExactly(CareTopic.HUMIDITY);
        assertThat(result.sources().getFirst().url()).isEqualTo("https://plants.ces.ncsu.edu/plants/zamioculcas-zamiifolia/");
        assertThat(result.sources().getFirst().evidence().getFirst().text()).startsWith("Yellow leaves");
        verify(client, never()).fetch(contains("money"));
    }

    @Test
    void cactusCategoryReturnsReferencesWithoutRequiringSpeciesSelection() {
        when(client.fetch("/find_a_plant/?q=ball+cactus")).thenReturn(KnowledgeFixtures.search("/plants/parodia/"));
        when(client.fetch("/find_a_plant/?q=Easter+lily+cactus"))
                .thenReturn(KnowledgeFixtures.search("/plants/parodia/", "/plants/echinopsis-oxygona/", "/plants/unrelated/"));
        when(client.fetch("/plants/parodia/")).thenReturn(KnowledgeFixtures.detail());
        when(client.fetch("/plants/echinopsis-oxygona/")).thenReturn(KnowledgeFixtures.detail());
        var result = service.query("仙人球", List.of("cactus"), List.of("WATERING"), null);
        assertThat(result.status()).isEqualTo("FOUND");
        assertThat(result.scope()).isEqualTo("CATEGORY_REFERENCE");
        assertThat(result.sources()).hasSize(2);
        verify(client, times(1)).fetch("/plants/parodia/");
        verify(client, never()).fetch("/plants/unrelated/");
    }

    @Test
    void unknownCommonNameUsesTranslatedNamesSeparatelyAndReadsAtMostThreePages() {
        when(client.fetch("/find_a_plant/?q=English+name")).thenReturn(KnowledgeFixtures.search("/plants/one/", "/plants/two/"));
        when(client.fetch("/find_a_plant/?q=Another+name")).thenReturn(KnowledgeFixtures.search("/plants/two/", "/plants/three/", "/plants/four/"));
        for (String path : List.of("one", "two", "three")) when(client.fetch("/plants/" + path + "/")).thenReturn(KnowledgeFixtures.detail());
        var result = service.query("未收录俗名", List.of("English name", "Another name"), null, null);
        assertThat(result.sources()).hasSize(3);
        assertThat(result.moreSourcesAvailable()).isTrue();
        verify(client, never()).fetch("/plants/four/");
        assertThat(result.sources().getFirst().evidence()).anyMatch(item -> item.topic() == CareTopic.GENERAL_CARE);
    }

    @Test
    void notFoundIsNormalAndSourceErrorsDoNotProducePartialSuccess() {
        when(client.fetch("/find_a_plant/?q=unknown")).thenReturn(KnowledgeFixtures.search());
        var missing = service.query("未知植物", List.of("unknown"), List.of("LIGHT"), null);
        assertThat(missing.status()).isEqualTo("NOT_FOUND");
        assertThat(missing.sources()).isEmpty();
        assertThat(missing.topicsWithoutExplicitEvidence()).containsExactly(CareTopic.LIGHT);
        when(client.fetch("/find_a_plant/?q=second")).thenThrow(new BusinessException(ErrorCode.PLANT_KNOWLEDGE_UNAVAILABLE));
        assertThatThrownBy(() -> service.query("未知植物", List.of("unknown", "second"), null, null))
                .isInstanceOfSatisfying(BusinessException.class,
                        error -> assertThat(error.errorCode()).isEqualTo(ErrorCode.PLANT_KNOWLEDGE_UNAVAILABLE));
    }

    @Test
    void generalCareCanBeCombinedWithSpecificTopicsAndRepeatedTopicsAreDeduplicated() {
        when(client.fetch("/find_a_plant/?q=golden+pothos")).thenReturn(KnowledgeFixtures.search("/plants/epipremnum-aureum/"));
        when(client.fetch("/plants/epipremnum-aureum/")).thenReturn(KnowledgeFixtures.detail());
        var result = service.query("绿萝", List.of("pothos"),
                List.of("GENERAL_CARE", "WATERING", "REPOTTING", "WATERING", "HUMIDITY"), null);
        assertThat(result.status()).isEqualTo("FOUND");
        assertThat(result.sources().getFirst().evidence()).anyMatch(item -> item.topic() == CareTopic.WATERING
                && item.text().startsWith("In winter"));
        assertThat(result.sources().getFirst().evidence()).anyMatch(item -> item.topic() == CareTopic.REPOTTING
                && item.text().contains("Re-pot in spring"));
        assertThat(result.sources().getFirst().evidence()).doesNotHaveDuplicates();
        assertThat(result.topicsWithoutExplicitEvidence()).containsExactly(CareTopic.HUMIDITY);
        verify(client, times(1)).fetch("/plants/epipremnum-aureum/");
    }

    @Test
    void invalidParametersFailBeforeAnyNetworkRequest() {
        List<Runnable> invalid = List.of(
                () -> service.query(" ", List.of("pothos"), null, null),
                () -> service.query("文".repeat(101), List.of("pothos"), null, null),
                () -> service.query("绿萝", null, null, null),
                () -> service.query("绿萝", List.of(), null, null),
                () -> service.query("绿萝", List.of("a"), null, null),
                () -> service.query("绿萝", List.of("绿萝"), null, null),
                () -> service.query("绿萝", Arrays.asList((String) null), null, null),
                () -> service.query("绿萝", List.of("https://other.example/"), null, null),
                () -> service.query("绿萝", List.of("pothos"), List.of(), null),
                () -> service.query("绿萝", List.of("pothos"), List.of("BAD"), null),
                () -> service.query("绿萝", List.of("pothos"), Arrays.asList("LIGHT", null), null),
                () -> service.query("绿萝", List.of("pothos"),
                        List.of("GENERAL_CARE", "LIGHT", "WATERING", "SOIL", "TEMPERATURE", "HUMIDITY", "FERTILIZING"), null),
                () -> service.query("绿萝", List.of("pothos"), null, "文".repeat(501)));
        for (Runnable input : invalid) assertThatThrownBy(input::run).isInstanceOfSatisfying(BusinessException.class,
                error -> assertThat(error.errorCode()).isEqualTo(ErrorCode.INVALID_PLANT_KNOWLEDGE_QUERY));
        verifyNoInteractions(client);
    }

    @Test
    void oversizedEvidenceIsRejectedWithoutSilentlyTruncatingConditions() {
        when(client.fetch("/find_a_plant/?q=golden+pothos")).thenReturn(KnowledgeFixtures.search("/plants/epipremnum-aureum/"));
        when(client.fetch("/plants/epipremnum-aureum/"))
                .thenReturn("<div id='plant_detail'><h1>Plant</h1><dl><dt>Description</dt><dd><p>Water " + "condition ".repeat(2000) + "</p></dd></dl></div>");
        assertThatThrownBy(() -> service.query("绿萝", List.of("pothos"), List.of("WATERING"), null))
                .isInstanceOfSatisfying(BusinessException.class,
                        error -> assertThat(error.errorCode()).isEqualTo(ErrorCode.PLANT_KNOWLEDGE_TOO_LARGE));
    }
}
