#pragma once
#include "traffic_counter.h"
#include "limiter.h"
#include "process_stats.h"
#include <winsock2.h>
#include <windows.h>
#include <atomic>
#include <string>
#include <thread>
class TrafficService {
 public:
  bool run();
  void stop();
  std::string processJson();
  bool driverAvailable() const;
 private:
  void pipeLoop();
  std::wstring pipeName_=LR"(\\.\pipe\TrafficLimit)";
  HANDLE stopEvent_=nullptr;
  TrafficCounter counter_;
  PacketLimiter limiter_;
  ProcessStats processStats_;
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
  HANDLE flowHandle_=nullptr;
  HANDLE packetHandle_=nullptr;
  std::thread flowWorker_;
  std::thread packetWorker_;
  std::atomic_bool telemetryRunning_{false};
  std::atomic_bool driverAvailable_{false};
  void flowLoop();
  void packetLoop();
  void refreshConnections();
#endif
};
