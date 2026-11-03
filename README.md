# 多模态感知智能导盲小车

基于 PYNQ-Z2 / Zynq-7020 的受控赛道演示项目。通过五路巡线、OV5640 全帧颜色统计、超声波测距和编码器观测，实现巡线纠偏、障碍停车、斑马线等待与绿灯通行，并提供 HDMI 图像预览、ASRPRO 语音触发和 ESP32-S3 网页遥测。

## 归档版本

经项目成员确认，本仓库采用 `car_zebra_sequence_20261031`（2026年10月31日晚最终整合版）。不包含10月30日旧版及后续独立网页试验版。RTL、约束、原有脚本和烧录文件保留归档内容，新增了便于重建的 `FPGA/scripts/build.ps1`。ESP32 配置中的原 Wi-Fi 名称和密码已替换为占位符，使用前填写本地网络信息。

## 目录

|目录|内容|
|---|---|
|FPGA/src|Verilog RTL，包括摄像头、HDMI、控制与语音事件模块|
|FPGA/constraints|引脚及时钟约束|
|FPGA/board_files|PYNQ-Z2 板卡定义|
|FPGA/scripts|重建、仿真、PS时钟初始化及JTAG下载脚本|
|FPGA/sim|仿真测试及参考模块|
|FPGA/output|最终BIT、LTX与PS初始化脚本|
|FPGA/reports|归档时序、DRC、CDC、资源报告及13项回归日志|
|ESP32/GuideCarGateway|Arduino程序、协议、配置和内嵌网页dog_pages.h|
|SD_BOOT|PYNQ系统内运行的加载脚本、清单及同版本烧录文件|
|docs|技术文档PDF和Word原稿|

## 系统连接

OV5640、五路巡线、超声波和四轮AB编码器连接PYNQ-Z2。FPGA汇总输入并执行路口状态机与安全仲裁，通过PWM、方向、使能信号驱动四轮底盘。摄像头图像同时送往HDMI预览，事件通过GPIO触发ASRPRO。PYNQ JA10/W19输出UART遥测至ESP32-S3 GPIO16，波特率115200、8N1，所有模块共地。超声波ECHO进入FPGA前需完成电平适配。详细接线以XDC与技术文档为准。

## FPGA重建与仿真

归档构建报告使用Vivado 2024.1，目标器件`xc7z020clg400-1`，顶层由脚本生成为`clock_system_wrapper`，PS FCLK0为125 MHz。

在FPGA目录中打开PowerShell，替换工具安装位置后执行：

```powershell
./scripts/build.ps1 -VivadoBin 'D:/vivado/Vivado/2024.1/bin'
./scripts/test.ps1 -VivadoBin 'D:/vivado/Vivado/2024.1/bin'
```

重建脚本从源码和板卡定义生成Block Design及工程，不需要历史`.xpr`、DCP或编译缓存。构建成功后可打开`build/project/car_psclock.xpr`。先安装Vivado所需的Zynq-7000器件支持。

JTAG路径使用`./scripts/program.ps1 -VivadoBin 'D:/vivado/Vivado/2024.1/bin'`，会初始化PS时钟并下载BIT/LTX。该操作涉及连接的硬件，先架空车轮并确认急停有效。PYNQ Linux中的加载方式另见`SD_BOOT/SD卡使用说明.md`，两种启动方式按各自说明使用。

## ESP32与网页

Arduino IDE打开`ESP32/GuideCarGateway/GuideCarGateway.ino`，安装相应ESP32开发板支持，按实际ESP32-S3硬件配置编译。填写`config.h`内的Wi-Fi名称与密码后烧录。网页由同目录`dog_pages.h`内嵌提供，具体数据字段见`protocol.h`。网页仅用于状态查看，不控制车辆。

## 操作及验证边界

BTN0复位、BTN1启停、BTN2急停。五路巡线全黑触发斑马线阶段，立即停车并发出提示，等待约1.5秒。只有有效绿灯、安全条件满足且绿灯语音GPIO触发后才允许直行。有效通行累计3秒后停车，复位后重新开始。原20秒巡线试跑限制保留。

40cm距离报警，30cm内连续确认后停车，恢复至40cm并确认后满足恢复条件。摄像头采用320×240 RGB565全帧颜色统计，不做灯形识别。编码器默认未标定，速度及里程不作为精度指标，也未实现编码器速度闭环。归档日志记录13项仿真通过，但不代表全部实物场景均已验证。ASRPRO没有BUSY反馈，保证的是语音GPIO触发与运动许可的逻辑关系。

技术文档为提供的原文件，部分章节含历史版本描述。当前归档行为请结合RTL、`FPGA/使用说明.md`及`FPGA/验证结果.md`核对。

## 完整性

`FILE_SHA256.json`记录本仓库交付文件的SHA-256摘要。`ARCHIVE_SOURCES.json`记录复制来源与原始摘要，配置文件脱敏后的摘要以FILE_SHA256为准。未附加开源许可证，公开展示不代表授予任意使用许可。
