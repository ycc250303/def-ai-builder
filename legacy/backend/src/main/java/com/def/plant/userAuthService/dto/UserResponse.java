package com.def.plant.userAuthService.dto;

/**
 * 对外返回的用户信息。
 *
 * @param id 用户编号
 * @param username 规范化后的用户名称
 */
public record UserResponse(long id, String username) {
}
