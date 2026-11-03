#ifndef FILE_SAVER_IO_H_
#define FILE_SAVER_IO_H_
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>
#include <cstdint>

inline std::wstring FileExtensionToFileFilter(std::wstring extension) {
  if (!extension.empty() && extension.front() == L'.') extension.erase(0, 1);
  std::wstring filter = L"Document";
  filter.push_back(L'\0');
  filter += extension.empty() ? L"*.*" : L"*." + extension;
  filter.push_back(L'\0');
  filter.push_back(L'\0');
  return filter;
}

inline bool WriteDocument(const std::filesystem::path& path,
                          const std::vector<uint8_t>& bytes) {
  std::ofstream file;
  file.open(path, std::ios::binary | std::ios::trunc);
  if (!file.is_open()) return false;
  file.write(reinterpret_cast<const char*>(bytes.data()), bytes.size());
  file.flush();
  const bool written = file.good();
  file.close();
  return written && !file.fail();
}
#endif
