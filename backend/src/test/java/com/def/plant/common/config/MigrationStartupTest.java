package com.def.plant.common.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.yaml.snakeyaml.Yaml;

/**
 * 后端启动配置不执行迁移脚本。
 */
class MigrationStartupTest {

	/**
	 * 主配置关闭 Flyway，避免脚本变更阻断进程启动。
	 */
	@Test
	void backendStartupDoesNotRunMigrationScripts() throws Exception {
		String text = Files.readString(Path.of("src/main/resources/application.yaml"));
		Object loaded = new Yaml().load(text);
		assertThat(loaded).isInstanceOf(Map.class);
		Object flyway = map(map(loaded).get("spring")).get("flyway");
		assertThat(map(flyway).get("enabled")).isEqualTo(false);
	}

	@SuppressWarnings("unchecked")
	private static Map<String, Object> map(Object value) {
		return (Map<String, Object>) value;
	}

}
