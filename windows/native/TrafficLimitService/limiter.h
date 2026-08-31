#pragma once
#include <atomic>
#include <cstdint>
#include <thread>

class PacketLimiter {
 public:
  ~PacketLimiter();
  bool start(uint64_t downloadBits, uint64_t uploadBits);
  void stop();
  bool available() const;

 private:
  void loop(void* handle, const std::atomic_uint64_t& rate);
  std::atomic_bool running_{false};
  std::atomic_uint64_t download_{0};
  std::atomic_uint64_t upload_{0};
  void* inboundHandle_ = nullptr;
  void* outboundHandle_ = nullptr;
  std::thread inboundWorker_;
  std::thread outboundWorker_;
};
