#include "service.h"
#include <sstream>
#include <cstring>
#include <cstdlib>
bool TrafficService::run(){stopEvent_=CreateEventW(nullptr,TRUE,FALSE,nullptr);pipeLoop();return true;}
void TrafficService::stop(){if(stopEvent_)SetEvent(stopEvent_);limiter_.stop();}
void TrafficService::pipeLoop(){while(WaitForSingleObject(stopEvent_,0)==WAIT_TIMEOUT){HANDLE pipe=CreateNamedPipeW(pipeName_.c_str(),PIPE_ACCESS_DUPLEX,PIPE_TYPE_MESSAGE|PIPE_READMODE_MESSAGE,1,4096,4096,1000,nullptr);if(pipe==INVALID_HANDLE_VALUE)return;if(ConnectNamedPipe(pipe,nullptr)||GetLastError()==ERROR_PIPE_CONNECTED){char request[256]{};DWORD read=0;ReadFile(pipe,request,sizeof(request)-1,&read,nullptr);
      auto readNumber=[&](const char* key){const char* at=strstr(request,key);return at?strtoull(at+strlen(key),nullptr,10):0ULL;};
      const auto down=readNumber("\"download\":"); const auto up=readNumber("\"upload\":"); if(down||up) limiter_.start(down,up);
      auto t=counter_.read();std::ostringstream response;response<<"{\"received\":"<<t.received<<",\"sent\":"<<t.sent<<",\"limiter\":"<<(limiter_.available()?"true":"false")<<"}";auto out=response.str();DWORD written=0;WriteFile(pipe,out.data(),(DWORD)out.size(),&written,nullptr);FlushFileBuffers(pipe);DisconnectNamedPipe(pipe);}CloseHandle(pipe);}}
