package com.def.plant.plantInfoService.mapper;

import org.apache.ibatis.annotations.Mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.def.plant.plantInfoService.entity.Plant;

/**
 * 植物表访问。业务层在查询、更新和删除条件中限定所属用户。
 */
@Mapper
public interface PlantMapper extends BaseMapper<Plant> {
}
