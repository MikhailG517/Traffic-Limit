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
  void loop();
  std::atomic_bool running_{false};
  std::atomic_uint64_t download_{0};
  std::atomic_uint64_t upload_{0};
  void* handle_ = nullptr;
  std::thread worker_;
};
