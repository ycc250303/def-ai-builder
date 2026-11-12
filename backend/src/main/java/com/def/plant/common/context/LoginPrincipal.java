package com.def.plant.common.context;

/**
 * 已通过令牌校验的当前用户。
 *
 * @param userId 用户编号
 * @param username 规范化账号
 */
public record LoginPrincipal(long userId, String username) {
}
