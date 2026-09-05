#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {
constexpr wchar_t kInstanceMutex[] = L"Local\\TrafficLimit.SingleInstance";

struct ExistingWindowSearch {
  std::wstring executable;
  HWND window = nullptr;
};

BOOL CALLBACK FindExistingWindow(HWND window, LPARAM parameter) {
  auto* search = reinterpret_cast<ExistingWindowSearch*>(parameter);
  DWORD process_id = 0;
  GetWindowThreadProcessId(window, &process_id);
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
  if (!process) return TRUE;
  wchar_t path[MAX_PATH]{};
  DWORD length = MAX_PATH;
  const bool same_executable =
      QueryFullProcessImageNameW(process, 0, path, &length) &&
      search->executable == path;
  CloseHandle(process);
  if (same_executable) {
    search->window = window;
    return FALSE;
  }
  return TRUE;
}

void ActivateExistingInstance() {
  wchar_t executable[MAX_PATH]{};
  GetModuleFileNameW(nullptr, executable, MAX_PATH);
  ExistingWindowSearch search{executable};
  EnumWindows(FindExistingWindow, reinterpret_cast<LPARAM>(&search));
  if (!search.window) return;
  ShowWindow(search.window, SW_RESTORE);
  SetForegroundWindow(search.window);
}
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE instance_mutex = CreateMutexW(nullptr, TRUE, kInstanceMutex);
  if (!instance_mutex) return EXIT_FAILURE;
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    if (!wcsstr(GetCommandLineW(), L"--autostart")) ActivateExistingInstance();
    CloseHandle(instance_mutex);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"traffic_limit", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  CloseHandle(instance_mutex);
  return EXIT_SUCCESS;
}
