#include <winsock2.h>
#include <windows.h>
#include <iphlpapi.h>
#include <vector>
#include "traffic_counter.h"

TrafficTotals TrafficCounter::read() const {
  DWORD size = 0;
  if (GetIfTable(nullptr, &size, FALSE) != ERROR_INSUFFICIENT_BUFFER) return {};
  std::vector<std::byte> buffer(size);
  auto* table = reinterpret_cast<MIB_IFTABLE*>(buffer.data());
  if (GetIfTable(table, &size, FALSE) != NO_ERROR) return {};

  TrafficTotals totals;
  for (DWORD i = 0; i < table->dwNumEntries; ++i) {
    const auto& row = table->table[i];
    if (row.dwType == MIB_IF_TYPE_LOOPBACK) continue;
    auto& state = states_[row.dwIndex];
    if (!state.initialized) {
      state.receivedTotal = row.dwInOctets;
      state.sentTotal = row.dwOutOctets;
      state.initialized = true;
    } else {
      state.receivedTotal += static_cast<DWORD>(row.dwInOctets - state.received);
      state.sentTotal += static_cast<DWORD>(row.dwOutOctets - state.sent);
    }
    state.received = row.dwInOctets;
    state.sent = row.dwOutOctets;
    totals.received += state.receivedTotal;
    totals.sent += state.sentTotal;
  }
  return totals;
}
