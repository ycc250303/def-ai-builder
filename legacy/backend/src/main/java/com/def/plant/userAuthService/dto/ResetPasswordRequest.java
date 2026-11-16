package com.def.plant.userAuthService.dto;

/**
 * 按账号名称重置密码的输入。字符串输出不包含密码。
 *
 * @param username 需要重置密码的账号名称，规范化后对应 users.username
 * @param newPassword 新密码原文，长度为 8 到 64 位，内容不做裁剪
 */
public record ResetPasswordRequest(String username, String newPassword) {

	@Override
	public String toString() {
		return "ResetPasswordRequest[username=" + username + "]";
	}

}
