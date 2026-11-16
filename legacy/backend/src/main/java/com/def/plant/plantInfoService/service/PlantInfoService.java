package com.def.plant.plantInfoService.service;

import java.util.List;

import com.def.plant.common.exception.BusinessException;
import com.def.plant.plantInfoService.dto.PlantRequest;
import com.def.plant.plantInfoService.dto.PlantResponse;

/**
 * 当前登录用户的植物档案。
 */
public interface PlantInfoService {

	/**
	 * 校验字段、填充昵称与养护日期，并为当前用户保存档案。
	 *
	 * @param request 完整档案输入
	 * @return 保存后的档案
	 * @throws BusinessException 未登录或字段不合法
	 */
	PlantResponse create(PlantRequest request);

	/** @return 当前用户的植物，按编号倒序排列 */
	List<PlantResponse> list();

	/**
	 * @param id 植物编号
	 * @return 当前用户的植物详情
	 * @throws BusinessException 未登录、植物不存在或不属于当前用户
	 */
	PlantResponse get(long id);

	/**
	 * 完整替换可编辑字段。选填字段可清空，昵称和养护日期留空时填充默认值。
	 *
	 * @param id 植物编号
	 * @param request 完整档案输入
	 * @return 更新后的档案
	 * @throws BusinessException 未登录、字段不合法、植物不存在或不属于当前用户
	 */
	PlantResponse update(long id, PlantRequest request);

	/**
	 * @param id 植物编号
	 * @throws BusinessException 未登录、植物不存在或不属于当前用户
	 */
	void delete(long id);

}
