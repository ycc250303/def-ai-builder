package com.def.plant.common.exception;

/**
 * 可预期的业务失败。调用方据此返回 Problem Details，不把它当成实现缺陷。
 */
public class BusinessException extends RuntimeException {

	private final ErrorCode errorCode;

	/**
	 * @param errorCode 已确定的业务失败
	 */
	public BusinessException(ErrorCode errorCode) {
		super(errorCode.detail());
		this.errorCode = errorCode;
	}

	/**
	 * @return 业务失败代号与 HTTP 状态
	 */
	public ErrorCode errorCode() {
		return errorCode;
	}

}
