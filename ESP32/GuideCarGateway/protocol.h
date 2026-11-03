#pragma once
#include <stdint.h>
#include <stddef.h>
#include <string.h>

struct TelemetryFrame {
  uint8_t seq, flags, state, gray, risk, blocked, leftDuty, rightDuty, visual;
  uint16_t distance;
  int32_t leftSpeed, rightSpeed;
};
struct TelemetryValidity {bool calibrated,wheels,distance,vision;};
inline TelemetryValidity validity(const TelemetryFrame& f,bool fresh,bool allowEstimate,bool visualEnabled){
  return {bool(f.flags&0x80),fresh && bool(f.flags&0x10) && (bool(f.flags&0x80)||allowEstimate),
    fresh && bool(f.flags&1) && f.distance!=0xffff,
    fresh && visualEnabled && bool(f.visual&0x40) && !(f.visual&0x80) && (f.visual&7)==7};
}
inline uint32_t readLE32(const uint8_t* p) {
  return uint32_t(p[0]) | uint32_t(p[1])<<8 | uint32_t(p[2])<<16 | uint32_t(p[3])<<24;
}
inline int32_t readSignedLE32(const uint8_t* p) {
  uint32_t n=readLE32(p); return n<=0x7fffffffU ? int32_t(n) : int32_t(int64_t(n)-0x100000000LL);
}
// Sliding window recovers even if a corrupt frame contains another frame header.
class TelemetryParser {
  uint8_t data[40] = {}; size_t used=0;
public:
  uint32_t good=0, bad=0;
  void reset(){used=0;}
  bool push(uint8_t b, TelemetryFrame& f) {
    if(used==40){memmove(data,data+1,39);used=39;}
    data[used++]=b;
    if(used!=40 || data[0]!=0xa5 || data[1]!=0x5a) return false;
    uint8_t sum=0; for(size_t i=0;i<39;++i)sum^=data[i];
    if(data[2]!=1 || data[3]!=40 || sum!=data[39]){++bad;return false;}
    f.seq=data[4]; f.flags=data[5]; f.state=data[6]; f.gray=data[7];
    f.risk=data[8];f.blocked=data[9];f.distance=uint16_t(data[10])|uint16_t(data[11])<<8;
    f.leftDuty=data[12];f.rightDuty=data[13];
    f.leftSpeed=readSignedLE32(data+14);f.rightSpeed=readSignedLE32(data+18);f.visual=data[38];
    ++good; used=0;return true;
  }
};
