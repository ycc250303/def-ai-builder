package com.def.plant.userAuthService;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.doThrow;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.def.plant.common.security.RedisJwtSessionStore;
import com.def.plant.userAuthService.dto.ResetPasswordRequest;

/**
 * 注册、登录、密码重置、当前用户和退出。数据库和 Redis 使用 Testcontainers，不连接服务器。
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class UserLoginTest {

	@Container
	static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16");

	@Container
	static final GenericContainer<?> REDIS = new GenericContainer<>(DockerImageName.parse("redis:7"))
			.withExposedPorts(6379);

	private final HttpClient http = HttpClient.newHttpClient();

	private final ObjectMapper json = new ObjectMapper();

	@Autowired
	private JdbcTemplate jdbc;

	@Autowired
	private PasswordEncoder passwordEncoder;

	@MockitoSpyBean
	private RedisJwtSessionStore sessionStore;

	@DynamicPropertySource
	static void properties(DynamicPropertyRegistry registry) {
		registry.add("spring.flyway.enabled", () -> "true");
		registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
		registry.add("spring.datasource.username", POSTGRES::getUsername);
		registry.add("spring.datasource.password", POSTGRES::getPassword);
		registry.add("app.jwt.secret", () -> "0123456789abcdef0123456789abcdef");
		registry.add("spring.data.redis.host", REDIS::getHost);
		registry.add("spring.data.redis.port", () -> REDIS.getMappedPort(6379));
	}

	@LocalServerPort
	private int port;

	@Test
	void registerLoginCurrentUserAndLogout() throws Exception {
		String username = "alice_01";
		JsonNode registered = body(send("/users", "POST", credentials(username, "password1"), null));
		assertThat(registered.path("username").asText()).isEqualTo(username);
		assertThat(registered.has("password")).isFalse();

		HttpResponse<String> loggedIn = send("/users/login", "POST", credentials("Alice_01", "password1"), null);
		assertThat(loggedIn.statusCode()).isEqualTo(200);
		JsonNode loginBody = json.readTree(loggedIn.body());
		String token = loginBody.path("token").asText();
		assertThat(token).isNotBlank();
		assertThat(loggedIn.body()).doesNotContain("password1");

		HttpResponse<String> me = send("/users/me", "GET", null, token);
		assertThat(me.statusCode()).isEqualTo(200);
		assertThat(json.readTree(me.body()).path("username").asText()).isEqualTo(username);

		HttpResponse<String> loggedOut = send("/users/logout", "POST", "{}", token);
		assertThat(loggedOut.statusCode()).isEqualTo(200);

		HttpResponse<String> rejected = send("/users/me", "GET", null, token);
		assertThat(rejected.statusCode()).isEqualTo(401);
		assertThat(json.readTree(rejected.body()).path("code").asText()).isEqualTo("NOT_AUTHENTICATED");
	}

	@Test
	void duplicateAccountAndWrongPassword() throws Exception {
		send("/users", "POST", credentials("bob_02", "password1"), null);

		HttpResponse<String> duplicate = send("/users", "POST", credentials("Bob_02", "password2"), null);
		assertThat(duplicate.statusCode()).isEqualTo(409);
		assertThat(json.readTree(duplicate.body()).path("code").asText()).isEqualTo("ACCOUNT_TAKEN");

		HttpResponse<String> wrongPassword = send("/users/login", "POST", credentials("bob_02", "wrong-password"), null);
		assertThat(wrongPassword.statusCode()).isEqualTo(401);
		assertThat(json.readTree(wrongPassword.body()).path("code").asText()).isEqualTo("BAD_CREDENTIALS");

		HttpResponse<String> missing = send("/users/me", "GET", null, null);
		assertThat(missing.statusCode()).isEqualTo(401);
		assertThat(json.readTree(missing.body()).path("code").asText()).isEqualTo("NOT_AUTHENTICATED");
	}

	@Test
	void concurrentRegisterAllowsOneAccount() throws Exception {
		String username = "concurrent_user";
		ExecutorService executor = Executors.newFixedThreadPool(2);
		CountDownLatch start = new CountDownLatch(1);
		try {
			Future<Integer> first = executor.submit(() -> registerStatus(username, start));
			Future<Integer> second = executor.submit(() -> registerStatus(username, start));
			start.countDown();
			assertThat(List.of(first.get(), second.get())).containsExactlyInAnyOrder(200, 409);
		}
		finally {
			executor.shutdownNow();
		}
	}

	@Test
	void resetPasswordAnonymouslyInvalidatesOldPasswordAndToken() throws Exception {
		String username = "reset_user";
		String newPassword = " new-password ";
		body(send("/users", "POST", credentials(username, "password1"), null));
		String oldToken = body(send("/users/login", "POST", credentials(username, "password1"), null))
				.path("token").asText();

		HttpResponse<String> reset = send("/users/reset-password", "POST",
				resetRequest(" RESET_User ", newPassword), null);
		assertThat(reset.statusCode()).isEqualTo(200);
		assertThat(reset.body()).isEmpty();
		assertProblem(send("/users/me", "GET", null, oldToken), 401, "NOT_AUTHENTICATED");
		assertProblem(send("/users/login", "POST", credentials(username, "password1"), null),
				401, "BAD_CREDENTIALS");
		assertProblem(send("/users/login", "POST", credentials(username, newPassword.strip()), null),
				401, "BAD_CREDENTIALS");

		String stored = jdbc.queryForObject("SELECT password FROM users WHERE username = ?", String.class, username);
		assertThat(stored).isNotEqualTo(newPassword);
		assertThat(passwordEncoder.matches(newPassword, stored)).isTrue();
		String newToken = body(send("/users/login", "POST", credentials(username, newPassword), null))
				.path("token").asText();
		assertThat(newToken).isNotEqualTo(oldToken);
		body(send("/users/me", "GET", null, newToken));
		assertProblem(send("/users/me", "GET", null, oldToken), 401, "NOT_AUTHENTICATED");
		assertThat(new ResetPasswordRequest(username, newPassword).toString()).doesNotContain(newPassword);
	}

	@Test
	void resetPasswordValidatesInputAndPreservesExistingLoginOnFailure() throws Exception {
		String username = "reset_validation";
		body(send("/users", "POST", credentials(username, "password1"), null));
		String token = body(send("/users/login", "POST", credentials(username, "password1"), null))
				.path("token").asText();
		for (String password : List.of("", "short", "x".repeat(65))) {
			assertProblem(send("/users/reset-password", "POST", resetRequest(username, password), null),
					400, "INVALID_PASSWORD");
		}
		assertProblem(send("/users/reset-password", "POST", "{\"username\":\"" + username + "\"}", null),
				400, "INVALID_PASSWORD");
		assertProblem(send("/users/reset-password", "POST", resetRequest("??", "password2"), null),
				400, "INVALID_ACCOUNT");
		assertProblem(send("/users/reset-password", "POST", "{}", null), 400, "INVALID_ACCOUNT");
		assertProblem(send("/users/reset-password", "POST", "{", null), 400, "INVALID_CREDENTIALS");
		assertProblem(send("/users/reset-password", "POST", "", null), 400, "INVALID_CREDENTIALS");
		assertProblem(send("/users/reset-password", "POST", resetRequest("missing_reset", "password2"), null),
				401, "ACCOUNT_NOT_FOUND");
		body(send("/users/me", "GET", null, token));
		body(send("/users/login", "POST", credentials(username, "password1"), null));
	}

	@Test
	void resetPasswordRollsBackWhenSessionRevocationFails() throws Exception {
		String username = "reset_rollback";
		long userId = body(send("/users", "POST", credentials(username, "password1"), null)).path("id").asLong();
		String token = body(send("/users/login", "POST", credentials(username, "password1"), null))
				.path("token").asText();
		doThrow(new DataAccessResourceFailureException("测试登录存储不可用")).when(sessionStore).revoke(userId);

		assertProblem(send("/users/reset-password", "POST", resetRequest(username, "password2"), null),
				503, "DATA_STORE_UNAVAILABLE");
		body(send("/users/me", "GET", null, token));
		body(send("/users/login", "POST", credentials(username, "password1"), null));
		assertProblem(send("/users/login", "POST", credentials(username, "password2"), null),
				401, "BAD_CREDENTIALS");
	}

	@Test
	void concurrentLoginAndResetDoNotLeaveOldCredentialsAuthenticated() throws Exception {
		String username = "reset_concurrent";
		body(send("/users", "POST", credentials(username, "password1"), null));
		ExecutorService executor = Executors.newFixedThreadPool(2);
		CountDownLatch start = new CountDownLatch(1);
		try {
			Future<HttpResponse<String>> login = executor.submit(() -> {
				start.await();
				return send("/users/login", "POST", credentials(username, "password1"), null);
			});
			Future<HttpResponse<String>> reset = executor.submit(() -> {
				start.await();
				return send("/users/reset-password", "POST", resetRequest(username, "password2"), null);
			});
			start.countDown();
			assertThat(reset.get().statusCode()).isEqualTo(200);
			HttpResponse<String> loginResponse = login.get();
			assertThat(loginResponse.statusCode()).isIn(200, 401);
			if (loginResponse.statusCode() == 200) {
				String token = json.readTree(loginResponse.body()).path("token").asText();
				assertProblem(send("/users/me", "GET", null, token), 401, "NOT_AUTHENTICATED");
			}
			else {
				assertProblem(loginResponse, 401, "BAD_CREDENTIALS");
			}
			body(send("/users/login", "POST", credentials(username, "password2"), null));
		}
		finally {
			executor.shutdownNow();
		}
	}

	private void assertProblem(HttpResponse<String> response, int status, String code) throws Exception {
		assertThat(response.statusCode()).isEqualTo(status);
		assertThat(response.headers().firstValue("Content-Type")).hasValueSatisfying(
				contentType -> assertThat(contentType).startsWith("application/problem+json"));
		assertThat(json.readTree(response.body()).path("code").asText()).isEqualTo(code);
	}

	private String resetRequest(String username, String newPassword) throws Exception {
		return json.writeValueAsString(Map.of("username", username, "newPassword", newPassword));
	}

	private int registerStatus(String username, CountDownLatch start) throws Exception {
		start.await();
		return send("/users", "POST", credentials(username, "password1"), null).statusCode();
	}

	private JsonNode body(HttpResponse<String> response) throws Exception {
		assertThat(response.statusCode()).isEqualTo(200);
		return json.readTree(response.body());
	}

	private String credentials(String username, String password) {
		return "{\"username\":\"" + username + "\",\"password\":\"" + password + "\"}";
	}

	private HttpResponse<String> send(String path, String method, String body, String token) throws Exception {
		HttpRequest.Builder builder = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path))
				.header("Content-Type", "application/json");
		if (token != null) {
			builder.header("Authorization", "Bearer " + token);
		}
		if ("GET".equals(method)) {
			builder.GET();
		}
		else {
			builder.method(method, HttpRequest.BodyPublishers.ofString(body == null ? "" : body));
		}
		return http.send(builder.build(), HttpResponse.BodyHandlers.ofString());
	}

}
