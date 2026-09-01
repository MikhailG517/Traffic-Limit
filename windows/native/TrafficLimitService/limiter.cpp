#include "limiter.h"
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
#include "windivert.h"
#include <windows.h>
#include <chrono>
#include <thread>
#include <timeapi.h>

namespace {
constexpr UINT kControlPacketBytes = 256;

class PacketPacer {
 public:
  void pace(UINT length, uint64_t rateBits) {
    if (rateBits == 0 || length <= kControlPacketBytes) return;
    const auto now = std::chrono::steady_clock::now();
    if (rateBits != rateBits_) {
      rateBits_ = rateBits;
      next_ = now;
    }
    const auto duration = std::chrono::nanoseconds(
        (static_cast<uint64_t>(length) * 8'000'000'000ULL) / rateBits);
    if (now >= next_) {
      next_ = now + duration;
      return;
    }
    std::this_thread::sleep_until(next_);
    next_ += duration;
  }

 private:
  uint64_t rateBits_ = 0;
  std::chrono::steady_clock::time_point next_{};
};

HANDLE openDivert(const char* filter) {
  const auto handle = WinDivertOpen(filter, WINDIVERT_LAYER_NETWORK, -100, 0);
  return handle == INVALID_HANDLE_VALUE ? nullptr : handle;
}
}
#endif

PacketLimiter::~PacketLimiter() { stop(); }

bool PacketLimiter::start(uint64_t downloadBits, uint64_t uploadBits) {
  download_ = downloadBits;
  upload_ = uploadBits;
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
  if (running_) return true;
  const auto inbound = openDivert("inbound and (tcp or udp)");
  const auto outbound = openDivert("outbound and (tcp or udp)");
  if (!inbound || !outbound) {
    if (inbound) WinDivertClose(inbound);
    if (outbound) WinDivertClose(outbound);
    return false;
  }
  inboundHandle_ = inbound;
  outboundHandle_ = outbound;
  // ~1 ms system timer so pacing delays are accurate (default ~15.6 ms
  // granularity otherwise over-throttles the link).
  ::timeBeginPeriod(1);
  for (auto* handle : {inbound, outbound}) {
    ::WinDivertSetParam(handle, WINDIVERT_PARAM_QUEUE_SIZE,
                        static_cast<UINT64>(64ULL * 1024ULL * 1024ULL));
    ::WinDivertSetParam(handle, WINDIVERT_PARAM_QUEUE_LENGTH, 4096);
  }
  running_ = true;
  inboundWorker_ = std::thread(&PacketLimiter::loop, this, inbound, std::cref(download_));
  outboundWorker_ = std::thread(&PacketLimiter::loop, this, outbound, std::cref(upload_));
  return true;
#else
  return false;
#endif
}

void PacketLimiter::stop() {
  running_ = false;
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
  const auto inbound = static_cast<HANDLE>(inboundHandle_);
  const auto outbound = static_cast<HANDLE>(outboundHandle_);
  inboundHandle_ = nullptr;
  outboundHandle_ = nullptr;
  ::timeEndPeriod(1);
  if (inbound) WinDivertClose(inbound);
  if (outbound) WinDivertClose(outbound);
  if (inboundWorker_.joinable()) inboundWorker_.join();
  if (outboundWorker_.joinable()) outboundWorker_.join();
#endif
}

bool PacketLimiter::available() const { return running_; }

#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
void PacketLimiter::loop(void* rawHandle, const std::atomic_uint64_t& rate) {
  const auto handle = static_cast<HANDLE>(rawHandle);
  char packet[65535];
  UINT length = 0;
  WINDIVERT_ADDRESS address{};
  PacketPacer pacer;
  while (running_) {
    if (!WinDivertRecv(handle, packet, sizeof(packet), &length, &address)) {
      if (!running_ || GetLastError() == ERROR_OPERATION_ABORTED) break;
      std::this_thread::sleep_for(std::chrono::milliseconds(10));
      continue;
    }
    pacer.pace(length, rate.load());
    if (!WinDivertSend(handle, packet, length, nullptr, &address) && running_) {
      std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
  }
}
#endif
