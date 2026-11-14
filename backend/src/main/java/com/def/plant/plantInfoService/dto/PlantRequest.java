package com.def.plant.plantInfoService.dto;

import java.time.LocalDate;

/**
 * 新建和完整更新植物档案的输入，数据归属由登录身份确定。
 *
 * @param nickname 昵称，去除首尾空白后最多 100 字，留空时采用品种
 * @param species 品种，必填，去除首尾空白后最多 100 字
 * @param plantingDate 种植日期，可空，格式为 yyyy-MM-dd
 * @param careStartDate 开始养护日期，可空，留空时采用上海时区当天日期
 * @param growingLocation 培养地，可空；INDOOR 为室内，OUTDOOR 为室外
 * @param cultivationMethod 培养方式，可空；SOIL 为土培，WATER 为水培
 * @param description 简要描述，可空，去除首尾空白后最多 1000 字
 */
public record PlantRequest(String nickname, String species, LocalDate plantingDate, LocalDate careStartDate,
		String growingLocation, String cultivationMethod, String description) {
}
