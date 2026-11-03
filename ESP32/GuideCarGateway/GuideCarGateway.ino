#include <Arduino.h>
#if !defined(CONFIG_IDF_TARGET_ESP32S3)
#error Select ESP32S3 Dev Module for this sketch.
#endif
#if !ARDUINO_USB_CDC_ON_BOOT
#error Enable Tools -> USB CDC On Boot for the native USB port.
#endif
#include <WiFi.h>
#include <WebServer.h>
#include "config.h"
#include "protocol.h"
#include "dog_pages.h"

HardwareSerial pynq(1);
WebServer server(80);
TelemetryParser parser;
TelemetryFrame latest{};
uint32_t lastFrame=0,lastByte=0,sequence=0;
bool received=false;
String numberOrNull(bool valid,float value){return valid ? String(value,3) : String("null");}

String telemetryJSON(){
  const uint32_t now=millis();
  const bool fresh=received && uint32_t(now-lastFrame)<=STALE_MS;
  const auto valid=validity(latest,fresh,ALLOW_UNCALIBRATED_SPEED,ENABLE_VISUAL_V1);
  const bool calibrated=valid.calibrated,wheels=valid.wheels,distance=valid.distance;
  // v1 visual layout: fault7,mode6,light5:4,zebra3,frame_valid2,ready1,configured0.
  const bool vision=valid.vision;
  const uint8_t light=(latest.visual>>4)&3;
  const char* color=!vision?"unknown":light==1?"red":light==2?"green":"unknown";
  String s; s.reserve(1100);
  s="{\"schema_version\":1,\"device_id\":\"pynq-esp32-01\",\"seq\":"+String(sequence)+
    ",\"uptime_ms\":"+String(now)+",\"wheels\":{\"left_mps\":"+
    numberOrNull(wheels,latest.leftSpeed/1000.0f)+",\"right_mps\":"+
    numberOrNull(wheels,latest.rightSpeed/1000.0f)+"},\"road\":{\"distance_cm\":"+
    numberOrNull(distance,latest.distance/10.0f)+",\"valid\":"+(distance?"true":"false")+
    ",\"source\":\"ultrasonic\"},\"vision\":{\"ready\":"+(vision?"true":"false")+
    ",\"zebra\":"+(vision?((latest.visual&8)?"true":"false"):"null")+
    ",\"traffic_light\":\""+color+"\"},\"camera\":{\"available\":false},\"gateway\":{\"fresh\":"+
    (fresh?"true":"false")+",\"age_ms\":"+(received?String(uint32_t(now-lastFrame)):"null")+
    ",\"good_frames\":"+String(parser.good)+",\"bad_frames\":"+String(parser.bad)+
    ",\"calibrated\":"+(calibrated?"true":"false")+",\"raw_left_mm_s\":"+
    (fresh?String(latest.leftSpeed):"null")+",\"raw_right_mm_s\":"+
    (fresh?String(latest.rightSpeed):"null")+",\"fpga_seq\":"+String(latest.seq)+
    ",\"state\":"+(fresh?String(latest.state):"null")+",\"flags\":"+String(latest.flags)+
    ",\"blocked_reason\":"+String(latest.blocked)+",\"visual_status\":"+String(latest.visual)+",\"left_duty\":"+String(latest.leftDuty)+",\"right_duty\":"+String(latest.rightDuty)+"}}";
  return s;
}
void headers(){server.sendHeader("Cache-Control","no-store");}
void setup(){
  Serial.begin(115200);
  uint32_t usbStart=millis();
  while(!Serial && uint32_t(millis()-usbStart)<1500) delay(10);
  Serial.println("\nPYNQ gateway: ESP32-S3 N16R8 / native USB CDC");
  Serial.println("PYNQ RX=GPIO16, UART1, 115200 8N1; TX17 unused");
  Serial.printf("Connecting to hotspot SSID: %s\n",STA_SSID);
  Serial.println("Use a 2.4 GHz hotspot. The password is never printed.");
  WiFi.onEvent([](WiFiEvent_t event, WiFiEventInfo_t info){
    if(event==ARDUINO_EVENT_WIFI_STA_DISCONNECTED)
      Serial.printf("WiFi disconnected, reason=%u (check SSID/password/2.4GHz/signal)\n",info.wifi_sta_disconnected.reason);
  });
  pynq.setRxBufferSize(2048);
  // UART1 is separate from native USB CDC. No motion commands are sent.
  pynq.begin(UART_BAUD,SERIAL_8N1,PYNQ_RX_PIN,PYNQ_TX_PIN);
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.setSleep(false);
  WiFi.setHostname("pynq-car");
  WiFi.begin(STA_SSID,STA_PASSWORD);
  registerDogPages(server);
  server.on("/api/telemetry",HTTP_GET,[]{headers();server.send(200,"application/json",telemetryJSON());});
  server.on("/api/health",HTTP_GET,[]{headers();server.send(200,"application/json",
    String("{\"connected\":")+(WiFi.status()==WL_CONNECTED?"true":"false")+",\"sta_ip\":\""+WiFi.localIP().toString()+"\"}");});
  server.onNotFound([]{server.send(404,"text/plain","Not found. Open / or /api/telemetry");});
  server.begin();
}
void loop(){
  unsigned budget=512;
  while(budget-- && pynq.available()){
    uint32_t now=millis();if(uint32_t(now-lastByte)>FRAME_GAP_MS)parser.reset();lastByte=now;
    if(parser.push(uint8_t(pynq.read()),latest)){received=true;lastFrame=now;++sequence;}
  }
  server.handleClient();
  static uint32_t lastLog=0;
  static int previousStatus=-100;
  int currentStatus=WiFi.status();
  if(currentStatus!=previousStatus || uint32_t(millis()-lastLog)>=5000){
    previousStatus=currentStatus;lastLog=millis();
    if(currentStatus==WL_CONNECTED){
      Serial.print("WiFi CONNECTED. Open http://");Serial.print(WiFi.localIP());Serial.println("/");
      Serial.printf("RSSI=%d dBm, UART good=%lu bad=%lu, fresh=%s\n",WiFi.RSSI(),
        (unsigned long)parser.good,(unsigned long)parser.bad,
        received && uint32_t(millis()-lastFrame)<=STALE_MS ? "yes":"no");
    }else{
      const char* label=currentStatus==WL_NO_SSID_AVAIL ? "SSID not found" :
        currentStatus==WL_CONNECT_FAILED ? "connection failed" :
        currentStatus==WL_DISCONNECTED ? "disconnected / connecting" : "waiting";
      Serial.printf("WiFi status=%d (%s). Check 2.4GHz and exact credentials.\n",currentStatus,label);
    }
  }
  static uint32_t lastRetry=0;
  if(WiFi.status()!=WL_CONNECTED && uint32_t(millis()-lastRetry)>15000){lastRetry=millis();WiFi.reconnect();}
  delay(1);
}
