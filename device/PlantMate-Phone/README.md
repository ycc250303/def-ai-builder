# PlantMate 手机监测

这个目录包含同一套手机网页、电脑模拟服务和 ESP-Mosaico（ESP32-S31）应用源码。网页约每秒读取一次 `/api/state`，显示温度、空气湿度、光照、土壤触点、触摸电极及最近一条设备指令。

## 电脑模拟

在 PowerShell 中运行：

```powershell
Set-Location 'D:/AI Builder/PlantMate-Phone'
node preview.mjs
```

打开 [电脑模拟页](http://127.0.0.1:8790/)。要从手机测试，电脑和手机加入同一 Wi-Fi，改用 `node preview.mjs --lan`，在手机浏览器访问电脑该 Wi-Fi 网卡的 IPv4 地址及端口 8790。使用 `ipconfig` 获取网卡地址。只有模拟数据会由此服务发送。

## 板端应用

`device` 是独立 ESP-IDF 项目，复用相邻 `Mosaico/sdk` 中现有的传感器驱动、屏幕组件和分区配置。使用该 SDK 配套的 ESP-IDF 6.2 环境打开项目，在 `idf.py menuconfig` 的 **PlantMate phone dashboard** 下设置热点名称和密码，然后执行 `idf.py build`。源码检查已通过，当前 Windows 环境的完整构建卡在 ESP32-S31 工具链启动，尚无可烧录产物。

板端应用运行后，手机连接该应用创建的 Wi-Fi 热点（默认 `PlantMate`，开发密码 `plantmate-local`），然后在浏览器地址栏打开 `http://192.168.4.1/`。若手机提示热点没有互联网，选择保持连接。网页和 API 均由板子向手机提供，无需路由器或云端。

## 数据接口

- `GET /` 提供单页网页。
- `GET /api/state` 返回 `source`、采样序号 `sequence`、`sensors` 和最近一条 `command`。读取失败的传感器字段为 `null`。土壤字段为 `high`（开路）或 `low`（闭合），湿度百分比为 SHT31 测得的空气湿度。
- `plant_phone_publish_command("COMMAND_CODE")` 可从板端业务逻辑发布一条指令。当前板端示例在服务启动和检测到新触摸时发布 `MONITORING` 和 `TOUCH_DETECTED`。指令带递增 ID。页面展示最近一条指令，适合状态显示，连续指令的逐条送达需要队列和确认协议。
- `plant_phone_publish_sample()` 从采样任务更新快照。网页失联时保留上次读数，并标注连接中断。

本次开发和预览没有连接、访问串口或烧录设备。
