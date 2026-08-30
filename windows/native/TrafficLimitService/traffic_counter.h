#pragma once
#include <cstdint>
struct TrafficTotals { uint64_t received = 0; uint64_t sent = 0; };
class TrafficCounter { public: TrafficTotals read() const; };
