# ESP-Mosaico 四路植物传感器监测

该工程位于 ESP-Mosaico SDK 的 projects/plant_sensor_monitor，使用现有 BSP、
ESP-Iris，并沿用 PlantMate 工程的完整分区表。安装时以设备实际分区表为准。

## 1. 硬件与配置

| 检查项 | 结果 |
| --- | --- |
| 工程目标 | ESP32-S31，ESP-IDF 固定提交 7b9cc1ac79f865983f59bb8ff3ff43eb74ff1dbe |
| 板版本 | 核对 CoreBoard 丝印，启动时 BSP 从 eFuse 读取硬件版本并记录 Hardware version |
| 扩展 I²C | SDA GPIO0、SCL GPIO1，对应 H2/H1 的 16、14 脚，使用 100 kHz |
| V1.0 | 扩展设备和屏幕 CST9220 都在 I²C0，CST9220 占 0x5A |
| V1.2 | 扩展设备在 I²C1，屏幕触控在 I²C0，内侧总线走 GPIO56/GPIO3 |
| GPIO48 | H2 左槽第 4 脚，具备数字输入能力。确认该脚没有被其他扩展板占用 |
| 外设供电 | GPIO60 低有效。BSP 的 bsp_subboard_init 启用槽位电源。H2/H1 的 19、18、20 脚分别是 3.3 V、5V_OUT、GND |

官方指南的 500 mA 是 Type-C 源模式额定值。插槽 5V_OUT 的可用负载
仍需针对供电方式和继电器模块确认。先用独立稳压 5 V 电源给继电器板供电，
保持 COM 接 Mosaico GND、NO 接 GPIO48，只把无源触点接到 GPIO。
确认模块吸合时的电流和插槽电压后，再决定是否改用 5V_OUT。
5 V 电源线及继电器模块逻辑输出都应与 GPIO48 隔离。

V1.0 应先断电，将 MPR121 的 ADDR 改为 0x5B 或 0x5D 并在 menuconfig
选择相同地址。默认 0x5A 会被固件屏蔽。实际 ADDR 仍需与设置一致，
软件屏蔽无法消除两个器件在电气层同时响应。V1.2 可保留默认 0x5A。
本程序将 0x5C 留给 BH1750，扩展总线上的其他模块应避开传感器地址。
检查各 I²C 模块的上拉均接 3.3 V，避免叠加多组过强的上拉。

## 2. 四路驱动

- components/app_sht31 支持 0x44 和 0x45，校验两个测量字的 CRC。
- components/app_bh1750 支持 0x23 和 0x5C，读取单次高分辨率数据并换算 lux。
- components/app_mpr121 读取 ELE0–ELE11，校验复位特征、配置与过流标志。
- components/app_soil_relay 对 GPIO48 上拉输入做稳定性检查。触点闭合读 LOW，断开读 HIGH。

## 3. 串口和屏幕

main/monitor.c 每秒输出 Plant Sensor Data 和 Sensor Connection。I²C 出错时相应值
显示 ERROR，并在下一轮尝试重新连接。components/app_monitor_view
用 BSP 和 LVGL 显示白底卡片。触摸状态按秒采样，测试时请持续按住电极至少两秒。

默认土壤状态显示 Open/HIGH 或 Closed/LOW。在干、湿样本上观察继电器，
调好阈值后记下两个电平。使用 Plant sensor monitor 菜单设置 Soil relay polarity。
单根 NO 输入无法区分合法开路、断线和继电器未上电，Input OK 代表 GPIO 读到了稳定电平。
继电器状态对应干湿阈值，没有连续湿度数值。

## 4. 编译、安装和验证

在已加载固定版本 ESP-IDF 的 PowerShell 中执行。

```powershell
Set-Location 'D:AI BuilderMosaicosdkprojectsplant_sensor_monitor'
idf.py menuconfig
idf.py build
```

回到 SDK 根目录。先查询设备和 Gateway 所有权，确认目标板和当前 Vibe Mode，
按 SDK 的更新流程安装。如果实板完整分区表与本工程一致，且现有资源无需变更，
可以使用 app-update。首次换用工程或布局不一致时按 SDK 指南使用 system-update。
若当前应用正在运行，
先按 SDK 指南进入已有 Vibe Mode。该操作替换板上的应用，请先确认需要保留的应用和数据。

```powershell
Set-Location 'D:AI BuilderMosaicosdk'
python mosaico.py iris status --all --json
python mosaico.py iris system-update --project projects/plant_sensor_monitor
python mosaico.py iris logs --project projects/plant_sensor_monitor --timeout 20
```

可直接使用本次构建的 build-verified/plant_sensor_monitor-system-update.irisfw。
该本地包未签名，适用于允许未签名开发包的 Vibe Mode 0.2.0 或以上版本。
使用已生成的包时，从本工程目录运行 python ../../mosaico.py iris system-update --bundle build-verified/plant_sensor_monitor-system-update.irisfw。CLI 从当前目录选择工程。

也可从 H1 的 TX0 GPIO58 和 GND 以 115200 波特查看 UART0。使用 3.3 V 逻辑的
USB-UART，连接其 RX 和 GND。板上的 USB High-Speed 继续由 ESP-Iris 使用。

1. 核对启动日志中的板版本、I²C 总线和传感器 ACK 地址。
2. 比较 SHT31 与室内参考温湿度计的趋势。遮挡和照亮 BH1750，检查 lux 变化。
3. 按住再放开一个电极，确认相应 ELE 位及 Touched/Idle 更新。
4. 用已知干、湿样本检查触点电平，配置极性后确认 Dry/Wet。
5. 查看屏幕和串口是否每秒更新且状态一致。
6. 断电后取下一路 I²C 传感器并重启，确认该路显示 ERROR，其余路继续刷新。
   若有安全的单路断开测试夹具，可验证运行中失联及重新连接。


官方资料可查阅 [ESP-Mosaico V1.0](https://github.com/espressif/esp-dev-kits/blob/master/docs/en/esp-mosaico/user_guide_v1.0.rst)、
[ESP-Mosaico V1.2](https://docs.espressif.com/projects/esp-dev-kits/en/latest/esp32s31/esp-mosaico/user_guide.html)、
[SHT3x-DIS 数据手册](https://sensirion.com/media/documents/213E6A3B/63A5A569/Datasheet_SHT3x_DIS.pdf)
和 [MPR121 数据手册](https://www.nxp.com/docs/en/data-sheet/MPR121.pdf)。



