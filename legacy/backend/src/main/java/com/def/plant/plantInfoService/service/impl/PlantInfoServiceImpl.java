package com.def.plant.plantInfoService.service.impl;

import java.util.List;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.def.plant.common.context.LoginPrincipal;
import com.def.plant.common.exception.BusinessException;
import com.def.plant.common.exception.ErrorCode;
import com.def.plant.plantInfoService.dto.PlantRequest;
import com.def.plant.plantInfoService.dto.PlantResponse;
import com.def.plant.plantInfoService.entity.Plant;
import com.def.plant.plantInfoService.mapper.PlantMapper;
import com.def.plant.plantInfoService.service.PlantInfoService;
import com.def.plant.plantInfoService.utils.PlantProfileRule;

/**
 * 植物档案业务。所有数据访问限定当前用户，写入通过单条 SQL 原子完成。
 */
@Service
public class PlantInfoServiceImpl implements PlantInfoService {

	private final PlantMapper plantMapper;

	/** @param plantMapper 植物表 */
	public PlantInfoServiceImpl(PlantMapper plantMapper) {
		this.plantMapper = plantMapper;
	}

	@Override
	public PlantResponse create(PlantRequest request) {
		long userId = currentPrincipal().userId();
		Plant plant = PlantProfileRule.normalize(request);
		plant.setUserId(userId);
		plantMapper.insert(plant);
		if (plant.getId() == null) {
			throw new IllegalStateException("保存植物后没有返回植物编号");
		}
		return PlantResponse.from(plant);
	}

	@Override
	public List<PlantResponse> list() {
		return plantMapper.selectList(ownedPlants().orderByDesc(Plant::getId)).stream()
				.map(PlantResponse::from).toList();
	}

	@Override
	public PlantResponse get(long id) {
		Plant plant = plantMapper.selectOne(ownedPlants().eq(Plant::getId, id));
		if (plant == null) {
			throw new BusinessException(ErrorCode.PLANT_NOT_FOUND);
		}
		return PlantResponse.from(plant);
	}

	/**
	 * 校验完整表单后，以编号和所属用户为条件执行一次更新，显式写入空值以支持清空。
	 * 并发更新按数据库执行顺序生效；与删除并发时按受影响行数判定是否存在。
	 *
	 * @param id 植物编号
	 * @param request 完整档案输入
	 * @return 本次保存的档案
	 * @throws BusinessException 未登录、输入不合法或植物不存在
	 */
	@Override
	public PlantResponse update(long id, PlantRequest request) {
		long userId = currentPrincipal().userId();
		Plant plant = PlantProfileRule.normalize(request);
		int changed = plantMapper.update(null, new LambdaUpdateWrapper<Plant>()
				.eq(Plant::getId, id).eq(Plant::getUserId, userId)
				.set(Plant::getNickname, plant.getNickname())
				.set(Plant::getSpecies, plant.getSpecies())
				.set(Plant::getPlantingDate, plant.getPlantingDate())
				.set(Plant::getCareStartDate, plant.getCareStartDate())
				.set(Plant::getGrowingLocation, plant.getGrowingLocation())
				.set(Plant::getCultivationMethod, plant.getCultivationMethod())
				.set(Plant::getDescription, plant.getDescription()));
		if (changed == 0) {
			throw new BusinessException(ErrorCode.PLANT_NOT_FOUND);
		}
		plant.setId(id);
		return PlantResponse.from(plant);
	}

	@Override
	public void delete(long id) {
		if (plantMapper.delete(ownedPlants().eq(Plant::getId, id)) == 0) {
			throw new BusinessException(ErrorCode.PLANT_NOT_FOUND);
		}
	}

	private static LambdaQueryWrapper<Plant> ownedPlants() {
		return new LambdaQueryWrapper<Plant>().eq(Plant::getUserId, currentPrincipal().userId());
	}

	private static LoginPrincipal currentPrincipal() {
		Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
		if (authentication == null || !(authentication.getPrincipal() instanceof LoginPrincipal principal)) {
			throw new BusinessException(ErrorCode.NOT_AUTHENTICATED);
		}
		return principal;
	}

}
