#include "limiter.h"
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
#include "windivert.h"
#include <windows.h>
#include <chrono>
#include <thread>
static HANDLE divertHandle=nullptr;
#endif
PacketLimiter::~PacketLimiter(){stop();}
bool PacketLimiter::start(uint64_t downloadBits,uint64_t uploadBits){download_=downloadBits;upload_=uploadBits;
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
  if(running_){ download_=downloadBits; upload_=uploadBits; return true; } divertHandle=WinDivertOpen("true",WINDIVERT_LAYER_NETWORK,0,0); if(!divertHandle)return false; running_=true; worker_=std::thread(&PacketLimiter::loop,this); return true;
#else
  return false;
#endif
}
void PacketLimiter::stop(){running_=false;
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
  if(divertHandle){WinDivertClose(divertHandle);divertHandle=nullptr;} if(worker_.joinable())worker_.join();
#endif
}
bool PacketLimiter::available()const{return running_;}
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
void PacketLimiter::loop(){char packet[65535];UINT length=0;WINDIVERT_ADDRESS address{};while(running_){if(!WinDivertRecv(divertHandle,packet,sizeof(packet),&length,&address))continue;const uint64_t rate=address.Outbound?upload_.load():download_.load();if(rate>0){const auto micros=(length*8ULL*1000000ULL)/rate; if(micros>0)std::this_thread::sleep_for(std::chrono::microseconds(micros));}WinDivertSend(divertHandle,packet,length,nullptr,&address);}}
#endif
