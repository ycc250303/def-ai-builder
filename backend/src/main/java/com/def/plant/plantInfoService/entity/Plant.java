package com.def.plant.plantInfoService.entity;

import java.time.LocalDate;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;

/**
 * 用户植物档案，对应 plants 表。
 */
@TableName("plants")
public class Plant {

	/** 植物编号，对应 id，数据库自增。 */
	@TableId(type = IdType.AUTO)
	private Long id;

	/** 所属用户，对应 user_id，关联 users.id，由登录身份确定。 */
	private Long userId;

	/** 昵称，对应 nickname，非空，最多 100 字。 */
	private String nickname;

	/** 用户填写的品种，对应 species，非空，最多 100 字。 */
	private String species;

	/** 种植日期，对应 planting_date，可空。 */
	private LocalDate plantingDate;

	/** 开始养护日期，对应 care_start_date，非空。 */
	private LocalDate careStartDate;

	/** 培养地，对应 growing_location；INDOOR 为室内，OUTDOOR 为室外，可空。 */
	private String growingLocation;

	/** 培养方式，对应 cultivation_method；SOIL 为土培，WATER 为水培，可空。 */
	private String cultivationMethod;

	/** 简要描述，对应 description，可空，最多 1000 字。 */
	private String description;

	public Long getId() {
		return id;
	}

	public void setId(Long id) {
		this.id = id;
	}

	public Long getUserId() {
		return userId;
	}

	public void setUserId(Long userId) {
		this.userId = userId;
	}

	public String getNickname() {
		return nickname;
	}

	public void setNickname(String nickname) {
		this.nickname = nickname;
	}

	public String getSpecies() {
		return species;
	}

	public void setSpecies(String species) {
		this.species = species;
	}

	public LocalDate getPlantingDate() {
		return plantingDate;
	}

	public void setPlantingDate(LocalDate plantingDate) {
		this.plantingDate = plantingDate;
	}

	public LocalDate getCareStartDate() {
		return careStartDate;
	}

	public void setCareStartDate(LocalDate careStartDate) {
		this.careStartDate = careStartDate;
	}

	public String getGrowingLocation() {
		return growingLocation;
	}

	public void setGrowingLocation(String growingLocation) {
		this.growingLocation = growingLocation;
	}

	public String getCultivationMethod() {
		return cultivationMethod;
	}

	public void setCultivationMethod(String cultivationMethod) {
		this.cultivationMethod = cultivationMethod;
	}

	public String getDescription() {
		return description;
	}

	public void setDescription(String description) {
		this.description = description;
	}

}
