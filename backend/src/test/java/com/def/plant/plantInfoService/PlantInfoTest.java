package com.def.plant.plantInfoService;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;

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
 * 植物档案 HTTP 契约、持久化和用户隔离，使用独立 PostgreSQL 与 Redis 容器。
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class PlantInfoTest {

	@Container
	static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16");

	@Container
	static final GenericContainer<?> REDIS = new GenericContainer<>(DockerImageName.parse("redis:7"))
			.withExposedPorts(6379);

	private final HttpClient http = HttpClient.newHttpClient();

	private final ObjectMapper json = new ObjectMapper();

	@LocalServerPort
	private int port;

	@DynamicPropertySource
	static void properties(DynamicPropertyRegistry registry) {
		registry.add("spring.flyway.enabled", () -> "true");
		registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
		registry.add("spring.datasource.username", POSTGRES::getUsername);
		registry.add("spring.datasource.password", POSTGRES::getPassword);
		registry.add("spring.data.redis.host", REDIS::getHost);
		registry.add("spring.data.redis.port", () -> REDIS.getMappedPort(6379));
		registry.add("app.jwt.secret", () -> "0123456789abcdef0123456789abcdef");
	}

	@Test
	void createListReadUpdateAndDelete() throws Exception {
		String token = login("plant_lifecycle");
		JsonNode created = ok(send("/plants", "POST", """
				{"nickname":" 小绿 ","species":" 绿萝 ","plantingDate":"2024-03-12",
				 "careStartDate":"2025-01-02","growingLocation":"INDOOR",
				 "cultivationMethod":"SOIL","description":" 窗边养护 "}
				""", token));
		long id = created.path("id").asLong();
		assertThat(id).isPositive();
		assertThat(created.path("nickname").asText()).isEqualTo("小绿");
		assertThat(created.path("species").asText()).isEqualTo("绿萝");
		assertThat(created.path("plantingDate").asText()).isEqualTo("2024-03-12");
		assertThat(created.path("careStartDate").asText()).isEqualTo("2025-01-02");
		assertThat(created.path("growingLocation").asText()).isEqualTo("INDOOR");
		assertThat(created.path("cultivationMethod").asText()).isEqualTo("SOIL");
		assertThat(created.path("description").asText()).isEqualTo("窗边养护");
		assertThat(created.has("userId")).isFalse();
		assertThat(ok(send("/plants/" + id, "GET", null, token))).isEqualTo(created);
		assertThat(ok(send("/plants", "GET", null, token)).get(0)).isEqualTo(created);

		JsonNode updated = ok(send("/plants/" + id, "PUT", """
				{"nickname":"新名字","species":"龟背竹","plantingDate":"2023-05-06",
				 "careStartDate":"2024-07-08","growingLocation":"OUTDOOR",
				 "cultivationMethod":"WATER","description":"新的描述"}
				""", token));
		assertThat(updated.path("id").asLong()).isEqualTo(id);
		assertThat(updated.path("nickname").asText()).isEqualTo("新名字");
		assertThat(updated.path("species").asText()).isEqualTo("龟背竹");
		assertThat(updated.path("plantingDate").asText()).isEqualTo("2023-05-06");
		assertThat(updated.path("careStartDate").asText()).isEqualTo("2024-07-08");
		assertThat(updated.path("growingLocation").asText()).isEqualTo("OUTDOOR");
		assertThat(updated.path("cultivationMethod").asText()).isEqualTo("WATER");
		assertThat(updated.path("description").asText()).isEqualTo("新的描述");
		assertThat(ok(send("/plants/" + id, "GET", null, token))).isEqualTo(updated);
		assertThat(send("/plants/" + id, "DELETE", null, token).statusCode()).isEqualTo(200);
		assertThat(ok(send("/plants", "GET", null, token)).size()).isZero();
		assertProblem(send("/plants/" + id, "GET", null, token), 404, "PLANT_NOT_FOUND");
		assertProblem(send("/plants/" + id, "PUT", "{\"species\":\"绿萝\"}", token), 404, "PLANT_NOT_FOUND");
		assertProblem(send("/plants/" + id, "DELETE", null, token), 404, "PLANT_NOT_FOUND");
	}

	@Test
	void defaultsOptionalFieldsAndListOrder() throws Exception {
		String token = login("plant_defaults");
		LocalDate before = LocalDate.now(ZoneId.of("Asia/Shanghai"));
		JsonNode first = ok(send("/plants", "POST", """
				{"species":" 绿萝 ","nickname":"  ","description":"  ","careStartDate":null}
				""", token));
		assertThat(first.path("nickname").asText()).isEqualTo("绿萝");
		assertThat(first.path("species").asText()).isEqualTo("绿萝");
		assertThat(first.path("careStartDate").asText()).isIn(before.toString(), LocalDate.now(ZoneId.of("Asia/Shanghai")).toString());
		for (String field : List.of("plantingDate", "growingLocation", "cultivationMethod", "description")) {
			assertThat(first.get(field).isNull()).as(field).isTrue();
		}
		JsonNode second = ok(send("/plants", "POST", "{\"species\":\"绿萝\"}", token));
		JsonNode list = ok(send("/plants", "GET", null, token));
		assertThat(list.size()).isEqualTo(2);
		assertThat(list.get(0)).isEqualTo(second);
		assertThat(list.get(1)).isEqualTo(first);
	}

	@Test
	void updateCanClearAllOptionalFieldsAndReapplyDefaults() throws Exception {
		String token = login("plant_clear");
		JsonNode created = ok(send("/plants", "POST", """
				{"species":"绿萝","nickname":"小绿","plantingDate":"2020-01-01",
				 "careStartDate":"2020-02-01","growingLocation":"INDOOR",
				 "cultivationMethod":"SOIL","description":"原有描述"}
				""", token));
		String path = "/plants/" + created.path("id").asLong();
		JsonNode updated = ok(send(path, "PUT", """
				{"species":" 吊兰 ","nickname":null,"plantingDate":null,"careStartDate":null,
				 "growingLocation":null,"cultivationMethod":null,"description":null}
				""", token));
		assertThat(updated.path("nickname").asText()).isEqualTo("吊兰");
		assertThat(updated.path("careStartDate").asText()).isEqualTo(LocalDate.now(ZoneId.of("Asia/Shanghai")).toString());
		for (String field : List.of("plantingDate", "growingLocation", "cultivationMethod", "description")) {
			assertThat(updated.get(field).isNull()).as(field).isTrue();
		}
		assertThat(ok(send(path, "GET", null, token))).isEqualTo(updated);
	}

	@Test
	void privatePlantsCannotBeReadChangedOrDeletedByAnotherUser() throws Exception {
		String owner = login("plant_owner");
		String other = login("plant_other");
		JsonNode plant = ok(send("/plants", "POST", "{\"species\":\"绿萝\",\"userId\":999999,\"id\":999999}", owner));
		String path = "/plants/" + plant.path("id").asLong();
		assertThat(ok(send("/plants", "GET", null, other)).size()).isZero();
		assertProblem(send(path, "GET", null, other), 404, "PLANT_NOT_FOUND");
		assertProblem(send(path, "PUT", "{\"species\":\"吊兰\"}", other), 404, "PLANT_NOT_FOUND");
		assertProblem(send(path, "DELETE", null, other), 404, "PLANT_NOT_FOUND");
		assertThat(ok(send(path, "GET", null, owner))).isEqualTo(plant);
		String relogged = ok(send("/users/login", "POST", credentials("plant_owner"), null)).path("token").asText();
		assertThat(ok(send(path, "GET", null, relogged))).isEqualTo(plant);
	}

	@Test
	void everyPlantEndpointRequiresLogin() throws Exception {
		for (var endpoint : List.of(Map.entry("GET", "/plants"), Map.entry("GET", "/plants/1"),
				Map.entry("POST", "/plants"), Map.entry("PUT", "/plants/1"), Map.entry("DELETE", "/plants/1"))) {
			assertProblem(send(endpoint.getValue(), endpoint.getKey(), "{\"species\":\"绿萝\"}", null),
					401, "NOT_AUTHENTICATED");
		}
	}

	@Test
	void invalidFieldsDatesAndIdsReturnProblemDetailsWithoutWriting() throws Exception {
		String token = login("plant_validation");
		List<String> invalid = List.of("{}", "null", "{", "{\"species\":\"  \"}",
				json.writeValueAsString(Map.of("species", "绿".repeat(101))),
				json.writeValueAsString(Map.of("species", "绿萝", "nickname", "名".repeat(101))),
				json.writeValueAsString(Map.of("species", "绿萝", "description", "文".repeat(1001))),
				"{\"species\":\"绿萝\",\"plantingDate\":\"2026-02-30\"}",
				"{\"species\":\"绿萝\",\"careStartDate\":\"2026/01/01\"}",
				"{\"species\":\"绿萝\",\"growingLocation\":\"GARDEN\"}",
				"{\"species\":\"绿萝\",\"cultivationMethod\":\"MIXED\"}");
		for (String body : invalid) {
			assertProblem(send("/plants", "POST", body, token), 400, "INVALID_PLANT_INFO");
		}
		assertThat(ok(send("/plants", "GET", null, token)).size()).isZero();
		JsonNode plant = ok(send("/plants", "POST", "{\"species\":\"绿萝\"}", token));
		String path = "/plants/" + plant.path("id").asLong();
		assertProblem(send(path, "PUT", "{\"species\":\" \"}", token), 400, "INVALID_PLANT_INFO");
		assertThat(ok(send(path, "GET", null, token))).isEqualTo(plant);
		assertProblem(send("/plants/abc", "GET", null, token), 400, "INVALID_PLANT_INFO");
		assertProblem(send("/plants/-1", "GET", null, token), 404, "PLANT_NOT_FOUND");
	}

	@Test
	void browserPreflightAllowsUpdatesAndDeletion() throws Exception {
		for (String method : List.of("PUT", "DELETE")) {
			HttpRequest request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/plants/1"))
					.header("Origin", "http://localhost:8088")
					.header("Access-Control-Request-Method", method)
					.header("Access-Control-Request-Headers", "authorization,content-type")
					.method("OPTIONS", HttpRequest.BodyPublishers.noBody()).build();
			HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
			assertThat(response.statusCode()).isEqualTo(200);
			assertThat(response.headers().firstValue("Access-Control-Allow-Methods").orElseThrow()).contains(method);
		}
	}

	@Test
	void concurrentDeletionRemovesOneRowAndNeverRecreatesPlant() throws Exception {
		String token = login("plant_concurrent");
		JsonNode created = ok(send("/plants", "POST", "{\"species\":\"绿萝\"}", token));
		String path = "/plants/" + created.path("id").asLong();
		CountDownLatch start = new CountDownLatch(1);
		try (var executor = Executors.newFixedThreadPool(3)) {
			var first = executor.submit(() -> { start.await(); return send(path, "DELETE", null, token).statusCode(); });
			var second = executor.submit(() -> { start.await(); return send(path, "DELETE", null, token).statusCode(); });
			var update = executor.submit(() -> { start.await(); return send(path, "PUT", "{\"species\":\"吊兰\"}", token).statusCode(); });
			start.countDown();
			assertThat(List.of(first.get(), second.get())).containsExactlyInAnyOrder(200, 404);
			assertThat(update.get()).isIn(200, 404);
		}
		assertProblem(send(path, "GET", null, token), 404, "PLANT_NOT_FOUND");
	}

	private String login(String username) throws Exception {
		ok(send("/users", "POST", credentials(username), null));
		return ok(send("/users/login", "POST", credentials(username), null)).path("token").asText();
	}

	private String credentials(String username) {
		return "{\"username\":\"" + username + "\",\"password\":\"password1\"}";
	}

	private JsonNode ok(HttpResponse<String> response) throws Exception {
		assertThat(response.statusCode()).as(response.body()).isEqualTo(200);
		return json.readTree(response.body());
	}

	private void assertProblem(HttpResponse<String> response, int status, String code) throws Exception {
		assertThat(response.statusCode()).as(response.body()).isEqualTo(status);
		assertThat(response.headers().firstValue("Content-Type").orElseThrow()).contains("application/problem+json");
		assertThat(json.readTree(response.body()).path("code").asText()).isEqualTo(code);
	}

	private HttpResponse<String> send(String path, String method, String body, String token) throws Exception {
		HttpRequest.Builder builder = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path))
				.header("Content-Type", "application/json");
		if (token != null) {
			builder.header("Authorization", "Bearer " + token);
		}
		builder.method(method, body == null ? HttpRequest.BodyPublishers.noBody() : HttpRequest.BodyPublishers.ofString(body));
		return http.send(builder.build(), HttpResponse.BodyHandlers.ofString());
	}

}
