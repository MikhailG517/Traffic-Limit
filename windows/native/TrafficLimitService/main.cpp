#include "service.h"
#include <windows.h>
#include <string>
#include <cstdio>
static TrafficService* g_service=nullptr; static SERVICE_STATUS_HANDLE g_statusHandle=nullptr; static SERVICE_STATUS g_status{};
static void WINAPI Handler(DWORD control){if(control==SERVICE_CONTROL_STOP||control==SERVICE_CONTROL_SHUTDOWN){g_status.dwCurrentState=SERVICE_STOP_PENDING;SetServiceStatus(g_statusHandle,&g_status);if(g_service)g_service->stop();}}
static void WINAPI ServiceMain(DWORD,LPWSTR*){g_statusHandle=RegisterServiceCtrlHandlerW(L"TrafficLimitService",Handler);g_status.dwServiceType=SERVICE_WIN32_OWN_PROCESS;g_status.dwControlsAccepted=SERVICE_ACCEPT_STOP|SERVICE_ACCEPT_SHUTDOWN;g_status.dwCurrentState=SERVICE_RUNNING;SetServiceStatus(g_statusHandle,&g_status);TrafficService service;g_service=&service;service.run();g_status.dwCurrentState=SERVICE_STOPPED;SetServiceStatus(g_statusHandle,&g_status);}
static bool InstallService(){
  wchar_t path[MAX_PATH]{}; GetModuleFileNameW(nullptr,path,MAX_PATH);
  SC_HANDLE manager=OpenSCManagerW(nullptr,nullptr,SC_MANAGER_CREATE_SERVICE); if(!manager)return false;
  std::wstring commandLine = L"\"" + std::wstring(path) + L"\"";
  SC_HANDLE service=CreateServiceW(manager,L"TrafficLimitService",L"Traffic Limit Service",SERVICE_ALL_ACCESS,SERVICE_WIN32_OWN_PROCESS,SERVICE_AUTO_START,SERVICE_ERROR_NORMAL,commandLine.c_str(),nullptr,nullptr,nullptr,nullptr,nullptr);
  if(!service && GetLastError()==ERROR_SERVICE_EXISTS) service=OpenServiceW(manager,L"TrafficLimitService",SERVICE_START|SERVICE_QUERY_STATUS);
  if(!service){CloseServiceHandle(manager);return false;}
  const bool started=StartServiceW(service,0,nullptr) || GetLastError()==ERROR_SERVICE_ALREADY_RUNNING;
  CloseServiceHandle(service); CloseServiceHandle(manager); return started;
}
static bool UninstallService(){SC_HANDLE manager=OpenSCManagerW(nullptr,nullptr,SC_MANAGER_CONNECT);if(!manager)return false;SC_HANDLE service=OpenServiceW(manager,L"TrafficLimitService",DELETE|SERVICE_STOP);if(!service){CloseServiceHandle(manager);return true;}SERVICE_STATUS status{};ControlService(service,SERVICE_CONTROL_STOP,&status);const bool ok=DeleteService(service);CloseServiceHandle(service);CloseServiceHandle(manager);return ok;}
static int SendLimit(const std::wstring& args){HANDLE pipe=CreateFileW(LR"(\\.\pipe\TrafficLimit)",GENERIC_READ|GENERIC_WRITE,0,nullptr,OPEN_EXISTING,0,nullptr);if(pipe==INVALID_HANDLE_VALUE)return 1;std::string payload(args.begin(),args.end()); DWORD written=0;WriteFile(pipe,payload.data(),(DWORD)payload.size(),&written,nullptr);char response[512]{};DWORD read=0;ReadFile(pipe,response,sizeof(response)-1,&read,nullptr);response[read]=0;DWORD out=0;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),response,read,&out,nullptr);CloseHandle(pipe);return 0;}
int WINAPI wWinMain(HINSTANCE,HINSTANCE,PWSTR command,int){std::wstring args=command?command:L"";if(args.find(L"--install")!=std::wstring::npos)return InstallService()?0:1;if(args.find(L"--uninstall")!=std::wstring::npos)return UninstallService()?0:1;if(args.find(L"--set-limit")!=std::wstring::npos||args.find(L"--get-processes")!=std::wstring::npos||args.find(L"--get-status")!=std::wstring::npos||args.find(L"--disable")!=std::wstring::npos)return SendLimit(args);SERVICE_TABLE_ENTRYW table[]={{const_cast<LPWSTR>(L"TrafficLimitService"),ServiceMain},{nullptr,nullptr}};return StartServiceCtrlDispatcherW(table)?0:1;}
