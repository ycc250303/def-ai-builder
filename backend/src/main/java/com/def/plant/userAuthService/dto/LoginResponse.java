package com.def.plant.userAuthService.dto;

/**
 * 登录结果。字符串输出不包含令牌。
 *
 * @param token 当前登录令牌
 * @param user 用户信息
 */
public record LoginResponse(String token, UserResponse user) {

	@Override
	public String toString() {
		return "LoginResponse[user=" + user + "]";
	}

}
