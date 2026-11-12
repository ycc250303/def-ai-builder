package com.def.plant.common.exception;

import java.io.IOException;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;

import jakarta.servlet.http.HttpServletResponse;

/**
 * 把业务失败写成 RFC 9457 Problem Details。
 */
public final class ProblemResponses {

	private ProblemResponses() {
	}

	/**
	 * @param errorCode 业务失败
	 * @return 带稳定代号的 Problem Details
	 */
	public static ProblemDetail toProblemDetail(ErrorCode errorCode) {
		ProblemDetail detail = ProblemDetail.forStatusAndDetail(errorCode.status(), errorCode.detail());
		detail.setTitle(errorCode.detail());
		detail.setProperty("code", errorCode.code());
		return detail;
	}

	/**
	 * 在过滤器中直接写回 Problem Details，并停止后续处理。
	 *
	 * @param response 当前响应
	 * @param errorCode 业务失败
	 * @throws IOException 响应无法写入时抛出
	 */
	public static void write(HttpServletResponse response, ErrorCode errorCode) throws IOException {
		HttpStatus status = errorCode.status();
		response.setStatus(status.value());
		response.setCharacterEncoding("UTF-8");
		response.setContentType("application/problem+json");
		response.getWriter().write("{\"type\":\"about:blank\",\"title\":" + json(errorCode.detail())
				+ ",\"status\":" + status.value()
				+ ",\"detail\":" + json(errorCode.detail())
				+ ",\"code\":" + json(errorCode.code()) + "}");
	}

	private static String json(String value) {
		return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
	}

}
