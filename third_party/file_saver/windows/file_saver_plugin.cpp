#include "include/file_saver/file_saver_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <Commdlg.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <sstream>
#include <algorithm>
#include <fstream>
#include "file_saver_io.h"

namespace {

class FileSaverPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FileSaverPlugin();

  virtual ~FileSaverPlugin();

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

// static
void FileSaverPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "file_saver",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FileSaverPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FileSaverPlugin::FileSaverPlugin() {}

FileSaverPlugin::~FileSaverPlugin() {}

std::vector<int64_t> WideStringToVector(const wchar_t* wideStr) {
  std::vector<int64_t> result;

  int length = 0;
  while (wideStr[length] != L'\0') {
    length++;
  }

  for (int i = 0; i < length; i++) {
    result.push_back(static_cast<int64_t>(wideStr[i]));
  }

  return result;
}

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) return L"";
  const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
      value.data(), static_cast<int>(value.size()), nullptr, 0);
  if (size == 0) throw std::runtime_error("Invalid UTF-8 filename");
  std::wstring output(size, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
      static_cast<int>(value.size()), output.data(), size);
  return output;
}

void FileSaverPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("saveAs") == 0) {
    try {
    const auto& arguments = *method_call.arguments();
    const auto& mapArgs = std::get<flutter::EncodableMap>(arguments);

    const flutter::EncodableValue& inputFileNameValue = mapArgs.at(flutter::EncodableValue("name"));
    const std::string inputFileName = std::get<std::string>(inputFileNameValue);

    const flutter::EncodableValue& inputExtensionValue = mapArgs.at(flutter::EncodableValue("ext"));
    const std::string inputExtension = std::get<std::string>(inputExtensionValue);

    const flutter::EncodableValue& inputFileValue = mapArgs.at(flutter::EncodableValue("bytes"));
    const std::vector<uint8_t> inputFileBytes = std::get<std::vector<uint8_t>>(inputFileValue);

    const std::string defaultFileName = inputFileName + (inputExtension.find(".") != std::string::npos ? inputExtension : ("." + inputExtension));
    wchar_t szFile[32768] = L"";
    const std::wstring wideName = Utf8ToWide(defaultFileName);
    if (wideName.size() >= 32768) throw std::runtime_error("Filename too long");
    std::copy(wideName.begin(), wideName.end(), szFile);
    const std::wstring defaultFileFilter = FileExtensionToFileFilter(Utf8ToWide(inputExtension));
    OPENFILENAMEW ofn{};
    ofn.lStructSize = sizeof(ofn);
    ofn.lpstrFilter = defaultFileFilter.c_str();
    ofn.lpstrFile = szFile;
    ofn.nMaxFile = 32768;
    ofn.Flags = OFN_OVERWRITEPROMPT | OFN_PATHMUSTEXIST | OFN_HIDEREADONLY;

    if (GetSaveFileNameW(&ofn)) {
      if (!WriteDocument(std::filesystem::path(szFile), inputFileBytes)) {
        result->Error("FILE_WRITE_ERROR", "Unable to write and close document");
        return;
      }
      result->Success(flutter::EncodableValue(WideStringToVector(szFile)));
    } else {
      const DWORD error = CommDlgExtendedError();
      if (error == 0) {
        result->Success(flutter::EncodableValue());  // User cancelled.
      } else {
        result->Error("SAVE_DIALOG_ERROR", "Save dialog failed");
      }
    }
    } catch (const std::exception& error) {
      result->Error("FILE_WRITE_ERROR", error.what());
    }

  } else {
    result->NotImplemented();
  }
}

}  // namespace

void FileSaverPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  FileSaverPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
