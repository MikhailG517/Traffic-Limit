#include "process_stats.h"
#include <algorithm>
#include <sstream>
namespace {
uint32_t localKey(uint8_t protocol, uint16_t port) {
  return (static_cast<uint32_t>(protocol) << 16) | port;
}
}
void ProcessStats::bind(const std::string& key, uint32_t processId) { std::lock_guard lock(mutex_); owners_[key] = processId; counters_.try_emplace(processId); }
void ProcessStats::bindLocal(uint8_t protocol, uint16_t port, uint32_t processId) { std::lock_guard lock(mutex_); localOwners_[localKey(protocol, port)] = processId; counters_.try_emplace(processId); }
void ProcessStats::add(const std::string& key, uint8_t protocol, uint16_t port, bool outbound, uint64_t bytes) { std::lock_guard lock(mutex_); auto owner = owners_.find(key); uint32_t pid = 0; if (owner != owners_.end()) pid = owner->second; else { const auto local = localOwners_.find(localKey(protocol, port)); if (local == localOwners_.end()) return; pid = local->second; } auto& counter = counters_[pid]; if (outbound) counter.sent += bytes; else counter.received += bytes; }
std::string ProcessStats::json() { std::lock_guard lock(mutex_); const auto now = std::chrono::steady_clock::now(); const double seconds = std::max(0.001, std::chrono::duration<double>(now - previous_).count()); previous_ = now; std::ostringstream output; output << "["; bool first = true; for (auto& [pid, counter] : counters_) { if (!first) output << ","; first = false; const auto receivedRate = (counter.received - counter.previousReceived) * 8.0 / seconds / 1000.0; const auto sentRate = (counter.sent - counter.previousSent) * 8.0 / seconds / 1000.0; output << "{\"pid\":" << pid << ",\"received\":" << counter.received << ",\"sent\":" << counter.sent << ",\"receivedRate\":" << receivedRate << ",\"sentRate\":" << sentRate << "}"; counter.previousReceived = counter.received; counter.previousSent = counter.sent; } output << "]"; return output.str(); }
