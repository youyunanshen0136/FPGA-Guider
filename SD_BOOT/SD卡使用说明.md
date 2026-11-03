# 最新整车SD自动启动

已部署到E: PYNQ启动分区：boot.py和car_zebra_final目录。原BOOT.BIN、boot.scr、image.ub、旧line_demo保留；完整原文件备份见sd_boot/backups/before_zebra_final_20261031_233852。

Windows安全弹出读卡器。PYNQ完全断电后，将卡插回，启动跳线改为SD，再上电。等待原Linux系统启动和boot.py自动运行，摄像头HDMI与ESP32遥测应随后出现。无需运行Windows program.ps1，无需再次初始化PS。首次启动先关闭电机动力，架空车轮，确认数据和图像后再试BTN1。BTN0程序复位，BTN2急停。

此版保留摄像头颜色修正、巡线、超声、ESP32和六路语音，斑马线先停并触发语音，约1.5秒后按当前灯色播报，绿灯触发同时授权行走。

boot.py先校验BIT的SHA256，再通过PYNQ Clocks设置FCLK0为125MHz并下载。脚本不会运行XSDB系统复位，不会自动启动电机。Linux和PS继续正常运行，区别于JTAG调试时停止两核的流程。

写入、读回校验、缓存刷新已完成；本次SD冷启动尚未实板验证。启动状态写入car_zebra_final/boot_status.json；如果loaded=false，查看error字段或板上串口的CAR_ZEBRA_FINAL_FAILED。不要在Windows格式化Linux分区。

恢复旧版：将备份中的boot.py复制回SD根目录即可恢复原line_demo入口，旧数据仍在。
