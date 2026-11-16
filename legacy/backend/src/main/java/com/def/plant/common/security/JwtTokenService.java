package com.def.plant.common.security;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.UUID;

import javax.crypto.SecretKey;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

/**
 * 登录令牌的签发与验签。密钥来自 {@code JWT_SECRET}，有效期 7 天。
 */
@Component
public class JwtTokenService {

	private static final long EXPIRATION_DAYS = 7;

	private final SecretKey signingKey;

	/**
	 * @param secret {@code JWT_SECRET}，空白或短于 32 字节时拒绝启动
	 */
	public JwtTokenService(@Value("${app.jwt.secret}") String secret) {
		if (secret == null || secret.isBlank()) {
			throw new IllegalStateException("JWT_SECRET 未配置");
		}
		byte[] keyBytes = secret.getBytes(StandardCharsets.UTF_8);
		if (keyBytes.length < 32) {
			throw new IllegalStateException("JWT_SECRET 长度不足 32 字节");
		}
		this.signingKey = Keys.hmacShaKeyFor(keyBytes);
	}

	/**
	 * @param userId 用户编号
	 * @param username 规范化账号
	 * @return 已签名的令牌及其过期时间
	 */
	public IssuedToken generateToken(long userId, String username) {
		Instant now = Instant.now();
		Instant expiration = now.plus(EXPIRATION_DAYS, ChronoUnit.DAYS);
		String token = Jwts.builder()
				.id(UUID.randomUUID().toString())
				.subject(Long.toString(userId))
				.claim("username", username)
				.issuedAt(Date.from(now))
				.expiration(Date.from(expiration))
				.signWith(signingKey)
				.compact();
		return new IssuedToken(token, expiration);
	}

	/**
	 * @param token 请求中的令牌
	 * @return 验签后的声明
	 */
	public Claims parse(String token) {
		return Jwts.parser().verifyWith(signingKey).build().parseSignedClaims(token).getPayload();
	}

}
