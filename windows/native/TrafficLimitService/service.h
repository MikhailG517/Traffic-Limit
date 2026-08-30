#pragma once
#include "traffic_counter.h"
#include "limiter.h"
#include <windows.h>
#include <string>
class TrafficService { public: bool run(); void stop(); private: void pipeLoop(); std::wstring pipeName_=L"\\\\.\\pipe\\TrafficLimit"; HANDLE stopEvent_=nullptr; TrafficCounter counter_; PacketLimiter limiter_; };
