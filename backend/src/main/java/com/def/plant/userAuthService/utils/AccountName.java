package com.def.plant.userAuthService.utils;

import java.util.Locale;
import java.util.regex.Pattern;

import com.def.plant.common.exception.BusinessException;
import com.def.plant.common.exception.ErrorCode;

/**
 * 账号规范化。保存和登录都使用去掉首尾空白并转为小写后的结果。
 */
public final class AccountName {

	private static final Pattern ALLOWED = Pattern.compile("[a-z0-9_]{3,32}");

	private AccountName() {
	}

	/**
	 * @param raw 调用方输入的用户名称
	 * @return 用于保存和比较的账号
	 * @throws BusinessException 名称不符合长度或字符规则
	 */
	public static String normalize(String raw) {
		if (raw == null) {
			throw new BusinessException(ErrorCode.INVALID_ACCOUNT);
		}
		String normalized = raw.trim().toLowerCase(Locale.ROOT);
		if (!ALLOWED.matcher(normalized).matches()) {
			throw new BusinessException(ErrorCode.INVALID_ACCOUNT);
		}
		return normalized;
	}

}
