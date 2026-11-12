package com.def.plant.common.config;

import java.io.IOException;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import com.def.plant.common.context.LoginPrincipal;
import com.def.plant.common.exception.ErrorCode;
import com.def.plant.common.exception.ProblemResponses;
import com.def.plant.common.security.JwtSessionStore;
import com.def.plant.common.security.JwtTokenService;

import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * 验签后核对该用户保存在 Redis 中的当前令牌。存储故障时立即返回，不把故障当成未登录。
 */
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

	private static final Logger log = LoggerFactory.getLogger(JwtAuthenticationFilter.class);

	private final JwtTokenService jwtTokenService;

	private final JwtSessionStore jwtSessionStore;

	/**
	 * @param jwtTokenService 令牌验签
	 * @param jwtSessionStore 当前登录态
	 */
	public JwtAuthenticationFilter(JwtTokenService jwtTokenService, JwtSessionStore jwtSessionStore) {
		this.jwtTokenService = jwtTokenService;
		this.jwtSessionStore = jwtSessionStore;
	}

	@Override
	protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
			throws ServletException, IOException {
		String token = bearerToken(request);
		if (StringUtils.hasText(token)) {
			try {
				var claims = jwtTokenService.parse(token);
				long userId = Long.parseLong(claims.getSubject());
				String username = claims.get("username", String.class);
				var stored = jwtSessionStore.find(userId);
				if (username != null && stored.isPresent() && stored.get().equals(token)) {
					LoginPrincipal principal = new LoginPrincipal(userId, username);
					UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
							principal, null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
					SecurityContextHolder.getContext().setAuthentication(authentication);
				}
			}
			catch (JwtException | IllegalArgumentException exception) {
				SecurityContextHolder.clearContext();
			}
			catch (DataAccessException exception) {
				log.error("读取登录状态失败", exception);
				ProblemResponses.write(response, ErrorCode.DATA_STORE_UNAVAILABLE);
				return;
			}
		}
		filterChain.doFilter(request, response);
	}

	private static String bearerToken(HttpServletRequest request) {
		String header = request.getHeader("Authorization");
		if (StringUtils.hasText(header) && header.startsWith("Bearer ")) {
			return header.substring(7);
		}
		return null;
	}

}
