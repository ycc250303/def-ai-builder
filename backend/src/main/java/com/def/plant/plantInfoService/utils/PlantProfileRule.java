package com.def.plant.plantInfoService.utils;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Set;

import com.def.plant.common.exception.BusinessException;
import com.def.plant.common.exception.ErrorCode;
import com.def.plant.plantInfoService.dto.PlantRequest;
import com.def.plant.plantInfoService.entity.Plant;

/**
 * 植物档案字段校验与默认值。日期按上海时区计算。
 */
public final class PlantProfileRule {

	private PlantProfileRule() {
	}

	/**
	 * 校验文字长度、必填品种和选项码值，规范化空白并填充默认值。
	 *
	 * @param request 完整输入
	 * @return 尚未设置编号及所属用户的植物
	 * @throws BusinessException 品种、文字长度或选项码值不合法
	 */
	public static Plant normalize(PlantRequest request) {
		if (request == null) {
			throw new BusinessException(ErrorCode.INVALID_PLANT_INFO);
		}
		String species = text(request.species(), 100);
		if (species == null) {
			throw new BusinessException(ErrorCode.INVALID_PLANT_INFO);
		}
		String nickname = text(request.nickname(), 100);
		Plant plant = new Plant();
		plant.setSpecies(species);
		plant.setNickname(nickname == null ? species : nickname);
		plant.setPlantingDate(request.plantingDate());
		plant.setCareStartDate(request.careStartDate() == null
				? LocalDate.now(ZoneId.of("Asia/Shanghai")) : request.careStartDate());
		plant.setGrowingLocation(option(request.growingLocation(), Set.of("INDOOR", "OUTDOOR")));
		plant.setCultivationMethod(option(request.cultivationMethod(), Set.of("SOIL", "WATER")));
		plant.setDescription(text(request.description(), 1000));
		return plant;
	}

	private static String text(String value, int maxLength) {
		if (value == null || value.isBlank()) {
			return null;
		}
		String normalized = value.strip();
		if (normalized.codePointCount(0, normalized.length()) > maxLength) {
			throw new BusinessException(ErrorCode.INVALID_PLANT_INFO);
		}
		return normalized;
	}

	private static String option(String value, Set<String> allowed) {
		if (value != null && !allowed.contains(value)) {
			throw new BusinessException(ErrorCode.INVALID_PLANT_INFO);
		}
		return value;
	}

}
