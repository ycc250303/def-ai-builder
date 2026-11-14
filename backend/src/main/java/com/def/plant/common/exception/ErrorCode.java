package com.def.plant.common.exception;

import org.springframework.http.HttpStatus;

/**
 * 可预期的业务失败。每项包含 HTTP 状态、稳定代号和给调用方的说明。
 */
public enum ErrorCode {

	/** 会话标题、提问、UUID 或分页参数不合法。 */
	INVALID_AI_INPUT(HttpStatus.BAD_REQUEST, "INVALID_AI_INPUT", "请检查会话名称、问题内容、编号和分页参数"),
	/** 当前用户没有对应会话。 */
	AI_CONVERSATION_NOT_FOUND(HttpStatus.NOT_FOUND, "AI_CONVERSATION_NOT_FOUND", "会话不存在"),
	/** 会话内没有对应问答。 */
	AI_TURN_NOT_FOUND(HttpStatus.NOT_FOUND, "AI_TURN_NOT_FOUND", "问答不存在"),
	/** 同一会话已有进行中的问答。 */
	AI_CONVERSATION_BUSY(HttpStatus.CONFLICT, "AI_CONVERSATION_BUSY", "当前会话正在生成回复"),
	/** 去重编号被用于不同正文。 */
	AI_REQUEST_CONFLICT(HttpStatus.CONFLICT, "AI_REQUEST_CONFLICT", "该请求编号已用于其他问题"),
	/** 模型地址、名称或密钥缺失。 */
	AI_NOT_CONFIGURED(HttpStatus.SERVICE_UNAVAILABLE, "AI_NOT_CONFIGURED", "模型服务尚未配置"),
	/** 上下文超过配置的输入预算。 */
	AI_CONTEXT_TOO_LONG(HttpStatus.BAD_REQUEST, "AI_CONTEXT_TOO_LONG", "本次会话上下文超过输入预算，请新建会话"),
	/** 生成请求数量超过服务限制。 */
	AI_CAPACITY_EXCEEDED(HttpStatus.TOO_MANY_REQUESTS, "AI_CAPACITY_EXCEEDED", "同时生成的请求已达上限，请稍后再试"),
	/** 模型上游请求失败。 */
	AI_UPSTREAM_FAILED(HttpStatus.BAD_GATEWAY, "AI_UPSTREAM_FAILED", "模型服务请求失败"),
	/** 整轮生成超过允许时间。 */
	AI_TIMEOUT(HttpStatus.GATEWAY_TIMEOUT, "AI_TIMEOUT", "回复生成超时"),
	/** 回复因输出限制或工具调用限制未完成。 */
	AI_OUTPUT_INCOMPLETE(HttpStatus.BAD_GATEWAY, "AI_OUTPUT_INCOMPLETE", "回复未完整生成"),
	/** 用户主动取消或连接断开。 */
	AI_CANCELLED(HttpStatus.CONFLICT, "AI_CANCELLED", "回复已取消"),
	/** 执行租约过期。 */
	AI_INTERRUPTED(HttpStatus.CONFLICT, "AI_INTERRUPTED", "回复生成已中断"),

	/** 账号密码请求正文缺失，或 JSON 字段类型不合法。 */
	INVALID_CREDENTIALS(HttpStatus.BAD_REQUEST, "INVALID_CREDENTIALS", "请填写有效的账号名称和密码"),

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

	/** 植物档案字段不符合必填、长度、日期或选项要求。 */
	INVALID_PLANT_INFO(HttpStatus.BAD_REQUEST, "INVALID_PLANT_INFO",
			"品种必填且最多 100 字，昵称最多 100 字，描述最多 1000 字；日期使用 yyyy-MM-dd，培养地和培养方式请选择有效选项"),

	/** 植物不存在，或不属于当前用户。 */
	PLANT_NOT_FOUND(HttpStatus.NOT_FOUND, "PLANT_NOT_FOUND", "植物不存在"),

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
