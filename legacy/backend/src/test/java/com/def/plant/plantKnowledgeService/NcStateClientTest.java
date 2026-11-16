package com.def.plant.plantKnowledgeService;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.ProxySelector;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.Executors;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.def.plant.common.exception.BusinessException;
import com.def.plant.common.exception.ErrorCode;
import com.def.plant.plantKnowledgeService.client.NcStateClient;
import com.sun.net.httpserver.HttpServer;

class NcStateClientTest {
    private HttpServer server;
    private NcStateClient client;
    private final List<String> requests = new CopyOnWriteArrayList<>();

    @BeforeEach void start() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.setExecutor(Executors.newVirtualThreadPerTaskExecutor());
        server.createContext("/", exchange -> {
            requests.add(exchange.getRequestURI().toString());
            try (exchange) {
                String path = exchange.getRequestURI().getPath();
                if (path.equals("/plants/denied/")) { exchange.sendResponseHeaders(403, -1); return; }
                if (path.equals("/plants/redirect/")) {
                    exchange.getResponseHeaders().set("Location", "/plants/one/");
                    exchange.sendResponseHeaders(302, -1); return;
                }
                byte[] body = (path.equals("/plants/huge/") ? "x".repeat(2_000_001) : "<h1>植物资料</h1>").getBytes(StandardCharsets.UTF_8);
                exchange.getResponseHeaders().set("Content-Type", path.equals("/plants/json/") ? "application/json" : "text/html; charset=utf-8");
                exchange.sendResponseHeaders(200, body.length);
                if (path.equals("/plants/slow/")) {
                    try { Thread.sleep(500); } catch (InterruptedException interrupted) { Thread.currentThread().interrupt(); return; }
                }
                exchange.getResponseBody().write(body);
            } catch (IOException disconnected) { /* 验证取消和超限时，模拟服务结束连接。 */ }
        });
        server.start();
        client = new NcStateClient(URI.create("http://127.0.0.1:" + server.getAddress().getPort()), Duration.ofSeconds(2));
    }

    @AfterEach void stop() { client.close(); server.stop(0); }

    @Test
    void utf8AndEncodedQueriesAreReadWithoutFollowingRedirectsOrRetrying() {
        assertThat(client.fetch("/find_a_plant/?q=mother%27s+plant")).contains("植物资料");
        assertThat(requests).containsExactly("/find_a_plant/?q=mother%27s+plant");
        for (String path : List.of("/plants/denied/", "/plants/redirect/")) {
            assertThatThrownBy(() -> client.fetch(path)).isInstanceOfSatisfying(BusinessException.class,
                    error -> assertThat(error.errorCode()).isEqualTo(ErrorCode.PLANT_KNOWLEDGE_UNAVAILABLE));
        }
        assertThat(requests).hasSize(3).doesNotContain("/plants/one/");
        assertThatThrownBy(() -> client.fetch("https://other.example/")).isInstanceOf(IllegalArgumentException.class);
        assertThat(requests).hasSize(3);
    }

    @Test
    void sourceRequestsConnectDirectlyWhenSystemProxyIsUnavailable() {
        ProxySelector original = ProxySelector.getDefault();
        ProxySelector.setDefault(ProxySelector.of(new InetSocketAddress("127.0.0.1", 9)));
        try (var direct = new ClientResource(new NcStateClient(
                URI.create("http://127.0.0.1:" + server.getAddress().getPort()), Duration.ofSeconds(2)))) {
            assertThat(direct.value.fetch("/plants/one/")).contains("植物资料");
            assertThat(requests).containsExactly("/plants/one/");
        } finally {
            ProxySelector.setDefault(original);
        }
    }

    @Test
    void responseTypeAndPageSizeLimitsAreEnforced() {
        assertThatThrownBy(() -> client.fetch("/plants/json/")).isInstanceOfSatisfying(BusinessException.class,
                error -> assertThat(error.errorCode()).isEqualTo(ErrorCode.PLANT_KNOWLEDGE_PAGE_CHANGED));
        assertThatThrownBy(() -> client.fetch("/plants/huge/")).isInstanceOfSatisfying(BusinessException.class,
                error -> assertThat(error.errorCode()).isEqualTo(ErrorCode.PLANT_KNOWLEDGE_TOO_LARGE));
    }

    @Test
    void timeoutCoversSlowResponseBodyAndCancelsRequest() {
        try (var shortClient = new ClientResource(new NcStateClient(URI.create("http://127.0.0.1:" + server.getAddress().getPort()), Duration.ofMillis(100)))) {
            long started = System.nanoTime();
            assertThatThrownBy(() -> shortClient.value.fetch("/plants/slow/")).isInstanceOfSatisfying(BusinessException.class,
                    error -> assertThat(error.errorCode()).isEqualTo(ErrorCode.PLANT_KNOWLEDGE_UNAVAILABLE));
            assertThat(Duration.ofNanos(System.nanoTime() - started)).isLessThan(Duration.ofSeconds(1));
        }
    }

    private record ClientResource(NcStateClient value) implements AutoCloseable {
        @Override public void close() { value.close(); }
    }
}
