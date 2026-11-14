package com.def.plant.userAuthService.service.impl;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.def.plant.common.context.LoginPrincipal;
import com.def.plant.common.exception.BusinessException;
import com.def.plant.common.exception.ErrorCode;
import com.def.plant.common.security.IssuedToken;
import com.def.plant.common.security.JwtSessionStore;
import com.def.plant.common.security.JwtTokenService;
import com.def.plant.userAuthService.dto.CredentialsRequest;
import com.def.plant.userAuthService.dto.LoginResponse;
import com.def.plant.userAuthService.dto.ResetPasswordRequest;
import com.def.plant.userAuthService.dto.UserResponse;
import com.def.plant.userAuthService.entity.User;
import com.def.plant.userAuthService.mapper.UserMapper;
import com.def.plant.userAuthService.service.LoginService;
import com.def.plant.userAuthService.utils.AccountName;
import com.def.plant.userAuthService.utils.PasswordRule;

/**
 * 注册、登录、密码重置、退出和当前用户。
 */
@Service
public class LoginServiceImpl implements LoginService {

	private final UserMapper userMapper;

	private final JwtSessionStore jwtSessionStore;

	private final PasswordEncoder passwordEncoder;

	private final JwtTokenService jwtTokenService;

	/**
	 * @param userMapper 用户表
	 * @param jwtSessionStore 当前登录态
	 * @param passwordEncoder 密码哈希
	 * @param jwtTokenService 令牌签发
	 */
	public LoginServiceImpl(UserMapper userMapper, JwtSessionStore jwtSessionStore,
			PasswordEncoder passwordEncoder, JwtTokenService jwtTokenService) {
		this.userMapper = userMapper;
		this.jwtSessionStore = jwtSessionStore;
		this.passwordEncoder = passwordEncoder;
		this.jwtTokenService = jwtTokenService;
	}

	/**
	 * 规范化账号并保存密码哈希。
	 *
	 * @param request 用户名称和密码
	 * @return 新用户
	 * @throws BusinessException 名称、密码不合法或账号已占用
	 */
	@Override
	public UserResponse register(CredentialsRequest request) {
		if (request == null) {
			throw new BusinessException(ErrorCode.INVALID_ACCOUNT);
		}
		String username = AccountName.normalize(request.username());
		PasswordRule.check(request.password());
		User user = new User();
		user.setUsername(username);
		user.setPassword(passwordEncoder.encode(request.password()));
		try {
			userMapper.insert(user);
		}
		catch (DuplicateKeyException exception) {
			throw new BusinessException(ErrorCode.ACCOUNT_TAKEN);
		}
		if (user.getId() == null) {
			throw new IllegalStateException("注册后没有返回用户编号");
		}
		return new UserResponse(user.getId(), user.getUsername());
	}

	/**
	 * 在事务中锁定用户记录，校验账号密码并覆盖当前令牌，与密码重置按顺序执行。
	 *
	 * @param request 用户名称和密码
	 * @return 令牌和用户信息
	 * @throws BusinessException 名称不合法、账号不存在或密码错误
	 */
	@Override
	@Transactional
	public LoginResponse login(CredentialsRequest request) {
		if (request == null) {
			throw new BusinessException(ErrorCode.INVALID_ACCOUNT);
		}
		String username = AccountName.normalize(request.username());
		PasswordRule.check(request.password());
		User account = userMapper.selectOne(new LambdaQueryWrapper<User>()
				.eq(User::getUsername, username).last("FOR UPDATE"));
		if (account == null) {
			throw new BusinessException(ErrorCode.ACCOUNT_NOT_FOUND);
		}
		if (!passwordEncoder.matches(request.password(), account.getPassword())) {
			throw new BusinessException(ErrorCode.BAD_CREDENTIALS);
		}
		IssuedToken issuedToken = jwtTokenService.generateToken(account.getId(), account.getUsername());
		jwtSessionStore.replace(account.getId(), issuedToken.value());
		return new LoginResponse(issuedToken.value(), new UserResponse(account.getId(), account.getUsername()));
	}

	/**
	 * 校验输入并在事务中锁定用户记录，保存新密码哈希，再删除登录态。
	 * Redis 操作失败时异常向上传递，数据库密码更新随事务回滚。
	 *
	 * @param request 账号名称和新密码，允许匿名提交
	 * @throws BusinessException 账号名称或密码不合法，或账号不存在
	 */
	@Override
	@Transactional
	public void resetPassword(ResetPasswordRequest request) {
		if (request == null) {
			throw new BusinessException(ErrorCode.INVALID_ACCOUNT);
		}
		String username = AccountName.normalize(request.username());
		PasswordRule.check(request.newPassword());
		User account = userMapper.selectOne(new LambdaQueryWrapper<User>()
				.eq(User::getUsername, username).last("FOR UPDATE"));
		if (account == null) {
			throw new BusinessException(ErrorCode.ACCOUNT_NOT_FOUND);
		}
		int updated = userMapper.update(new LambdaUpdateWrapper<User>()
				.eq(User::getId, account.getId())
				.set(User::getPassword, passwordEncoder.encode(request.newPassword())));
		if (updated != 1) {
			throw new IllegalStateException("重置密码时未更新唯一的用户记录");
		}
		jwtSessionStore.revoke(account.getId());
	}

	/**
	 * 删除当前用户的登录态。
	 *
	 * @throws BusinessException 未登录
	 */
	@Override
	public void logout() {
		jwtSessionStore.revoke(currentPrincipal().userId());
	}

	/**
	 * @return 当前登录用户
	 * @throws BusinessException 未登录或用户已不存在
	 */
	@Override
	public UserResponse currentUser() {
		User user = userMapper.selectById(currentPrincipal().userId());
		if (user == null) {
			throw new BusinessException(ErrorCode.ACCOUNT_NOT_FOUND);
		}
		return new UserResponse(user.getId(), user.getUsername());
	}

	private static LoginPrincipal currentPrincipal() {
		Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
		if (authentication == null || !(authentication.getPrincipal() instanceof LoginPrincipal principal)) {
			throw new BusinessException(ErrorCode.NOT_AUTHENTICATED);
		}
		return principal;
	}

}
