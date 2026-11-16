package com.def.plant.common.security;

import java.time.Duration;
import java.util.Optional;

import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * 登录允许名单。键为 {@code plant:jwt:token:{userId}}，有效期 7 天。
 */
@Component
public class RedisJwtSessionStore implements JwtSessionStore {

	private static final String TOKEN_KEY_PREFIX = "plant:jwt:token:";

	private static final Duration TOKEN_TTL = Duration.ofDays(7);

	private final StringRedisTemplate redisTemplate;

	/**
	 * @param redisTemplate Redis 字符串访问
	 */
	public RedisJwtSessionStore(StringRedisTemplate redisTemplate) {
		this.redisTemplate = redisTemplate;
	}

	@Override
	public void replace(long userId, String token) {
		redisTemplate.opsForValue().set(TOKEN_KEY_PREFIX + userId, token, TOKEN_TTL);
	}

	@Override
	public Optional<String> find(long userId) {
		return Optional.ofNullable(redisTemplate.opsForValue().get(TOKEN_KEY_PREFIX + userId));
	}

	@Override
	public void revoke(long userId) {
		redisTemplate.delete(TOKEN_KEY_PREFIX + userId);
	}

}
