package com.def.plant.userAuthService.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;

/**
 * 用户表。密码字段只保存哈希，字符串输出不包含密码。
 */
@TableName("users")
public class User {

	/** 用户编号，数据库自增。 */
	@TableId(type = IdType.AUTO)
	private Long id;

	/** 规范化后的用户名称，唯一。 */
	private String username;

	/** 密码哈希。 */
	private String password;

	/**
	 * @return 用户编号
	 */
	public Long getId() {
		return id;
	}

	/**
	 * @param id 用户编号
	 */
	public void setId(Long id) {
		this.id = id;
	}

	/**
	 * @return 规范化后的用户名称
	 */
	public String getUsername() {
		return username;
	}

	/**
	 * @param username 规范化后的用户名称
	 */
	public void setUsername(String username) {
		this.username = username;
	}

	/**
	 * @return 密码哈希
	 */
	public String getPassword() {
		return password;
	}

	/**
	 * @param password 密码哈希
	 */
	public void setPassword(String password) {
		this.password = password;
	}

	@Override
	public String toString() {
		return "User[id=" + id + ", username=" + username + "]";
	}

}
