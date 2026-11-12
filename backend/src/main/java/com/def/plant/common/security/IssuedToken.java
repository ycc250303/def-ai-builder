package com.def.plant.common.security;

import java.time.Instant;

/**
 * 已签发的登录令牌。
 *
 * @param value 令牌原文
 * @param expiresAt 过期时间
 */
public record IssuedToken(String value, Instant expiresAt) {

	@Override
	public String toString() {
		return "IssuedToken[expiresAt=" + expiresAt + "]";
	}

}
