package com.def.plant.common.security;

import java.util.Optional;

/**
 * JWT 登录允许名单。Redis 连接失败必须抛出，不能当成未登录。
 */
public interface JwtSessionStore {

	/**
	 * 覆盖该用户的当前令牌。有效期与 JWT 的 7 天一致。
	 *
	 * @param userId 用户编号
	 * @param token 当前令牌
	 */
	void replace(long userId, String token);

	/**
	 * @param userId 用户编号
	 * @return 尚未过期的当前令牌；不存在时为空
	 */
	Optional<String> find(long userId);

	/**
	 * 删除该用户的当前令牌。
	 *
	 * @param userId 用户编号
	 */
	void revoke(long userId);

}
