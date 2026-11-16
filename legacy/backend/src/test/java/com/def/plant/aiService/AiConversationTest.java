package com.def.plant.aiService;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.nullable;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.UUID;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.Executors;

import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.boot.web.server.context.WebServerApplicationContext;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;
import org.flywaydb.core.Flyway;

import com.def.plant.PlantApplication;
import com.def.plant.aiService.service.AiConversationService;
import com.def.plant.aiService.dto.ConversationRequest;
import com.def.plant.aiService.dto.ConversationPlantRequest;
import com.def.plant.aiService.dto.QuestionRequest;
import com.def.plant.aiService.mapper.AiMapper;
import com.def.plant.plantKnowledgeService.client.NcStateClient;
import com.def.plant.plantKnowledgeService.KnowledgeFixtures;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

/** HTTP、真实 Spring AI 适配器及隔离 PostgreSQL/Redis 的集成验证。 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class AiConversationTest {
    @Container
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16");
    @Container
    static final GenericContainer<?> REDIS = new GenericContainer<>(DockerImageName.parse("redis:7")).withExposedPorts(6379);
    static final ObjectMapper JSON = new ObjectMapper();
    static final List<JsonNode> MODEL_REQUESTS = new CopyOnWriteArrayList<>();
    static final HttpServer MODEL = modelServer();
    final HttpClient http = HttpClient.newHttpClient();
    @LocalServerPort int port;
    @Autowired JdbcTemplate jdbc;
    @Autowired AiMapper mapper;
    @MockitoSpyBean AiConversationService conversations;
    @MockitoBean NcStateClient knowledgeClient;

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        settings().forEach((key, value) -> registry.add(key, () -> value));
    }

    static Map<String, Object> settings() {
        return Map.ofEntries(
                Map.entry("spring.flyway.enabled", "true"),
                Map.entry("spring.datasource.url", POSTGRES.getJdbcUrl()),
                Map.entry("spring.datasource.username", POSTGRES.getUsername()),
                Map.entry("spring.datasource.password", POSTGRES.getPassword()),
                Map.entry("spring.data.redis.host", REDIS.getHost()),
                Map.entry("spring.data.redis.port", REDIS.getMappedPort(6379)),
                Map.entry("app.jwt.secret", "0123456789abcdef0123456789abcdef"),
                Map.entry("app.ai.base-url", "http://localhost:" + MODEL.getAddress().getPort() + "/v1"),
                Map.entry("app.ai.api-key", "isolated-test-key"),
                Map.entry("app.ai.model", "test-model"),
                Map.entry("app.ai.memory-turns", 2),
                Map.entry("app.ai.input-budget-bytes", 9000),
                Map.entry("app.ai.timeout-seconds", 3));
    }

    @AfterAll static void closeModel() { MODEL.stop(0); }

    @Test
    void schemaUpgradePreservesHistoryAndModelMetadata() {
        String schema = "ai_upgrade";
        Flyway.configure().dataSource(POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword())
                .schemas(schema).defaultSchema(schema).target("3").load().migrate();
        var source = new DriverManagerDataSource(POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword());
        var connectionProperties = new Properties();
        connectionProperties.setProperty("currentSchema", schema);
        source.setConnectionProperties(connectionProperties);
        var old = new JdbcTemplate(source);
        long userId = old.queryForObject("INSERT INTO users(username,password) VALUES ('migration','test') RETURNING id", Long.class);
        String conversationId = UUID.randomUUID().toString();
        String turnId = UUID.randomUUID().toString();
        String requestId = UUID.randomUUID().toString();
        old.update("INSERT INTO ai_conversations(id,user_id,scope,title) VALUES (?,?,'GENERAL','历史会话')", conversationId, userId);
        old.update("""
                INSERT INTO ai_turns(id,conversation_id,request_id,sequence,status,run_id,lease_until,model,prompt_version)
                VALUES (?,?,?,1,'COMPLETED',?,CURRENT_TIMESTAMP,'historical-model','plant-care-v1')
                """, turnId, conversationId, requestId, UUID.randomUUID().toString());
        old.update("INSERT INTO ai_messages(id,turn_id,sequence,role,content) VALUES (?,?,0,'USER','历史问题')",
                UUID.randomUUID().toString(), turnId);
        old.update("""
                INSERT INTO ai_messages(id,turn_id,sequence,role,content,metadata)
                VALUES (?,?,1,'ASSISTANT','历史回答','{"inputTokens":10}'::jsonb)
                """, UUID.randomUUID().toString(), turnId);

        Flyway.configure().dataSource(source).schemas(schema).defaultSchema(schema).load().migrate();

        assertThat(old.queryForObject("SELECT user_id FROM ai_conversations WHERE id=?", Long.class, conversationId)).isEqualTo(userId);
        assertThat(old.queryForObject("SELECT status FROM ai_turns WHERE id=?", String.class, turnId)).isEqualTo("COMPLETED");
        assertThat(old.queryForObject("SELECT request_id FROM ai_turns WHERE id=?", String.class, turnId)).isEqualTo(requestId);
        assertThat(old.queryForList("SELECT content FROM ai_messages ORDER BY sequence", String.class)).containsExactly("历史问题", "历史回答");
        assertThat(old.queryForObject("SELECT metadata->>'model' FROM ai_messages WHERE sequence=1", String.class)).isEqualTo("historical-model");
        assertThat(old.queryForObject("SELECT metadata->>'inputTokens' FROM ai_messages WHERE sequence=1", String.class)).isEqualTo("10");
        assertThat(old.queryForList("SELECT column_name FROM information_schema.columns WHERE table_schema=? AND table_name='ai_turns'",
                String.class, schema)).doesNotContain("run_id", "model", "prompt_version");
        assertThat(old.queryForList("SELECT column_name FROM information_schema.columns WHERE table_schema=? AND table_name='ai_messages'",
                String.class, schema)).doesNotContain("updated_at");
    }

    @Test
    void simultaneousQuestionsCreateOnlyOneActiveTurn() throws Exception {
        long userId = jdbc.queryForObject("INSERT INTO users(username,password) VALUES ('ai_parallel','test') RETURNING id", Long.class);
        String id = conversations.create(userId, new ConversationRequest(null, null)).id();
        var ready = new java.util.concurrent.CountDownLatch(2);
        var start = new java.util.concurrent.CountDownLatch(1);
        java.util.concurrent.Callable<String> submit = () -> {
            ready.countDown();
            start.await();
            try {
                conversations.accept(userId, id, new QuestionRequest(UUID.randomUUID().toString(), "同时提问"));
                return "ACCEPTED";
            } catch (com.def.plant.common.exception.BusinessException exception) {
                return exception.errorCode().code();
            }
        };
        try (var workers = Executors.newVirtualThreadPerTaskExecutor()) {
            var first = workers.submit(submit);
            var second = workers.submit(submit);
            boolean bothReady = ready.await(5, java.util.concurrent.TimeUnit.SECONDS);
            start.countDown();
            assertThat(bothReady).isTrue();
            assertThat(List.of(first.get(5, java.util.concurrent.TimeUnit.SECONDS), second.get(5, java.util.concurrent.TimeUnit.SECONDS)))
                    .containsExactlyInAnyOrder("ACCEPTED", "AI_CONVERSATION_BUSY");
        }
        assertThat(jdbc.queryForObject("SELECT count(*) FROM ai_turns WHERE conversation_id=?", Integer.class, id)).isEqualTo(1);
        assertThat(conversations.messages(userId, id, Long.MAX_VALUE, 20)).hasSize(2);
    }

    @Test
    void terminalTurnsCannotBeOverwrittenAndContentFailureRollsBackState() {
        long userId = jdbc.queryForObject("INSERT INTO users(username,password) VALUES ('ai_atomic','test') RETURNING id", Long.class);
        String id = conversations.create(userId, new ConversationRequest(null, null)).id();
        var first = conversations.accept(userId, id, new QuestionRequest(UUID.randomUUID().toString(), "保存正文"));
        // 非法 JSON 使正文保存失败，验证此前的状态更新也被同一事务回滚。
        org.assertj.core.api.Assertions.assertThatThrownBy(() -> conversations.save(userId, first.turn(), "正文", "invalid-json", "COMPLETED", null))
                .isInstanceOf(org.springframework.dao.DataAccessException.class);
        assertThat(conversations.turn(userId, id, first.turn().id()).status()).isEqualTo("ACCEPTED");
        assertThat(conversations.turn(userId, id, first.turn().id()).content()).isEmpty();
        assertThat(conversations.save(userId, first.turn(), "最终正文", "{}", "COMPLETED", null)).isTrue();
        assertThat(conversations.cancel(userId, id, first.turn().id()).status()).isEqualTo("COMPLETED");
        assertThat(conversations.save(userId, first.turn(), "过期写入", "{}", "FAILED", "AI_UPSTREAM_FAILED")).isFalse();
        assertThat(mapper.renew(userId, first.turn().id())).isZero();
        assertThat(conversations.turn(userId, id, first.turn().id()).content()).isEqualTo("最终正文");

        var second = conversations.accept(userId, id, new QuestionRequest(UUID.randomUUID().toString(), "新的问题"));
        conversations.cancel(userId, id, second.turn().id());
        assertThat(conversations.save(userId, second.turn(), "取消后正文", "{}", "COMPLETED", null)).isFalse();
        assertThat(conversations.turn(userId, id, second.turn().id()).status()).isEqualTo("CANCELLED");
        assertThat(conversations.turn(userId, id, second.turn().id()).content()).isEmpty();
    }

    @Test
    void streamPersistsHistoryAndDuplicateRequestsDoNotGenerateTwice() throws Exception {
        String token = login("ai_history");
        String id = create(token, null);
        String request = question("记住：我昨天把绿萝移到了北窗");
        var response = send(path(id), "POST", request, token);
        assertThat(response.statusCode()).as(response.body()).isEqualTo(200);
        assertThat(response.body()).contains("event:accepted", "event:delta", "event:done", "检查土壤");
        var messages = body(send(path(id), "GET", null, token));
        assertThat(messages.size()).isEqualTo(2);
        assertThat(messages.get(1).path("content").asText()).isEqualTo("请检查土壤干湿。");
        assertThat(messages.get(1).path("status").asText()).isEqualTo("COMPLETED");
        String turnId = messages.get(1).path("turnId").asText();
        assertThat(body(send("/ai/conversations/" + id + "/turns/" + turnId, "GET", null, token)).has("runId")).isFalse();
        int calls = MODEL_REQUESTS.size();
        assertThat(send(path(id), "POST", request, token).body()).contains("event:done");
        assertThat(MODEL_REQUESTS).hasSize(calls);
        String sameId = JSON.readTree(request).path("requestId").asText();
        problem(send(path(id), "POST", JSON.writeValueAsString(Map.of("requestId",sameId,"content","其他问题")),token),409,"AI_REQUEST_CONFLICT");
        assertThat(send(path(id),"POST",question("那今天呢？"),token).body()).contains("event:done");
        JsonNode modelRequest = lastRequest();
        assertThat(modelRequest.path("thinking").path("type").asText()).isEqualTo("disabled");
        assertThat(modelRequest.path("messages").toString()).contains("我昨天把绿萝移到了北窗", "请检查土壤干湿", "那今天呢");
        assertThat(modelRequest.path("messages").findValuesAsText("content").stream().filter(value -> value.equals("那今天呢？")).count()).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM ai_messages WHERE metadata->>'model'='test-model'",Integer.class)).isPositive();
    }

    @Test
    void newestCompleteTurnsAreLoadedAfterNewApplicationInstanceStarts() throws Exception {
        String token = login("ai_restart");
        String id = create(token, null);
        for (int i=0;i<3;i++) assertThat(send(path(id),"POST",question("历史问题"+i),token).body()).contains("event:done");
        List<String> args = new ArrayList<>(List.of("--server.port=0", "--spring.main.banner-mode=off"));
        settings().forEach((key,value)->args.add("--"+key+"="+value));
        try (var restarted = SpringApplication.run(PlantApplication.class,args.toArray(String[]::new))) {
            int newPort = ((WebServerApplicationContext) restarted).getWebServer().getPort();
            var response = sendTo(newPort,path(id),"POST",question("重启后继续"),token);
            assertThat(response.body()).as(response.body()).contains("event:done");
            String context = lastRequest().path("messages").toString();
            assertThat(context).contains("历史问题1","历史问题2","重启后继续").doesNotContain("历史问题0");
        }
        assertThat(body(send(path(id),"GET",null,token)).size()).isEqualTo(8);
        assertThat(body(send(path(id)+"?before=3&limit=1","GET",null,token)).get(0).path("content").asText()).isEqualTo("历史问题1");
    }

    @Test
    void missingModelConfigurationKeepsAccountsAndHistoryAvailable() throws Exception {
        String token = login("ai_unconfigured");
        String id = create(token, null);
        List<String> args = new ArrayList<>(List.of("--server.port=0", "--spring.main.banner-mode=off"));
        settings().forEach((key, value) -> {
            if (!key.equals("app.ai.api-key")) args.add("--" + key + "=" + value);
        });
        args.add("--app.ai.api-key=");
        try (var application = SpringApplication.run(PlantApplication.class, args.toArray(String[]::new))) {
            int localPort = ((WebServerApplicationContext) application).getWebServer().getPort();
            assertThat(body(sendTo(localPort, "/plants", "GET", null, token)).isArray()).isTrue();
            assertThat(body(sendTo(localPort, path(id), "GET", null, token)).size()).isZero();
            var response = sendTo(localPort, path(id), "POST", question("你好"), token);
            problem(response, 503, "AI_NOT_CONFIGURED");
            assertThat(response.headers().firstValue("Content-Type").orElseThrow()).contains("application/problem+json");
            assertThat(application.getBeanFactory().containsSingleton("modelHttpClient")).isFalse();
        }
        assertThat(body(send(path(id), "GET", null, token)).size()).isZero();
    }

    @Test
    void plantSelectionPersistsAcrossSwitchesWithEachTurnsOriginalContext() throws Exception {
        String token = login("ai_plant_selection");
        long first = body(send("/plants", "POST",
                "{\"species\":\"绿萝\",\"nickname\":\"窗边绿萝\",\"cultivationMethod\":\"WATER\"}", token)).path("id").asLong();
        long second = body(send("/plants", "POST",
                "{\"species\":\"吊兰\",\"nickname\":\"阳台吊兰\",\"cultivationMethod\":\"SOIL\"}", token)).path("id").asLong();
        String id = create(token, null);
        String resource = "/ai/conversations/" + id;
        var selected = body(send(resource + "/plant", "PUT", JSON.writeValueAsString(Map.of("plantId", first)), token));
        assertThat(selected.path("scope").asText()).isEqualTo("PLANT");
        assertThat(selected.path("plantName").asText()).isEqualTo("窗边绿萝");
        assertThat(body(send(resource, "GET", null, token)).path("plantId").asLong()).isEqualTo(first);
        assertThat(body(send("/ai/conversations", "GET", null, token)).get(0).path("plantName").asText()).isEqualTo("窗边绿萝");
        String originalRequest = question("它应该怎么养？");
        assertThat(send(path(id), "POST", originalRequest, token).body()).contains("event:done");
        assertThat(lastRequest().path("messages").toString()).contains("窗边绿萝", "WATER");
        String turnId = body(send(path(id), "GET", null, token)).get(0).path("turnId").asText();
        String originalContext = jdbc.queryForObject(
                "SELECT metadata->>'plantContext' FROM ai_messages WHERE turn_id=? AND sequence=0", String.class, turnId);
        assertThat(originalContext).contains("窗边绿萝", "WATER");

        body(send("/plants/" + first, "PUT", "{\"species\":\"绿萝\",\"nickname\":\"改名绿萝\"}", token));
        assertThat(send(path(id), "POST", question("今天的档案呢？"), token).body()).contains("event:done");
        assertThat(lastRequest().path("messages").toString()).contains("改名绿萝", "窗边绿萝");
        body(send(resource + "/plant", "PUT", JSON.writeValueAsString(Map.of("plantId", second)), token));
        int calls = MODEL_REQUESTS.size();
        assertThat(send(path(id), "POST", originalRequest, token).body()).contains("event:done");
        assertThat(MODEL_REQUESTS).hasSize(calls);
        assertThat(jdbc.queryForObject("SELECT metadata->>'plantContext' FROM ai_messages WHERE turn_id=? AND sequence=0",
                String.class, turnId)).isEqualTo(originalContext);
        assertThat(send(path(id), "POST", question("它的培养方式是什么？"), token).body()).contains("event:done");
        var modelMessages = lastRequest().path("messages");
        assertThat(modelMessages.get(modelMessages.size() - 2).path("content").asText()).contains("阳台吊兰", "SOIL");
        assertThat(modelMessages.toString()).contains("窗边绿萝", "改名绿萝");

        var cleared = body(send(resource + "/plant", "PUT", "{\"plantId\":null}", token));
        assertThat(cleared.path("scope").asText()).isEqualTo("GENERAL");
        assertThat(cleared.path("plantId").isNull()).isTrue();
        assertThat(cleared.path("plantName").isNull()).isTrue();
        assertThat(send(path(id), "POST", question("什么是水培？"), token).body()).contains("event:done");
        modelMessages = lastRequest().path("messages");
        assertThat(modelMessages.get(modelMessages.size() - 2).path("content").asText()).contains("本轮未指定植物");
        assertThat(modelMessages.get(0).path("content").asText()).contains("用户询问通用问题", "用户明确询问其他植物");
    }

    @Test
    void selectedPlantDoesNotRestrictOtherPlantToolsAndDeletedSelectionCanBeCleared() throws Exception {
        String token = login("ai_plant_intent");
        long first = body(send("/plants", "POST", "{\"species\":\"绿萝\"}", token)).path("id").asLong();
        long second = body(send("/plants", "POST", "{\"species\":\"芦荟\"}", token)).path("id").asLong();
        String id = create(token, first);
        String resource = "/ai/conversations/" + id;
        assertThat(send(path(id), "POST", question("TOOL:" + second), token).body()).contains("event:done");
        assertThat(lastRequest().path("messages").toString()).contains("绿萝", "芦荟", "tool");
        body(send("/plants/" + first, "DELETE", null, token));
        var deleted = body(send(resource, "GET", null, token));
        assertThat(deleted.path("scope").asText()).isEqualTo("PLANT");
        assertThat(deleted.path("plantId").isNull()).isTrue();
        problem(send(path(id), "POST", question("它怎么样？"), token), 404, "PLANT_NOT_FOUND");
        body(send(resource + "/plant", "PUT", "{\"plantId\":null}", token));
        assertThat(send(path(id), "POST", question("继续通用问答"), token).body()).contains("event:done");
        body(send(resource + "/plant", "PUT", JSON.writeValueAsString(Map.of("plantId", second)), token));
        assertThat(body(send(resource, "GET", null, token)).path("plantId").asLong()).isEqualTo(second);
    }

    @Test
    void plantSelectionValidatesOwnershipAndInputWithoutChangingSavedChoice() throws Exception {
        String owner = login("ai_selection_owner");
        String other = login("ai_selection_other");
        long plant = body(send("/plants", "POST", "{\"species\":\"玉树\"}", owner)).path("id").asLong();
        String id = create(owner, plant);
        String resource = "/ai/conversations/" + id;
        String otherResource = "/ai/conversations/" + create(other, null);
        problem(send(resource, "GET", null, other), 404, "AI_CONVERSATION_NOT_FOUND");
        problem(send(resource + "/plant", "PUT", "{\"plantId\":null}", other), 404, "AI_CONVERSATION_NOT_FOUND");
        problem(send(otherResource + "/plant", "PUT", JSON.writeValueAsString(Map.of("plantId", plant)), other),
                404, "PLANT_NOT_FOUND");
        for (String input : List.of("null", "{", "{\"plantId\":\"invalid\"}")) {
            problem(send(resource + "/plant", "PUT", input, owner), 400, "INVALID_AI_INPUT");
        }
        problem(send(resource + "/plant", "PUT", "{\"plantId\":-1}", owner), 404, "PLANT_NOT_FOUND");
        problem(send(resource, "GET", null, null), 401, "NOT_AUTHENTICATED");
        problem(send(resource + "/plant", "PUT", "{}", null), 401, "NOT_AUTHENTICATED");
        assertThat(body(send(resource, "GET", null, owner)).path("plantId").asLong()).isEqualTo(plant);
        assertThat(body(send(path(id), "GET", null, owner)).size()).isZero();
    }

    @Test
    void concurrentPlantDeletionReturnsNotFoundWithoutDeadlockingSelection() throws Exception {
        long userId = jdbc.queryForObject("INSERT INTO users(username,password) VALUES ('ai_select_delete','test') RETURNING id", Long.class);
        long plantId = jdbc.queryForObject("INSERT INTO plants(user_id,nickname,species,care_start_date) VALUES (?,'待删除植物','绿萝',CURRENT_DATE) RETURNING id", Long.class, userId);
        String id = conversations.create(userId, new ConversationRequest(null, null)).id();
        try (var connection = jdbc.getDataSource().getConnection();
                var workers = Executors.newVirtualThreadPerTaskExecutor()) {
            connection.setAutoCommit(false);
            try (var locking = connection.prepareStatement("SELECT id FROM plants WHERE id=? FOR UPDATE")) {
                locking.setLong(1, plantId);
                locking.executeQuery().close();
            }
            var selecting = workers.submit(() -> {
                try {
                    conversations.selectPlant(userId, id, new ConversationPlantRequest(plantId));
                    return "SELECTED";
                } catch (com.def.plant.common.exception.BusinessException error) {
                    return error.errorCode().code();
                }
            });
            long deadline = System.nanoTime() + Duration.ofSeconds(5).toNanos();
            boolean waiting = false;
            while (System.nanoTime() < deadline) {
                waiting = jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE datname=current_database() AND wait_event_type='Lock')", Boolean.class);
                if (waiting) break;
                Thread.sleep(20);
            }
            assertThat(waiting).isTrue();
            try (var deleting = connection.prepareStatement("DELETE FROM plants WHERE id=? AND user_id=?")) {
                deleting.setQueryTimeout(5);
                deleting.setLong(1, plantId);
                deleting.setLong(2, userId);
                assertThat(deleting.executeUpdate()).isEqualTo(1);
            } finally {
                connection.commit();
            }
            assertThat(selecting.get(5, java.util.concurrent.TimeUnit.SECONDS)).isEqualTo("PLANT_NOT_FOUND");
            assertThat(conversations.get(userId, id).plantId()).isNull();
        }
    }

    @Test
    void plantSelectionAndQuestionAcceptanceSerializeOnTheConversation() throws Exception {
        long userId = jdbc.queryForObject("INSERT INTO users(username,password) VALUES ('ai_select_parallel','test') RETURNING id", Long.class);
        long first = jdbc.queryForObject("INSERT INTO plants(user_id,nickname,species,care_start_date) VALUES (?,'原植物','绿萝',CURRENT_DATE) RETURNING id", Long.class, userId);
        long second = jdbc.queryForObject("INSERT INTO plants(user_id,nickname,species,care_start_date) VALUES (?,'新植物','吊兰',CURRENT_DATE) RETURNING id", Long.class, userId);
        String id = conversations.create(userId, new ConversationRequest(first, null)).id();
        var ready = new java.util.concurrent.CountDownLatch(2);
        var start = new java.util.concurrent.CountDownLatch(1);
        try (var workers = Executors.newVirtualThreadPerTaskExecutor()) {
            var selecting = workers.submit(() -> {
                ready.countDown(); start.await();
                try {
                    conversations.selectPlant(userId, id, new ConversationPlantRequest(second));
                    return "SELECTED";
                } catch (com.def.plant.common.exception.BusinessException error) {
                    return error.errorCode().code();
                }
            });
            var accepting = workers.submit(() -> {
                ready.countDown(); start.await();
                return conversations.accept(userId, id, new QuestionRequest(UUID.randomUUID().toString(), "它如何养护？"));
            });
            boolean bothReady = ready.await(5, java.util.concurrent.TimeUnit.SECONDS);
            start.countDown();
            assertThat(bothReady).isTrue();
            String result = selecting.get(5, java.util.concurrent.TimeUnit.SECONDS);
            var turn = accepting.get(5, java.util.concurrent.TimeUnit.SECONDS).turn();
            if (result.equals("SELECTED")) {
                assertThat(turn.plantContext()).contains("新植物").doesNotContain("原植物");
                assertThat(conversations.get(userId, id).plantId()).isEqualTo(second);
            } else {
                assertThat(result).isEqualTo("AI_CONVERSATION_BUSY");
                assertThat(turn.plantContext()).contains("原植物").doesNotContain("新植物");
                assertThat(conversations.get(userId, id).plantId()).isEqualTo(first);
            }
            org.assertj.core.api.Assertions.assertThatThrownBy(() ->
                    conversations.selectPlant(userId, id, new ConversationPlantRequest(null)))
                    .isInstanceOfSatisfying(com.def.plant.common.exception.BusinessException.class,
                            error -> assertThat(error.errorCode().code()).isEqualTo("AI_CONVERSATION_BUSY"));
            jdbc.update("UPDATE ai_turns SET lease_until=CURRENT_TIMESTAMP-INTERVAL '1 minute' WHERE id=?", turn.id());
            assertThat(conversations.selectPlant(userId, id, new ConversationPlantRequest(second)).plantId()).isEqualTo(second);
            assertThat(conversations.turn(userId, id, turn.id()).status()).isEqualTo("INTERRUPTED");
        }
    }

    @Test
    void ownerChecksCoverEveryEndpointAndPlantAssociation() throws Exception {
        String owner = login("ai_owner"); String other=login("ai_other");
        long plant = body(send("/plants","POST","{\"species\":\"绿萝\",\"cultivationMethod\":\"WATER\"}",owner)).path("id").asLong();
        String id=create(owner,plant);
        assertThat(body(send("/ai/conversations","GET",null,owner)).get(0).path("title").asText()).isEqualTo("绿萝");
        problem(send("/ai/conversations","POST",JSON.writeValueAsString(Map.of("plantId",plant)),other),404,"PLANT_NOT_FOUND");
        assertThat(body(send("/ai/conversations","GET",null,other)).size()).isZero();
        for (String method:List.of("GET","POST")) problem(send(path(id),method,question("你好"),other),404,"AI_CONVERSATION_NOT_FOUND");
        String turnId=UUID.randomUUID().toString();
        problem(send("/ai/conversations/"+id+"/turns/"+turnId,"GET",null,other),404,"AI_CONVERSATION_NOT_FOUND");
        problem(send("/ai/conversations/"+id+"/turns/"+turnId+"/cancel","POST","{}",other),404,"AI_CONVERSATION_NOT_FOUND");
        problem(send("/ai/conversations/"+id,"DELETE",null,other),404,"AI_CONVERSATION_NOT_FOUND");
        problem(send(path(id),"GET",null,null),401,"NOT_AUTHENTICATED");
        assertThat(send(path(id),"POST",question("你好"),owner).body()).contains("event:done");
        assertThat(lastRequest().path("messages").toString()).contains("绿萝","WATER");
        send("/plants/"+plant,"DELETE",null,owner);
        problem(send(path(id),"POST",question("再次提问"),owner),404,"PLANT_NOT_FOUND");
        assertThat(body(send(path(id),"GET",null,owner)).size()).isEqualTo(2);
        assertThat(send("/ai/conversations/"+id,"DELETE",null,owner).statusCode()).isEqualTo(200);
        problem(send(path(id),"GET",null,owner),404,"AI_CONVERSATION_NOT_FOUND");
    }

    @Test
    void cancelledFailedAndExpiredTurnsStayOutOfMemory() throws Exception {
        String token=login("ai_states"); String id=create(token,null);
        assertThat(send(path(id),"POST",question("FAIL"),token).body())
                .contains("event:error", "AI_UPSTREAM_FAILED").doesNotContain("event:done", "isolated-test-key");
        assertThat(send(path(id),"POST",question("TRUNCATE"),token).body()).contains("AI_OUTPUT_INCOMPLETE");
        assertThat(send(path(id),"POST",question("绿".repeat(3500)),token).body()).contains("AI_CONTEXT_TOO_LONG");
        String request=question("WAIT");
        var inFlight=http.sendAsync(request(port,path(id),"POST",request,token),HttpResponse.BodyHandlers.ofString());
        String turnId=awaitActive(id);
        problem(send(path(id),"POST",question("并发问题"),token),409,"AI_CONVERSATION_BUSY");
        assertThat(send(path(id),"POST",request,token).body()).contains("event:snapshot");
        assertThat(body(send("/ai/conversations/"+id+"/turns/"+turnId+"/cancel","POST","{}",token)).path("status").asText()).isEqualTo("CANCELLED");
        inFlight.get(5,java.util.concurrent.TimeUnit.SECONDS);
        String expiredRequest=question("WAIT");
        var expiring=http.sendAsync(request(port,path(id),"POST",expiredRequest,token),HttpResponse.BodyHandlers.ofString());
        String expired=awaitActive(id);
        jdbc.update("UPDATE ai_turns SET lease_until=CURRENT_TIMESTAMP-INTERVAL '1 minute' WHERE id=?",expired);
        var history=body(send(path(id),"GET",null,token));
        assertThat(history.get(history.size()-1).path("status").asText()).isEqualTo("INTERRUPTED");
        expiring.get(5,java.util.concurrent.TimeUnit.SECONDS);
        assertThat(send(path(id),"POST",question("正常提问"),token).body()).contains("event:done");
        assertThat(lastRequest().path("messages").toString()).doesNotContain("FAIL","TRUNCATE","WAIT");
    }

    @Test
    void timeoutAndActualToolCallingRespectOwnership() throws Exception {
        String token=login("ai_tools");String id=create(token,null);
        assertThat(send(path(id),"POST",question("WAIT"),token).body()).contains("AI_TIMEOUT");
        long own=body(send("/plants","POST","{\"species\":\"吊兰\"}",token)).path("id").asLong();
        assertThat(send(path(id),"POST",question("TOOL:"+own),token).body()).contains("event:done");
        assertThat(lastRequest().path("messages").toString()).contains("tool","吊兰");
        for (JsonNode tool : lastRequest().path("tools")) {
            JsonNode function = tool.path("function");
            JsonNode parameters = function.path("parameters").path("properties");
            assertThat(parameters.has("context")).isFalse();
            if (function.path("name").asText().equals("listPlants")) {
                assertThat(parameters.path("offset").path("description").asText()).contains("0到10000");
            }
            if (function.path("name").asText().equals("getPlant")) {
                assertThat(parameters.path("plantId").path("description").asText()).contains("当前用户", "植物编号");
            }
        }
        String other=login("ai_tool_other");
        String privateNickname = "私有植物-" + UUID.randomUUID();
        long otherPlant=body(send("/plants","POST",JSON.writeValueAsString(Map.of("species", "龟背竹", "nickname", privateNickname)),other)).path("id").asLong();
        assertThat(send(path(id),"POST",question("TOOL:"+otherPlant),token).body()).contains("PLANT_NOT_FOUND");
        assertThat(lastRequest().toString()).doesNotContain(privateNickname);
        for (JsonNode message : lastRequest().path("messages")) {
            if (!message.path("role").asText().equals("system")) assertThat(message.toString()).doesNotContain("龟背竹");
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"CARE", "CARE_COMBINED"})
    void careToolReturnsSourceEvidenceThroughActualSpringAiAndPersistsReply(String questionText) throws Exception {
        when(knowledgeClient.fetch("/find_a_plant/?q=golden+pothos"))
                .thenReturn(KnowledgeFixtures.search("/plants/epipremnum-aureum/"));
        when(knowledgeClient.fetch("/plants/epipremnum-aureum/")).thenReturn(KnowledgeFixtures.detail());
        String token = login(questionText.equals("CARE") ? "ai_care_tool" : "ai_care_combined"); String id = create(token, null);
        assertThat(send(path(id), "POST", question(questionText), token).body()).contains("event:done");
        JsonNode modelRequest = lastRequest();
        assertThat(modelRequest.path("messages").toString()).contains("CATEGORY_REFERENCE", "WATERING",
                "https://plants.ces.ncsu.edu/plants/epipremnum-aureum/", "In winter");
        JsonNode function = null;
        for (JsonNode tool : modelRequest.path("tools")) {
            if (tool.path("function").path("name").asText().equals("queryPlantCare")) function = tool.path("function");
        }
        assertThat(function).isNotNull();
        assertThat(function.path("description").asText())
                .contains("CATEGORY_REFERENCE", "NOT_FOUND", "topicsWithoutExplicitEvidence");
        JsonNode parameters = function.path("parameters").path("properties");
        assertThat(parameters.path("searchTerms").path("description").asText())
                .contains("1到3个", "2到80字符", "watering", "仙人球ball cactus", "绿萝golden pothos");
        assertThat(parameters.path("topics").path("description").asText()).contains("最多6项", "GENERAL_CARE");
        assertThat(parameters.path("question").path("description").asText()).contains("最多500字符");
        assertThat(function.path("parameters").path("required").toString()).contains("plantName", "searchTerms")
                .doesNotContain("topics", "question");
        JsonNode topicValues = function.path("parameters").path("properties").path("topics").path("items").path("enum");
        assertThat(topicValues.isArray()).isTrue();
        assertThat(topicValues).hasSize(com.def.plant.plantKnowledgeService.dto.CareTopic.values().length);
        assertThat(topicValues.toString()).contains("GENERAL_CARE", "WATERING", "REPOTTING");
        if (questionText.equals("CARE_COMBINED")) {
            JsonNode result = null;
            for (JsonNode message : modelRequest.path("messages")) {
                if (message.path("role").asText().equals("tool")) result = JSON.readTree(message.path("content").asText());
            }
            assertThat(result).isNotNull();
            assertThat(result.path("topicsWithoutExplicitEvidence").toString()).isEqualTo("[\"HUMIDITY\"]");
            assertThat(result.path("sources").get(0).path("evidence")).anySatisfy(item -> {
                assertThat(item.path("topic").asText()).isEqualTo("REPOTTING");
                assertThat(item.path("text").asText()).contains("Re-pot in spring");
            });
        }
        assertThat(body(send(path(id), "GET", null, token)).get(1).path("status").asText()).isEqualTo("COMPLETED");
    }

    @Test
    void careSourceFailureTerminatesSseAndKeepsTurnOutOfContext() throws Exception {
        when(knowledgeClient.fetch("/find_a_plant/?q=golden+pothos"))
                .thenThrow(new com.def.plant.common.exception.BusinessException(
                        com.def.plant.common.exception.ErrorCode.PLANT_KNOWLEDGE_UNAVAILABLE));
        String token = login("ai_care_failure"); String id = create(token, null);
        var response = send(path(id), "POST", question("CARE"), token);
        assertThat(response.body()).contains("event:error", "PLANT_KNOWLEDGE_UNAVAILABLE").doesNotContain("event:done");
        assertThat(body(send(path(id), "GET", null, token)).get(1).path("status").asText()).isEqualTo("FAILED");
        assertThat(send(path(id), "POST", question("继续问答"), token).body()).contains("event:done");
        assertThat(lastRequest().path("messages").toString()).doesNotContain("\"content\":\"CARE\"");
    }

    @Test
    void invalidRequestsReturnProblemDetailsWithoutCreatingTurns() throws Exception {
        String token=login("ai_input");String id=create(token,null);
        for(String value:List.of("{}","{","null","{\"requestId\":\"invalid\",\"content\":\"你好\"}",question(" "),question("文".repeat(4001)))) {
            problem(send(path(id),"POST",value,token),400,"INVALID_AI_INPUT");
        }
        problem(send(path(id)+"?limit=100","GET",null,token),400,"INVALID_AI_INPUT");
        problem(send(path(id)+"?before=bad","GET",null,token),400,"INVALID_AI_INPUT");
        assertThat(body(send(path(id),"GET",null,token)).size()).isZero();
    }

    @Test
    void failedFinalSaveNeverSendsDoneOrAddsTheTurnToMemory() throws Exception {
        String token=login("ai_save_failure");String id=create(token,null);
        var failOnce=new java.util.concurrent.atomic.AtomicBoolean(true);
        doAnswer(invocation -> {
            if (invocation.getArgument(4).equals("COMPLETED") && failOnce.getAndSet(false)) {
                throw new DataAccessResourceFailureException("测试最终保存失败");
            }
            return invocation.callRealMethod();
        }).when(conversations).save(anyLong(),any(),anyString(),anyString(),anyString(),nullable(String.class));
        var response=send(path(id),"POST",question("本轮保存失败"),token);
        assertThat(response.body()).contains("DATA_STORE_UNAVAILABLE").doesNotContain("event:done");
        assertThat(body(send(path(id),"GET",null,token)).get(1).path("status").asText()).isEqualTo("FAILED");
        assertThat(send(path(id),"POST",question("继续问答"),token).body()).contains("event:done");
        assertThat(lastRequest().path("messages").toString()).doesNotContain("本轮保存失败");
    }

    @Test
    void disconnectAndDeletionStopActiveGenerationAndToolCallsAreLimited() throws Exception {
        String token=login("ai_disconnect");String id=create(token,null);
        var response=http.send(request(port,path(id),"POST",question("WAIT"),token),HttpResponse.BodyHandlers.ofInputStream());
        assertThat(response.statusCode()).isEqualTo(200);
        response.body().readNBytes(100);
        response.body().close();
        awaitInactive(id);
        assertThat(body(send(path(id),"GET",null,token)).get(1).path("status").asText()).isEqualTo("CANCELLED");
        var deleting=http.sendAsync(request(port,path(id),"POST",question("WAIT"),token),HttpResponse.BodyHandlers.ofString());
        awaitActive(id);
        assertThat(send("/ai/conversations/"+id,"DELETE",null,token).statusCode()).isEqualTo(200);
        deleting.get(5,java.util.concurrent.TimeUnit.SECONDS);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM ai_turns WHERE conversation_id=?",Integer.class,id)).isZero();
        String loop=create(token,null);
        assertThat(send(path(loop),"POST",question("LOOP"),token).body()).contains("AI_OUTPUT_INCOMPLETE");
        long toolCalls=MODEL_REQUESTS.stream().filter(r->r.path("messages").toString().contains("LOOP")).count();
        assertThat(toolCalls).isBetween(1L,6L);
    }

    private void awaitInactive(String id) throws Exception {
        long deadline=System.nanoTime()+Duration.ofSeconds(6).toNanos();
        while(System.nanoTime()<deadline) {
            int count=jdbc.queryForObject("SELECT count(*) FROM ai_turns WHERE conversation_id=? AND status IN ('ACCEPTED','STREAMING')",Integer.class,id);
            if(count==0)return;
            Thread.sleep(20);
        }
        throw new AssertionError("问答未停止");
    }

    private String awaitActive(String id) throws Exception {
        long deadline=System.nanoTime()+Duration.ofSeconds(5).toNanos();
        while(System.nanoTime()<deadline) {
            List<String> ids=jdbc.queryForList("SELECT id FROM ai_turns WHERE conversation_id=? AND status IN ('ACCEPTED','STREAMING')",String.class,id);
            if(!ids.isEmpty()) return ids.getFirst();
            Thread.sleep(20);
        }
        throw new AssertionError("没有正在执行的问答");
    }
    private String login(String name) throws Exception {
        String input=JSON.writeValueAsString(Map.of("username",name,"password","password1"));
        body(send("/users","POST",input,null));
        return body(send("/users/login","POST",input,null)).path("token").asText();
    }
    private String create(String token,Long plantId) throws Exception {
        return body(send("/ai/conversations","POST",plantId==null?"{}":JSON.writeValueAsString(Map.of("plantId",plantId)),token)).path("id").asText();
    }
    private String question(String text) throws Exception {return JSON.writeValueAsString(Map.of("requestId",UUID.randomUUID().toString(),"content",text));}
    private String path(String id) {return "/ai/conversations/"+id+"/messages";}
    private JsonNode body(HttpResponse<String> response) throws Exception {assertThat(response.statusCode()).as(response.body()).isEqualTo(200);return JSON.readTree(response.body());}
    private void problem(HttpResponse<String> response,int status,String code) throws Exception {
        assertThat(response.statusCode()).as(response.body()).isEqualTo(status);
        assertThat(JSON.readTree(response.body()).path("code").asText()).isEqualTo(code);
    }
    private HttpResponse<String> send(String path,String method,String body,String token) throws Exception {return sendTo(port,path,method,body,token);}
    private HttpResponse<String> sendTo(int targetPort,String path,String method,String body,String token) throws Exception {
        return http.send(request(targetPort,path,method,body,token),HttpResponse.BodyHandlers.ofString());
    }
    private HttpRequest request(int targetPort,String path,String method,String body,String token) {
        var request=HttpRequest.newBuilder(URI.create("http://localhost:"+targetPort+path)).timeout(Duration.ofSeconds(12)).header("Content-Type","application/json");
        if(token!=null)request.header("Authorization","Bearer "+token);
        return request.method(method,body==null?HttpRequest.BodyPublishers.noBody():HttpRequest.BodyPublishers.ofString(body)).build();
    }
    private JsonNode lastRequest() {return MODEL_REQUESTS.getLast();}

    private static HttpServer modelServer() {
        try {
            var server=HttpServer.create(new InetSocketAddress("127.0.0.1",0),0);
            server.createContext("/v1/chat/completions",AiConversationTest::model);
            server.setExecutor(Executors.newVirtualThreadPerTaskExecutor());server.start();return server;
        } catch(IOException error) {throw new IllegalStateException(error);}
    }
    private static void model(HttpExchange exchange) throws IOException {
        try(exchange) {
            JsonNode input=JSON.readTree(exchange.getRequestBody());MODEL_REQUESTS.add(input);
            String question="";boolean toolResult=false;
            for(JsonNode message:input.path("messages")) {
                if(message.path("role").asText().equals("user")) question=message.path("content").asText();
                if(message.path("role").asText().equals("tool")) toolResult=true;
            }
            if(question.equals("FAIL")){exchange.sendResponseHeaders(500,-1);return;}
            exchange.getResponseHeaders().set("Content-Type","text/event-stream");exchange.sendResponseHeaders(200,0);
            if(((question.startsWith("TOOL:") || question.equals("CARE") || question.equals("CARE_COMBINED"))&&!toolResult)||question.equals("LOOP")) {
                String arguments=JSON.writeValueAsString(question.equals("CARE") || question.equals("CARE_COMBINED")
                        ? Map.of("plantName", "绿萝", "searchTerms", List.of("golden pothos"), "topics",
                                question.equals("CARE_COMBINED") ? List.of("GENERAL_CARE", "WATERING", "REPOTTING", "WATERING", "HUMIDITY") : List.of("WATERING"))
                        : question.equals("LOOP")?Map.of("offset",0):Map.of("plantId",Long.parseLong(question.substring(5))));
                String name=question.equals("CARE") || question.equals("CARE_COMBINED")?"queryPlantCare":question.equals("LOOP")?"listPlants":"getPlant";
                chunk(exchange,Map.of("role","assistant","tool_calls",List.of(Map.of("index",0,"id","call_"+MODEL_REQUESTS.size(),"type","function","function",Map.of("name",name,"arguments",arguments)))),null);
                chunk(exchange,Map.of(),"tool_calls");
            } else {
                chunk(exchange,Map.of("role","assistant","content","请检查土壤"),null);
                if(question.equals("WAIT")) {
                    try {Thread.sleep(8000);}catch(InterruptedException error){Thread.currentThread().interrupt();return;}
                }
                chunk(exchange,Map.of("content","干湿。"),null);
                chunk(exchange,Map.of(),question.equals("TRUNCATE")?"length":"stop");
                write(exchange,"data: {\"id\":\"test\",\"object\":\"chat.completion.chunk\",\"created\":1,\"model\":\"test-model\",\"choices\":[],\"usage\":{\"prompt_tokens\":10,\"completion_tokens\":5,\"total_tokens\":15}}\n\n");
            }
            write(exchange,"data: [DONE]\n\n");
        } catch(IOException disconnected) { /* 客户端取消时，模拟服务结束当前连接。 */ }
    }
    private static void chunk(HttpExchange exchange,Map<String,Object> delta,String finish) throws IOException {
        var choice=new java.util.HashMap<String,Object>();choice.put("index",0);choice.put("delta",delta);choice.put("finish_reason",finish);
        write(exchange,"data: "+JSON.writeValueAsString(Map.of("id","test","object","chat.completion.chunk","created",1,"model","test-model","choices",List.of(choice)))+"\n\n");
    }
    private static void write(HttpExchange exchange,String text) throws IOException {exchange.getResponseBody().write(text.getBytes(StandardCharsets.UTF_8));exchange.getResponseBody().flush();}
}
