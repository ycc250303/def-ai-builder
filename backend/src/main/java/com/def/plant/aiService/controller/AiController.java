package com.def.plant.aiService.controller;

import java.util.List;

import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import com.def.plant.aiService.dto.ConversationRequest;
import com.def.plant.aiService.dto.ConversationResponse;
import com.def.plant.aiService.dto.MessageResponse;
import com.def.plant.aiService.dto.QuestionRequest;
import com.def.plant.aiService.entity.AiTurn;
import com.def.plant.aiService.service.AiConversationService;
import com.def.plant.aiService.service.AiReplyService;
import com.def.plant.common.context.LoginPrincipal;
import com.def.plant.common.exception.BusinessException;
import com.def.plant.common.exception.ErrorCode;
import com.def.plant.common.exception.ProblemResponses;

/** 当前登录账号的持久化会话和流式问答接口。 */
@RestController
@RequestMapping("/ai/conversations")
public class AiController {
    private final AiConversationService conversations;
    private final AiReplyService replies;
    public AiController(AiConversationService conversations, AiReplyService replies) {
        this.conversations = conversations; this.replies = replies;
    }

    @PostMapping
    public ConversationResponse create(@RequestBody ConversationRequest request) {
        return conversations.create(owner(), request);
    }

    @GetMapping
    public List<ConversationResponse> list(@RequestParam(defaultValue = "0") int offset,
            @RequestParam(defaultValue = "20") int limit) {
        return conversations.list(owner(), offset, limit);
    }

    @GetMapping("/{id}/messages")
    public List<MessageResponse> messages(@PathVariable String id,
            @RequestParam(defaultValue = "9223372036854775807") long before,
            @RequestParam(defaultValue = "20") int limit) {
        return conversations.messages(owner(), id, before, limit);
    }

    /**
     * 请求线程内验证身份，后续异步执行显式传递用户编号。
     * @param id 会话 UUID
     * @param request 问题和客户端去重 UUID
     * @return SSE 文本片段及持久化状态事件
     */
    @PostMapping(value = "/{id}/messages", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter send(@PathVariable String id, @RequestBody QuestionRequest request) {
        return replies.reply(owner(), id, request);
    }

    @GetMapping("/{id}/turns/{turnId}")
    public AiTurn turn(@PathVariable String id, @PathVariable String turnId) {
        return conversations.turn(owner(), id, turnId);
    }

    @PostMapping("/{id}/turns/{turnId}/cancel")
    public AiTurn cancel(@PathVariable String id, @PathVariable String turnId) {
        return replies.cancel(owner(), id, turnId);
    }

    @DeleteMapping("/{id}")
    public void delete(@PathVariable String id) { replies.delete(owner(), id); }

    /** 保证 SSE 响应建立前的业务失败仍使用 HTTP Problem Details。 */
    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ProblemDetail> business(BusinessException exception) {
        var code = exception.errorCode();
        return ResponseEntity.status(code.status()).contentType(MediaType.APPLICATION_PROBLEM_JSON)
                .body(ProblemResponses.toProblemDetail(code));
    }

    @ExceptionHandler({HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class})
    public ResponseEntity<ProblemDetail> invalid(Exception exception) {
        return ResponseEntity.badRequest().contentType(MediaType.APPLICATION_PROBLEM_JSON)
                .body(ProblemResponses.toProblemDetail(ErrorCode.INVALID_AI_INPUT));
    }

    private long owner() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof LoginPrincipal principal)) {
            throw new BusinessException(ErrorCode.NOT_AUTHENTICATED);
        }
        return principal.userId();
    }
}
