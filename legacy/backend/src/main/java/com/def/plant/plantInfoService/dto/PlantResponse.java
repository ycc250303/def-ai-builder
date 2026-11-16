package com.def.plant.plantInfoService.dto;

import java.time.LocalDate;

import com.def.plant.plantInfoService.entity.Plant;

/**
 * 植物档案详情，列表和写入结果共用此结构。
 *
 * @param id 植物编号，对应 plants.id
 * @param nickname 昵称，对应 nickname，非空
 * @param species 用户填写的品种，对应 species，非空
 * @param plantingDate 种植日期，对应 planting_date，可空
 * @param careStartDate 开始养护日期，对应 care_start_date，非空
 * @param growingLocation 培养地，对应 growing_location；INDOOR、OUTDOOR 或空
 * @param cultivationMethod 培养方式，对应 cultivation_method；SOIL、WATER 或空
 * @param description 简要描述，对应 description，可空
 */
public record PlantResponse(long id, String nickname, String species, LocalDate plantingDate,
		LocalDate careStartDate, String growingLocation, String cultivationMethod, String description) {

	public static PlantResponse from(Plant plant) {
		return new PlantResponse(plant.getId(), plant.getNickname(), plant.getSpecies(), plant.getPlantingDate(),
				plant.getCareStartDate(), plant.getGrowingLocation(), plant.getCultivationMethod(), plant.getDescription());
	}

}
