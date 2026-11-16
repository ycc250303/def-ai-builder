package com.def.plant.userAuthService.dto;

/**
 * 注册和登录共用的账号密码输入。字符串输出不包含密码。
 *
 * @param username 用户名称
 * @param password 密码原文
 */
public record CredentialsRequest(String username, String password) {

	@Override
	public String toString() {
		return "CredentialsRequest[username=" + username + "]";
	}

}
