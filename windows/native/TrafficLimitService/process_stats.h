#pragma once
#include <cstdint>
#include <string>
#include <unordered_map>
#include <mutex>
#include <chrono>

struct ProcessCounters {
  uint64_t received = 0;
  uint64_t sent = 0;
  uint64_t previousReceived = 0;
  uint64_t previousSent = 0;
};

class ProcessStats {
 public:
  void bind(const std::string& key, uint32_t processId);
  void add(const std::string& key, bool outbound, uint64_t bytes);
  std::string json();
 private:
  std::mutex mutex_;
  std::unordered_map<std::string, uint32_t> owners_;
  std::unordered_map<uint32_t, ProcessCounters> counters_;
  std::chrono::steady_clock::time_point previous_ = std::chrono::steady_clock::now();
};
