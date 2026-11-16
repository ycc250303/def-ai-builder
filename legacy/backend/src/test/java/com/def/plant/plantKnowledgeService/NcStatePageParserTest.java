package com.def.plant.plantKnowledgeService;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;

import org.junit.jupiter.api.Test;

import com.def.plant.common.exception.BusinessException;
import com.def.plant.common.exception.ErrorCode;
import com.def.plant.plantKnowledgeService.dto.CareTopic;
import com.def.plant.plantKnowledgeService.service.NcStatePageParser;

class NcStatePageParserTest {
    private final NcStatePageParser parser = new NcStatePageParser();

    @Test
    void directResultsAreDeduplicatedAndSuggestionsAreNeverTreatedAsMatches() {
        var found = parser.search(KnowledgeFixtures.search("/plants/one/", "/plants/one/", "/plants/two/"));
        assertThat(found.total()).isEqualTo(3);
        assertThat(found.candidates()).extracting(NcStatePageParser.Candidate::path)
                .containsExactly("/plants/one/", "/plants/two/");
        String noResults = """
                <input id='plant_object_count' value='0'><div id='plant_list'>
                <h2>Were you looking for these?</h2><div class='plant'><h2>
                <a href='/plants/suggestion/'>Suggested plant</a></h2></div></div>
                """;
        assertThat(parser.search(noResults).candidates()).isEmpty();
    }

    @Test
    void sourceFieldsAndCompleteConditionalParagraphsArePreserved() {
        var page = parser.detail(KnowledgeFixtures.detail(), List.of(CareTopic.WATERING, CareTopic.LIGHT, CareTopic.TEMPERATURE), null);
        assertThat(page.title()).isEqualTo("Reference plant");
        assertThat(page.evidence()).anySatisfy(item -> {
            assertThat(item.topic()).isEqualTo(CareTopic.LIGHT);
            assertThat(item.section()).isEqualTo("Light");
            assertThat(item.text()).isEqualTo("Partial Shade; Dappled Sunlight");
        }).anySatisfy(item -> {
            assertThat(item.topic()).isEqualTo(CareTopic.WATERING);
            assertThat(item.text()).isEqualTo("In winter, water only when the potting soil is dry. Avoid standing water.");
        });
        assertThat(page.evidence()).noneSatisfy(item -> assertThat(item.text()).contains("advertisements"));
        assertThat(page.evidence()).noneSatisfy(item -> assertThat(item.section()).isEqualTo("USDA Plant Hardiness Zone"));
    }

    @Test
    void missingTopicsStayEmptyAndQuestionOnlyChangesEvidenceOrder() {
        assertThat(parser.detail(KnowledgeFixtures.detail(), List.of(CareTopic.HUMIDITY, CareTopic.FERTILIZING), null).evidence()).isEmpty();
        var watering = parser.detail(KnowledgeFixtures.detail(), List.of(CareTopic.WATERING), "叶片发黄").evidence();
        assertThat(watering.getFirst().text()).startsWith("Yellow leaves");
        assertThat(watering).hasSize(2);
        var general = parser.detail(KnowledgeFixtures.detail(), List.of(CareTopic.GENERAL_CARE), null).evidence();
        assertThat(general).filteredOn(item -> item.section().equals("Description")).hasSize(4);
        assertThat(general).anyMatch(item -> item.section().equals("Soil Drainage"));
    }

    @Test
    void generalCareKeepsAdditionalTopicsAndTheirCompleteEvidence() {
        var evidence = parser.detail(KnowledgeFixtures.detail(),
                List.of(CareTopic.GENERAL_CARE, CareTopic.WATERING, CareTopic.REPOTTING), null).evidence();
        assertThat(evidence).anyMatch(item -> item.topic() == CareTopic.WATERING && item.text().startsWith("In winter"));
        assertThat(evidence).anyMatch(item -> item.topic() == CareTopic.REPOTTING && item.text().contains("Re-pot in spring"));
        assertThat(evidence).doesNotHaveDuplicates();
    }

    @Test
    void missingStructureAndUnsafeCandidateLinksFailImmediately() {
        for (String page : List.of("<h1>Access denied</h1>", "<input id='plant_object_count' value='bad'>",
                KnowledgeFixtures.search("https://other.example/plants/one/"))) {
            assertThatThrownBy(() -> parser.search(page)).isInstanceOfSatisfying(BusinessException.class,
                    error -> assertThat(error.errorCode()).isEqualTo(ErrorCode.PLANT_KNOWLEDGE_PAGE_CHANGED));
        }
        assertThatThrownBy(() -> parser.detail("<div id='plant_detail'><h1>Incomplete</h1></div>", List.of(CareTopic.LIGHT), null))
                .isInstanceOfSatisfying(BusinessException.class,
                        error -> assertThat(error.errorCode()).isEqualTo(ErrorCode.PLANT_KNOWLEDGE_PAGE_CHANGED));
    }
}
