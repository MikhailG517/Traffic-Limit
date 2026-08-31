#include <winsock2.h>
#include <windows.h>
#include <iphlpapi.h>
#include <netioapi.h>
#include "traffic_counter.h"

TrafficTotals TrafficCounter::read() const {
  MIB_IF_TABLE2* table = nullptr;
  TrafficTotals totals;
  if (GetIfTable2(&table) != NO_ERROR) return totals;
  for (ULONG i = 0; i < table->NumEntries; ++i) {
    const auto& row = table->Table[i];
    if (row.InterfaceType == IF_TYPE_SOFTWARE_LOOPBACK) continue;
    totals.received += row.InOctets;
    totals.sent += row.OutOctets;
  }
  FreeMibTable(table);
  return totals;
}
