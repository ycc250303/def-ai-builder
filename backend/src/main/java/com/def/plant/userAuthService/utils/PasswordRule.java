package com.def.plant.userAuthService.utils;

import com.def.plant.common.exception.BusinessException;
import com.def.plant.common.exception.ErrorCode;

/**
 * 密码规则。校验长度，不改写密码内容。
 */
public final class PasswordRule {

	private PasswordRule() {
	}

	/**
	 * @param password 调用方输入的密码
	 * @throws BusinessException 密码长度不在 8 到 64 位之间
	 */
	public static void check(String password) {
		if (password == null || password.length() < 8 || password.length() > 64) {
			throw new BusinessException(ErrorCode.INVALID_PASSWORD);
		}
	}

}
