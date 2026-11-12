package com.def.plant.common.exception;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * 把可预期失败转换成 Problem Details。未捕获的实现缺陷继续由框架暴露。
 */
@RestControllerAdvice
public class ApiExceptionHandler {

	private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

	/**
	 * @param exception 业务失败
	 * @return 对应的 Problem Details
	 */
	@ExceptionHandler(BusinessException.class)
	public ProblemDetail handleBusiness(BusinessException exception) {
		return ProblemResponses.toProblemDetail(exception.errorCode());
	}

	/**
	 * 数据库故障单独返回，保留原始异常到日志。
	 *
	 * @param exception 数据库访问失败
	 * @return 存储不可用
	 */
	@ExceptionHandler(DataAccessException.class)
	public ProblemDetail handleDataAccess(DataAccessException exception) {
		log.error("数据库访问失败", exception);
		return ProblemResponses.toProblemDetail(ErrorCode.DATA_STORE_UNAVAILABLE);
	}

}
