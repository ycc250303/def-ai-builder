package com.def.plant.common.exception;

import org.springframework.http.HttpStatus;

/**
 * 可预期的业务失败。每项包含 HTTP 状态、稳定代号和给调用方的说明。
 */
public enum ErrorCode {

	/** 用户名称不符合长度或字符规则。 */
	INVALID_ACCOUNT(HttpStatus.BAD_REQUEST, "INVALID_ACCOUNT", "用户名称需要为 3 到 32 位字母、数字或下划线"),

	/** 密码长度不符合规则。 */
	INVALID_PASSWORD(HttpStatus.BAD_REQUEST, "INVALID_PASSWORD", "密码长度需要为 8 到 64 位"),

	/** 规范化后的账号已被占用。 */
	ACCOUNT_TAKEN(HttpStatus.CONFLICT, "ACCOUNT_TAKEN", "账号已占用"),

	/** 登录时找不到对应账号。 */
	ACCOUNT_NOT_FOUND(HttpStatus.UNAUTHORIZED, "ACCOUNT_NOT_FOUND", "账号不存在"),

	/** 密码与已保存的哈希不一致。 */
	BAD_CREDENTIALS(HttpStatus.UNAUTHORIZED, "BAD_CREDENTIALS", "密码错误"),

	/** 请求没有可用的登录态。 */
	NOT_AUTHENTICATED(HttpStatus.UNAUTHORIZED, "NOT_AUTHENTICATED", "未登录"),

	/** 数据库暂时无法完成读写。 */
	DATA_STORE_UNAVAILABLE(HttpStatus.SERVICE_UNAVAILABLE, "DATA_STORE_UNAVAILABLE", "数据存储暂时不可用");

	private final HttpStatus status;

	private final String code;

	private final String detail;

	ErrorCode(HttpStatus status, String code, String detail) {
		this.status = status;
		this.code = code;
		this.detail = detail;
	}

	/**
	 * @return 对应的 HTTP 状态
	 */
	public HttpStatus status() {
		return status;
	}

	/**
	 * @return 稳定错误代号
	 */
	public String code() {
		return code;
	}

	/**
	 * @return 可直接展示的失败说明
	 */
	public String detail() {
		return detail;
	}

}
