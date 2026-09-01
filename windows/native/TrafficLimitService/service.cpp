#include "service.h"
#include <sstream>
#include <cstring>
#include <iphlpapi.h>
#include <cstdlib>
#include <vector>
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
#include "windivert.h"
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
  if (flowHandle_ == INVALID_HANDLE_VALUE) flowHandle_ = nullptr;
  if (packetHandle_ == INVALID_HANDLE_VALUE) packetHandle_ = nullptr;
  driverAvailable_ = flowHandle_ != nullptr && packetHandle_ != nullptr;
  if (flowHandle_) { telemetryRunning_ = true; flowWorker_ = std::thread(&TrafficService::flowLoop, this); }
  if (packetHandle_) { telemetryRunning_ = true; packetWorker_ = std::thread(&TrafficService::packetLoop, this); }
#endif
  pipeLoop(); return true;
}
void TrafficService::stop(){
  if(stopEvent_){
    SetEvent(stopEvent_);
    HANDLE wake=CreateFileW(pipeName_.c_str(),GENERIC_WRITE,0,nullptr,OPEN_EXISTING,0,nullptr);
    if(wake!=INVALID_HANDLE_VALUE){DWORD written=0;const char request[]="--stop";WriteFile(wake,request,sizeof(request)-1,&written,nullptr);CloseHandle(wake);}
  }
  limiter_.stop();
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
  telemetryRunning_=false;
  driverAvailable_=false;
  if(flowHandle_){WinDivertClose(flowHandle_);flowHandle_=nullptr;}
  if(packetHandle_){WinDivertClose(packetHandle_);packetHandle_=nullptr;}
  if(flowWorker_.joinable())flowWorker_.join(); if(packetWorker_.joinable())packetWorker_.join();
#endif
}
std::string TrafficService::processJson(){return processStats_.json();}
bool TrafficService::driverAvailable() const { return driverAvailable_; }
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
void TrafficService::flowLoop(){
  WINDIVERT_ADDRESS address{}; while(telemetryRunning_){ if(!WinDivertRecv(flowHandle_,nullptr,0,nullptr,&address))continue; if(address.Event!=WINDIVERT_EVENT_FLOW_ESTABLISHED)continue; const auto& f=address.Flow; const auto key=flowKey(f.LocalAddr,f.RemoteAddr,f.LocalPort,f.RemotePort,f.Protocol); const auto reverse=flowKey(f.RemoteAddr,f.LocalAddr,f.RemotePort,f.LocalPort,f.Protocol); processStats_.bind(key,f.ProcessId); processStats_.bind(reverse,f.ProcessId); }
}
void TrafficService::refreshConnections(){
  DWORD size=0; if(GetExtendedTcpTable(nullptr,&size,FALSE,AF_INET,TCP_TABLE_OWNER_PID_ALL,0)!=ERROR_INSUFFICIENT_BUFFER)return;
  std::vector<std::byte> buffer(size); auto* table=reinterpret_cast<MIB_TCPTABLE_OWNER_PID*>(buffer.data()); if(GetExtendedTcpTable(table,&size,FALSE,AF_INET,TCP_TABLE_OWNER_PID_ALL,0)!=NO_ERROR)return;
  for(DWORD i=0;i<table->dwNumEntries;++i){const auto& row=table->table[i]; UINT32 local[4]={row.dwLocalAddr,0,0,0}; UINT32 remote[4]={row.dwRemoteAddr,0,0,0}; const auto localPort=ntohs(static_cast<UINT16>(row.dwLocalPort)); const auto remotePort=ntohs(static_cast<UINT16>(row.dwRemotePort)); const auto key=flowKey(local,remote,localPort,remotePort,IPPROTO_TCP); const auto reverse=flowKey(remote,local,remotePort,localPort,IPPROTO_TCP); processStats_.bind(key,row.dwOwningPid); processStats_.bind(reverse,row.dwOwningPid); processStats_.bindLocal(IPPROTO_TCP,localPort,row.dwOwningPid);}
  size=0; if(GetExtendedUdpTable(nullptr,&size,FALSE,AF_INET,UDP_TABLE_OWNER_PID,0)!=ERROR_INSUFFICIENT_BUFFER)return;
  buffer.resize(size); auto* udpTable=reinterpret_cast<MIB_UDPTABLE_OWNER_PID*>(buffer.data()); if(GetExtendedUdpTable(udpTable,&size,FALSE,AF_INET,UDP_TABLE_OWNER_PID,0)!=NO_ERROR)return;
  for(DWORD i=0;i<udpTable->dwNumEntries;++i){const auto& row=udpTable->table[i]; processStats_.bindLocal(IPPROTO_UDP,ntohs(static_cast<UINT16>(row.dwLocalPort)),row.dwOwningPid);}
}
void TrafficService::packetLoop(){
  char packet[65535]; UINT length=0; WINDIVERT_ADDRESS address{}; while(telemetryRunning_){ if(!WinDivertRecv(packetHandle_,packet,sizeof(packet),&length,&address))continue; PWINDIVERT_IPHDR ip=nullptr; PWINDIVERT_IPV6HDR ipv6=nullptr; UINT8 protocol=0; PWINDIVERT_TCPHDR tcp=nullptr; PWINDIVERT_UDPHDR udp=nullptr; if(!WinDivertHelperParsePacket(packet,length,&ip,&ipv6,&protocol,nullptr,nullptr,&tcp,&udp,nullptr,nullptr,nullptr,nullptr))continue; const auto sourcePort=ntohs(tcp?tcp->SrcPort:(udp?udp->SrcPort:0)); const auto destinationPort=ntohs(tcp?tcp->DstPort:(udp?udp->DstPort:0)); if(ip){ UINT32 source[4]={ip->SrcAddr,0,0,0}; UINT32 destination[4]={ip->DstAddr,0,0,0}; const auto key=flowKey(source,destination,sourcePort,destinationPort,protocol); processStats_.add(key, protocol, address.Outbound ? sourcePort : destinationPort, address.Outbound, length); } else if(ipv6){ const auto key=flowKey(ipv6->SrcAddr,ipv6->DstAddr,sourcePort,destinationPort,protocol); processStats_.add(key, protocol, address.Outbound ? sourcePort : destinationPort, address.Outbound, length); } }
}
#endif
void TrafficService::pipeLoop(){while(WaitForSingleObject(stopEvent_,0)==WAIT_TIMEOUT){HANDLE pipe=CreateNamedPipeW(pipeName_.c_str(),PIPE_ACCESS_DUPLEX,PIPE_TYPE_MESSAGE|PIPE_READMODE_MESSAGE,1,4*1024*1024,4*1024*1024,1000,nullptr);if(pipe==INVALID_HANDLE_VALUE)return;if(ConnectNamedPipe(pipe,nullptr)||GetLastError()==ERROR_PIPE_CONNECTED){char request[4096]{};DWORD read=0;ReadFile(pipe,request,sizeof(request)-1,&read,nullptr);if(strstr(request,"--disable"))limiter_.stop();auto readNumber=[&](const char* key){const char* at=strstr(request,key);return at?strtoull(at+strlen(key),nullptr,10):0ULL;};const auto down=readNumber("--download=");const auto up=readNumber("--upload=");if(down||up)limiter_.start(down,up);auto t=counter_.read();std::ostringstream response;if(strstr(request,"--get-processes")){
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
refreshConnections();
#endif
response<<processJson();}else if(strstr(request,"--get-status")){response<<"{\"driver\":"<<(driverAvailable()?"true":"false")<<",\"limiter\":"<<(limiter_.available()?"true":"false")<<"}";}else{response<<"{\"received\":"<<t.received<<",\"sent\":"<<t.sent<<",\"limiter\":"<<(limiter_.available()?"true":"false")<<"}";}auto out=response.str();DWORD written=0;WriteFile(pipe,out.data(),(DWORD)out.size(),&written,nullptr);FlushFileBuffers(pipe);DisconnectNamedPipe(pipe);}CloseHandle(pipe);}}
