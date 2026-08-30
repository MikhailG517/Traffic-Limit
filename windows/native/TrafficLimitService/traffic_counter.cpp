#include <winsock2.h>
#include <windows.h>
#include <iphlpapi.h>
#include <vector>
#include "traffic_counter.h"
TrafficTotals TrafficCounter::read() const {
  DWORD size=0; if(GetIfTable(nullptr,&size,FALSE)!=ERROR_INSUFFICIENT_BUFFER) return {};
  std::vector<std::byte> buffer(size); auto* table=reinterpret_cast<MIB_IFTABLE*>(buffer.data()); TrafficTotals totals;
  if(GetIfTable(table,&size,FALSE)==NO_ERROR){ for(DWORD i=0;i<table->dwNumEntries;++i){const auto& row=table->table[i]; if(row.dwType!=MIB_IF_TYPE_LOOPBACK){totals.received+=row.dwInOctets; totals.sent+=row.dwOutOctets;}} } return totals;
}
