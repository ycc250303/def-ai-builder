package com.def.plant.aiService.mapper;

import java.util.List;

import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Options;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import com.def.plant.plantInfoService.dto.PlantResponse;

/** 工具只读查询，显式限定账号，单条查询最多执行五秒。 */
@Mapper
public interface AiPlantMapper {
    String COLUMNS = "id,nickname,species,planting_date,care_start_date,growing_location,cultivation_method,description";

    @Select("SELECT " + COLUMNS + " FROM plants WHERE user_id=#{userId} AND id=#{id}")
    @Options(timeout = 5)
    PlantResponse get(@Param("userId") long userId, @Param("id") long id);

    @Select("SELECT " + COLUMNS + " FROM plants WHERE user_id=#{userId} ORDER BY id DESC LIMIT 20 OFFSET #{offset}")
    @Options(timeout = 5)
    List<PlantResponse> list(@Param("userId") long userId, @Param("offset") int offset);
}
