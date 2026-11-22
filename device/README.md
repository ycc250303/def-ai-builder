# ESP-Mosaico 传感器采集与手机接口

## 从这里读代码

- 原工程 `Mosaico/sdk/projects/plant_sensor_monitor/main/main.c` 初始化 NVS、屏幕并启动采样。
- 同级 `monitor.c` 取得 BSP 提供的扩展 I²C 总线，对传感器候选地址进行探测，读取采样值，并将结果输出到串口和屏幕。失败的 I²C 句柄会释放，后续采样会重新探测。
- `components/app_sht31` 负责温湿度采样、CRC 校验和单位换算。
- `components/app_bh1750` 负责光照测量与 lux 换算。
- `components/app_mpr121` 负责触摸芯片初始化和 ELE0 至 ELE11 的位掩码读取。
- `components/app_soil_relay` 负责 GPIO48 触点采样和稳定性检查。
- `components/app_monitor_view` 负责设备屏幕上的监测界面。
- 原工程的 `README.md` 记录接线、硬件版本差异、I²C 地址、土壤阈值标定和原项目的验证流程。包内同时保留 Kconfig、CMake、依赖锁和分区配置。

## 手机 App 对接

`PlantMate-Phone/device/main/monitor.c` 是采样工程接入手机后的版本。在采样点调用 `plant_phone_publish_sample()`；触摸由无变为有时发布 `TOUCH_DETECTED`。HTTP 服务代码在 `PlantMate-Phone/firmware/plant_phone.c`。应用启动后创建 Wi-Fi 热点，手机 App 连接后读取：

```text
GET http://192.168.4.1/api/state
```

请求返回一个当前快照，例如：

```json
{
  "source": "device",
  "sequence": 42,
  "sensors": {
    "temperature_c": 24.6,
    "humidity_rh": 61.0,
    "light_lux": 480.0,
    "soil_level": "high",
    "touch_mask": 5
  },
  "command": {"id": 2, "code": "TOUCH_DETECTED"}
}
```

`humidity_rh` 是空气相对湿度。土壤输入是阈值触点，`high` 表示开路，`low` 表示闭合，干湿映射须按实际接线和阈值校准。触摸掩码的位 0 至 11 对应 ELE0 至 ELE11，示例中的 5 表示 ELE0 和 ELE2。读数失败使用 `null`，尚无指令时 `command` 为 `null`。接口只保留最近一条指令。

## 构建与测试范围

本包保留两个应用的项目目录结构。构建需要工作区已有的 ESP-Mosaico SDK 子模块、匹配的 ESP-IDF 6.2 和 ESP32-S31 工具链。归档附的是应用自有源码、配置和接口演示。解压到新位置时，应让相对目录下能找到匹配的 SDK 子模块。手机 App 自己的代码和分析 API 不在此包中。

可在 `PlantMate-Phone` 内执行 `node preview.mjs`，通过 `http://127.0.0.1:8790/api/state` 查看模拟 JSON。手机联调见该目录 README。上一轮已验证电脑模拟接口与网页，板端 HTTP 版本的完整构建仍受 Windows 工具链路径访问错误阻塞。本次整理没有连接或烧录设备。
