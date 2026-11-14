package com.def.plant.userAuthService;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

import com.def.plant.common.security.JwtTokenService;

/** 同一账号连续登录时，独立令牌不能恢复已失效令牌的效力。 */
class JwtTokenServiceTest {

	@Test
	void eachIssuedTokenHasAnIndependentIdentifier() {
		JwtTokenService tokens = new JwtTokenService("0123456789abcdef0123456789abcdef");
		String first = tokens.generateToken(1, "alice").value();
		String second = tokens.generateToken(1, "alice").value();
		assertThat(tokens.parse(first).getId()).isNotBlank().isNotEqualTo(tokens.parse(second).getId());
		assertThat(first).isNotEqualTo(second);
	}

}
