package com.def.plant.plantKnowledgeService.client;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.CompletionStage;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Flow;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import com.def.plant.common.exception.BusinessException;
import com.def.plant.common.exception.ErrorCode;

import jakarta.annotation.PreDestroy;

/** 来源网站只读客户端，固定域名并直连，禁止重定向和重试，限制正文大小及完整请求时间。 */
@Component
public class NcStateClient {
    public static final String ORIGIN = "https://plants.ces.ncsu.edu";
    private static final Logger log = LoggerFactory.getLogger(NcStateClient.class);
    private static final int MAX_PAGE_BYTES = 2_000_000;
    private final URI base;
    private final Duration timeout;
    private final HttpClient http;

    @Autowired
    public NcStateClient() { this(URI.create(ORIGIN), Duration.ofSeconds(10)); }

    /** @param base 服务端配置的来源地址，隔离测试可传本机模拟服务 @param timeout 包含正文读取的超时 */
    public NcStateClient(URI base, Duration timeout) {
        this.base = base;
        this.timeout = timeout;
        this.http = HttpClient.newBuilder().connectTimeout(timeout).followRedirects(HttpClient.Redirect.NEVER)
                .proxy(HttpClient.Builder.NO_PROXY)
                .version(HttpClient.Version.HTTP_1_1).build();
    }

    /**
     * 获取已编码的名称查询地址或规范详情路径，返回 UTF-8 HTML。
     * @param path 仅允许本站名称查询和 /plants/{slug}/
     * @return 完整 HTML，不返回任意上游错误正文
     * @throws BusinessException 来源拒绝、超时、中断、正文超限或响应类型变化
     */
    public String fetch(String path) {
        if (path == null || !(path.matches("/plants/[a-z0-9-]+/")
                || path.matches("/find_a_plant/\\?q=[a-zA-Z0-9%+_.-]+"))) {
            throw new IllegalArgumentException("植物资料请求路径不合法");
        }
        HttpRequest request = HttpRequest.newBuilder(base.resolve(path)).timeout(timeout)
                .header("Accept", "text/html").header("User-Agent", "PlantCareKnowledge/1.0")
                .GET().build();
        var pending = http.sendAsync(request, ignored -> new LimitedBody());
        try {
            HttpResponse<byte[]> response = pending.get(timeout.toMillis(), TimeUnit.MILLISECONDS);
            if (response.statusCode() != 200) {
                log.warn("植物资料来源拒绝请求: path={}, status={}", path, response.statusCode());
                throw new BusinessException(ErrorCode.PLANT_KNOWLEDGE_UNAVAILABLE);
            }
            if (!response.headers().firstValue("Content-Type").orElse("").toLowerCase(java.util.Locale.ROOT).contains("text/html")) {
                throw new BusinessException(ErrorCode.PLANT_KNOWLEDGE_PAGE_CHANGED);
            }
            return new String(response.body(), StandardCharsets.UTF_8);
        } catch (InterruptedException interrupted) {
            pending.cancel(true);
            Thread.currentThread().interrupt();
            throw new BusinessException(ErrorCode.PLANT_KNOWLEDGE_UNAVAILABLE);
        } catch (TimeoutException timedOut) {
            pending.cancel(true);
            log.warn("植物资料请求超时: path={}, timeoutMs={}", path, timeout.toMillis());
            throw new BusinessException(ErrorCode.PLANT_KNOWLEDGE_UNAVAILABLE);
        } catch (ExecutionException failed) {
            Throwable cause = failed.getCause();
            if (cause instanceof BusinessException business) throw business;
            if (cause instanceof IOException) {
                log.warn("植物资料连接失败: path={}, cause={}", path, cause.toString());
                throw new BusinessException(ErrorCode.PLANT_KNOWLEDGE_UNAVAILABLE);
            }
            throw new IllegalStateException("植物资料 HTTP 执行缺陷", cause);
        }
    }

    @PreDestroy
    public void close() { http.close(); }

    /** 转交标准正文订阅器，在分配大块正文之前取消超限响应。 */
    private static final class LimitedBody implements HttpResponse.BodySubscriber<byte[]> {
        private final HttpResponse.BodySubscriber<byte[]> delegate = HttpResponse.BodySubscribers.ofByteArray();
        private Flow.Subscription subscription;
        private long size;
        private boolean failed;
        @Override public CompletionStage<byte[]> getBody() { return delegate.getBody(); }
        @Override public void onSubscribe(Flow.Subscription value) { subscription = value; delegate.onSubscribe(value); }
        @Override public void onNext(List<ByteBuffer> buffers) {
            if (failed) return;
            for (ByteBuffer buffer : buffers) size += buffer.remaining();
            if (size > MAX_PAGE_BYTES) {
                failed = true;
                subscription.cancel();
                delegate.onError(new BusinessException(ErrorCode.PLANT_KNOWLEDGE_TOO_LARGE));
                return;
            }
            delegate.onNext(buffers);
        }
        @Override public void onError(Throwable error) { if (!failed) delegate.onError(error); }
        @Override public void onComplete() { if (!failed) delegate.onComplete(); }
    }
}
