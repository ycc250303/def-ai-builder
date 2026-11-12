package com.def.plant.userAuthService.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.def.plant.userAuthService.dto.CredentialsRequest;
import com.def.plant.userAuthService.dto.LoginResponse;
import com.def.plant.userAuthService.dto.UserResponse;
import com.def.plant.userAuthService.service.LoginService;

/**
 * 注册、登录、退出和当前用户。
 */
@RestController
@RequestMapping("/users")
public class UserController {

	private static final Logger log = LoggerFactory.getLogger(UserController.class);

	private final LoginService loginService;

	/**
	 * @param loginService 登录业务
	 */
	public UserController(LoginService loginService) {
		this.loginService = loginService;
	}

	/**
	 * @param request 用户名称和密码
	 * @return 新用户编号和名称
	 */
	@PostMapping
	public UserResponse register(@RequestBody CredentialsRequest request) {
		UserResponse user = loginService.register(request);
		log.info("用户注册: username={}", user.username());
		return user;
	}

	/**
	 * @param request 用户名称和密码
	 * @return 令牌和用户信息
	 */
	@PostMapping("/login")
	public LoginResponse login(@RequestBody CredentialsRequest request) {
		LoginResponse response = loginService.login(request);
		log.info("用户登录: username={}", response.user().username());
		return response;
	}

	/**
	 * 删除当前登录态。
	 */
	@PostMapping("/logout")
	public void logout() {
		loginService.logout();
		log.info("用户退出");
	}

	/**
	 * @return 当前登录用户
	 */
	@GetMapping("/me")
	public UserResponse me() {
		return loginService.currentUser();
	}

}
