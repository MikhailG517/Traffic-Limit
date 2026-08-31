#include "limiter.h"
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
#include "windivert.h"
#include <windows.h>
#include <chrono>
#include <thread>

namespace {
constexpr UINT kControlPacketBytes = 256;

void waitForRate(UINT length, uint64_t rateBits) {
  if (rateBits == 0 || length <= kControlPacketBytes) return;
  const auto delay = std::chrono::microseconds(
      (static_cast<uint64_t>(length) * 8'000'000ULL) / rateBits);
  if (delay.count() > 0) std::this_thread::sleep_for(delay);
}
}
#endif

PacketLimiter::~PacketLimiter() { stop(); }

bool PacketLimiter::start(uint64_t downloadBits, uint64_t uploadBits) {
  download_ = downloadBits;
  upload_ = uploadBits;
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
  if (running_) return true;
  const auto handle = WinDivertOpen("tcp or udp", WINDIVERT_LAYER_NETWORK, -100, 0);
  if (handle == INVALID_HANDLE_VALUE || handle == nullptr) return false;
  handle_ = handle;
  running_ = true;
  worker_ = std::thread(&PacketLimiter::loop, this);
  return true;
#else
  return false;
#endif
}

void PacketLimiter::stop() {
  running_ = false;
#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
  const auto handle = static_cast<HANDLE>(handle_);
  handle_ = nullptr;
  if (handle) WinDivertClose(handle);
  if (worker_.joinable()) worker_.join();
#endif
}

bool PacketLimiter::available() const { return running_; }

#ifdef TRAFFIC_LIMIT_USE_WINDIVERT
void PacketLimiter::loop() {
  char packet[65535];
  UINT length = 0;
  WINDIVERT_ADDRESS address{};
  const auto handle = static_cast<HANDLE>(handle_);
  while (running_) {
    if (!WinDivertRecv(handle, packet, sizeof(packet), &length, &address)) {
      if (!running_ || GetLastError() == ERROR_OPERATION_ABORTED) break;
      std::this_thread::sleep_for(std::chrono::milliseconds(10));
      continue;
    }
    waitForRate(length, address.Outbound ? upload_.load() : download_.load());
    if (!WinDivertSend(handle, packet, length, nullptr, &address) && running_) {
      std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
  }
}
#endif
