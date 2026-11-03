#pragma once
// ESP32-S3 N16R8; PYNQ JA10 -> GPIO16 (UART1 RX), common GND.
// GPIO17 is reserved for UART1 TX; leave it disconnected.
constexpr int PYNQ_RX_PIN=16, PYNQ_TX_PIN=17;
constexpr unsigned UART_BAUD=115200, STALE_MS=1500, FRAME_GAP_MS=100;
constexpr char STA_SSID[]="YOUR_WIFI_SSID";
constexpr char STA_PASSWORD[]="YOUR_WIFI_PASSWORD";
constexpr bool ALLOW_UNCALIBRATED_SPEED=false;
constexpr bool ENABLE_VISUAL_V1=true;
