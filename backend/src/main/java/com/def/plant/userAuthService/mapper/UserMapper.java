package com.def.plant.userAuthService.mapper;

import org.apache.ibatis.annotations.Mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.def.plant.userAuthService.entity.User;

/**
 * 用户表访问。基础增删改查由 MyBatis-Plus 提供。
 */
@Mapper
public interface UserMapper extends BaseMapper<User> {
}
