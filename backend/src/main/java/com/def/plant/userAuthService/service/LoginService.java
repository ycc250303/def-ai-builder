package com.def.plant.userAuthService.service;

import com.def.plant.common.exception.BusinessException;
import com.def.plant.userAuthService.dto.CredentialsRequest;
import com.def.plant.userAuthService.dto.LoginResponse;
import com.def.plant.userAuthService.dto.ResetPasswordRequest;
import com.def.plant.userAuthService.dto.UserResponse;

/**
 * 注册、登录、密码重置、退出和当前用户。
 */
public interface LoginService {

	/**
	 * 规范化账号并保存密码哈希。
	 *
	 * @param request 用户名称和密码
	 * @return 新用户
	 * @throws BusinessException 名称、密码不合法或账号已占用
	 */
	UserResponse register(CredentialsRequest request);

	/**
	 * 校验账号密码，覆盖该用户的当前令牌。
	 *
	 * @param request 用户名称和密码
	 * @return 令牌和用户信息
	 * @throws BusinessException 名称不合法、账号不存在或密码错误
	 */
	LoginResponse login(CredentialsRequest request);

	/**
	 * 按账号名称保存新密码哈希，并删除该账号的登录态。允许匿名调用。
	 *
	 * @param request 账号名称和新密码
	 * @throws BusinessException 账号名称或密码不合法，或账号不存在
	 */
	void resetPassword(ResetPasswordRequest request);

	/**
	 * 删除当前用户的登录态。
	 *
	 * @throws BusinessException 未登录
	 */
	void logout();

	/**
	 * @return 当前登录用户
	 * @throws BusinessException 未登录或用户已不存在
	 */
	UserResponse currentUser();

}
