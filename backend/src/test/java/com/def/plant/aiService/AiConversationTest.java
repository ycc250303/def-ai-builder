package com.def.plant.aiService;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.doAnswer;
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
import java.util.UUID;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.Executors;

import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.boot.web.server.context.WebServerApplicationContext;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import com.def.plant.PlantApplication;
import com.def.plant.aiService.service.impl.AiConversationServiceImpl;
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
    @MockitoSpyBean AiConversationServiceImpl conversations;

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
        int calls = MODEL_REQUESTS.size();
        assertThat(send(path(id), "POST", request, token).body()).contains("event:done");
        assertThat(MODEL_REQUESTS).hasSize(calls);
        String sameId = JSON.readTree(request).path("requestId").asText();
        problem(send(path(id), "POST", JSON.writeValueAsString(Map.of("requestId",sameId,"content","其他问题")),token),409,"AI_REQUEST_CONFLICT");
        assertThat(send(path(id),"POST",question("那今天呢？"),token).body()).contains("event:done");
        JsonNode modelRequest = lastRequest();
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
    void ownerChecksCoverEveryEndpointAndPlantAssociation() throws Exception {
        String owner = login("ai_owner"); String other=login("ai_other");
        long plant = body(send("/plants","POST","{\"species\":\"绿萝\",\"cultivationMethod\":\"WATER\"}",owner)).path("id").asLong();
        String id=create(owner,plant);
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
        assertThat(send(path(id),"POST",question("FAIL"),token).body()).contains("event:error");
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
        String other=login("ai_tool_other");
        long otherPlant=body(send("/plants","POST","{\"species\":\"龟背竹\"}",other)).path("id").asLong();
        assertThat(send(path(id),"POST",question("TOOL:"+otherPlant),token).body()).contains("PLANT_NOT_FOUND");
        assertThat(lastRequest().toString()).doesNotContain("龟背竹");
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
            if((question.startsWith("TOOL:")&&!toolResult)||question.equals("LOOP")) {
                String arguments=JSON.writeValueAsString(question.equals("LOOP")?Map.of("offset",0):Map.of("plantId",Long.parseLong(question.substring(5))));
                String name=question.equals("LOOP")?"listPlants":"getPlant";
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
