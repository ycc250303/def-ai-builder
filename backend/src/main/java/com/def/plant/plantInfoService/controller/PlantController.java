package com.def.plant.plantInfoService.controller;

import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ProblemDetail;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import com.def.plant.common.exception.ErrorCode;
import com.def.plant.common.exception.ProblemResponses;
import com.def.plant.plantInfoService.dto.PlantRequest;
import com.def.plant.plantInfoService.dto.PlantResponse;
import com.def.plant.plantInfoService.service.PlantInfoService;

/**
 * 当前登录用户的植物列表与档案。
 */
@RestController
@RequestMapping("/plants")
public class PlantController {

	private static final Logger log = LoggerFactory.getLogger(PlantController.class);

	private final PlantInfoService plantInfoService;

	/** @param plantInfoService 植物档案业务 */
	public PlantController(PlantInfoService plantInfoService) {
		this.plantInfoService = plantInfoService;
	}

	/** @return 当前用户的植物列表 */
	@GetMapping
	public List<PlantResponse> list() {
		return plantInfoService.list();
	}

	/**
	 * @param id 植物编号
	 * @return 当前用户的植物档案
	 */
	@GetMapping("/{id}")
	public PlantResponse get(@PathVariable long id) {
		return plantInfoService.get(id);
	}

	/**
	 * @param request 档案字段
	 * @return 新建档案
	 */
	@PostMapping
	public PlantResponse create(@RequestBody PlantRequest request) {
		PlantResponse plant = plantInfoService.create(request);
		log.info("新建植物档案: id={}", plant.id());
		return plant;
	}

	/**
	 * @param id 植物编号
	 * @param request 完整档案字段
	 * @return 更新后的档案
	 */
	@PutMapping("/{id}")
	public PlantResponse update(@PathVariable long id, @RequestBody PlantRequest request) {
		PlantResponse plant = plantInfoService.update(id, request);
		log.info("更新植物档案: id={}", plant.id());
		return plant;
	}

	/** @param id 植物编号 */
	@DeleteMapping("/{id}")
	public void delete(@PathVariable long id) {
		plantInfoService.delete(id);
		log.info("删除植物档案: id={}", id);
	}

	/**
	 * @param exception 请求字段类型、日期或编号格式不合法
	 * @return 档案输入不合法的 Problem Details
	 */
	@ExceptionHandler({HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class})
	public ProblemDetail handleInvalidInput(Exception exception) {
		return ProblemResponses.toProblemDetail(ErrorCode.INVALID_PLANT_INFO);
	}

}
