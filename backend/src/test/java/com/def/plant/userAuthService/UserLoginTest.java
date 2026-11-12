package com.def.plant.userAuthService;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * 注册、登录、当前用户和退出。数据库和 Redis 使用 Testcontainers，不连接服务器。
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

	@DynamicPropertySource
	static void properties(DynamicPropertyRegistry registry) {
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
