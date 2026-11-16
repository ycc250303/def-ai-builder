package com.def.plant.plantInfoService;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.LocalDate;

import org.junit.jupiter.api.Test;

import com.def.plant.common.exception.BusinessException;
import com.def.plant.common.exception.ErrorCode;
import com.def.plant.plantInfoService.dto.PlantRequest;
import com.def.plant.plantInfoService.entity.Plant;
import com.def.plant.plantInfoService.utils.PlantProfileRule;

/**
 * 植物文字长度边界，按 Unicode 码点计数，与 PostgreSQL VARCHAR 长度一致。
 */
class PlantProfileRuleTest {

	@Test
	void acceptsBoundaryLengthsIncludingSupplementaryUnicodeCharacters() {
		String species = "🌱".repeat(100);
		LocalDate date = LocalDate.of(2025, 1, 2);
		Plant plant = PlantProfileRule.normalize(new PlantRequest("  ", " " + species + " ", date, date,
				"OUTDOOR", "WATER", "文".repeat(1000)));
		assertThat(plant.getSpecies()).isEqualTo(species);
		assertThat(plant.getNickname()).isEqualTo(species);
		assertThat(plant.getDescription()).hasSize(1000);
		assertThat(plant.getPlantingDate()).isEqualTo(date);
		assertThat(plant.getCareStartDate()).isEqualTo(date);
	}

	@Test
	void rejectsTextBeyondUnicodeCharacterLimit() {
		assertThatThrownBy(() -> PlantProfileRule.normalize(new PlantRequest(null, "🌱".repeat(101),
				null, null, null, null, null)))
				.isInstanceOfSatisfying(BusinessException.class,
						error -> assertThat(error.errorCode()).isEqualTo(ErrorCode.INVALID_PLANT_INFO));
	}

}
