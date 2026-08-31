#include "service.h"
#include <sstream>
#include <cstring>
#include <cstdlib>
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
#include "windivert.h"
#include <winsock2.h>
static std::string flowKey(const UINT32* source, const UINT32* destination, UINT16 sourcePort, UINT16 destinationPort, UINT8 protocol) {
  std::ostringstream key;
  key << protocol << ':';
  for (int i=0;i<4;++i) key << source[i] << ':';
  for (int i=0;i<4;++i) key << destination[i] << ':';
  key << sourcePort << ':' << destinationPort;
  return key.str();
}
#endif
bool TrafficService::run(){
  stopEvent_=CreateEventW(nullptr,TRUE,FALSE,nullptr);
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
  flowHandle_=WinDivertOpen("true",WINDIVERT_LAYER_FLOW,10,0);
  packetHandle_=WinDivertOpen("tcp or udp",WINDIVERT_LAYER_NETWORK,10,WINDIVERT_FLAG_SNIFF);
  if(flowHandle_ && packetHandle_){ telemetryRunning_=true; flowWorker_=std::thread(&TrafficService::flowLoop,this); packetWorker_=std::thread(&TrafficService::packetLoop,this); }
#endif
  pipeLoop(); return true;
}
void TrafficService::stop(){
  if(stopEvent_)SetEvent(stopEvent_); limiter_.stop();
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
  telemetryRunning_=false;
  if(flowHandle_){WinDivertClose(flowHandle_);flowHandle_=nullptr;}
  if(packetHandle_){WinDivertClose(packetHandle_);packetHandle_=nullptr;}
  if(flowWorker_.joinable())flowWorker_.join(); if(packetWorker_.joinable())packetWorker_.join();
#endif
}
std::string TrafficService::processJson(){return processStats_.json();}
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
void TrafficService::flowLoop(){
  WINDIVERT_ADDRESS address{}; while(telemetryRunning_){ if(!WinDivertRecv(flowHandle_,nullptr,0,nullptr,&address))continue; if(address.Event!=WINDIVERT_EVENT_FLOW_ESTABLISHED)continue; const auto& f=address.Flow; const auto key=flowKey(f.LocalAddr,f.RemoteAddr,f.LocalPort,f.RemotePort,f.Protocol); const auto reverse=flowKey(f.RemoteAddr,f.LocalAddr,f.RemotePort,f.LocalPort,f.Protocol); processStats_.bind(key,f.ProcessId); processStats_.bind(reverse,f.ProcessId); }
}
void TrafficService::packetLoop(){
  char packet[65535]; UINT length=0; WINDIVERT_ADDRESS address{}; while(telemetryRunning_){ if(!WinDivertRecv(packetHandle_,packet,sizeof(packet),&length,&address))continue; PWINDIVERT_IPHDR ip=nullptr; PWINDIVERT_IPV6HDR ipv6=nullptr; UINT8 protocol=0; PWINDIVERT_TCPHDR tcp=nullptr; PWINDIVERT_UDPHDR udp=nullptr; if(!WinDivertHelperParsePacket(packet,length,&ip,&ipv6,&protocol,nullptr,nullptr,&tcp,&udp,nullptr,nullptr,nullptr,nullptr))continue; const auto sourcePort=tcp?tcp->SrcPort:(udp?udp->SrcPort:0); const auto destinationPort=tcp?tcp->DstPort:(udp?udp->DstPort:0); if(ip){ UINT32 source[4]={ip->SrcAddr,0,0,0}; UINT32 destination[4]={ip->DstAddr,0,0,0}; const auto key=flowKey(source,destination,sourcePort,destinationPort,protocol); processStats_.add(key,address.Outbound,length); } else if(ipv6){ const auto key=flowKey(ipv6->SrcAddr,ipv6->DstAddr,sourcePort,destinationPort,protocol); processStats_.add(key,address.Outbound,length); } }
}
#endif
void TrafficService::pipeLoop(){while(WaitForSingleObject(stopEvent_,0)==WAIT_TIMEOUT){HANDLE pipe=CreateNamedPipeW(pipeName_.c_str(),PIPE_ACCESS_DUPLEX,PIPE_TYPE_MESSAGE|PIPE_READMODE_MESSAGE,1,65536,65536,1000,nullptr);if(pipe==INVALID_HANDLE_VALUE)return;if(ConnectNamedPipe(pipe,nullptr)||GetLastError()==ERROR_PIPE_CONNECTED){char request[512]{};DWORD read=0;ReadFile(pipe,request,sizeof(request)-1,&read,nullptr);if(strstr(request,"--disable"))limiter_.stop();auto readNumber=[&](const char* key){const char* at=strstr(request,key);return at?strtoull(at+strlen(key),nullptr,10):0ULL;};const auto down=readNumber("--download=");const auto up=readNumber("--upload=");if(down||up)limiter_.start(down,up);auto t=counter_.read();std::ostringstream response;if(strstr(request,"--get-processes")){response<<processJson();}else{response<<"{\"received\":"<<t.received<<",\"sent\":"<<t.sent<<",\"limiter\":"<<(limiter_.available()?"true":"false")<<"}";}auto out=response.str();DWORD written=0;WriteFile(pipe,out.data(),(DWORD)out.size(),&written,nullptr);FlushFileBuffers(pipe);DisconnectNamedPipe(pipe);}CloseHandle(pipe);}}
