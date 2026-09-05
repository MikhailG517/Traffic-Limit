#pragma once
#include <cstdint>
#include <unordered_map>
struct TrafficTotals { uint64_t received = 0; uint64_t sent = 0; };
class TrafficCounter {
 public:
  TrafficTotals read() const;
 private:
  struct InterfaceState {
    uint32_t received = 0;
    uint32_t sent = 0;
    uint64_t receivedTotal = 0;
    uint64_t sentTotal = 0;
    bool initialized = false;
  };
  mutable std::unordered_map<uint32_t, InterfaceState> states_;
};
