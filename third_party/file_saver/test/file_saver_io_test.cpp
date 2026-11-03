#include "../windows/file_saver_io.h"
#include <cassert>
#include <chrono>
#include <iterator>
int main() {
  const auto filter = FileExtensionToFileFilter(L".pdf");
  assert(filter == std::wstring(L"Document\0*.pdf\0\0", 16));
  assert(FileExtensionToFileFilter(L"xlsx") == std::wstring(L"Document\0*.xlsx\0\0", 17));
  assert(FileExtensionToFileFilter(L"") == std::wstring(L"Document\0*.*\0\0", 14));
  const auto nonce = std::chrono::high_resolution_clock::now().time_since_epoch().count();
  const auto folder = std::filesystem::temp_directory_path() /
      ("target-saver-io-test-" + std::to_string(nonce));
  // Never reuse or remove a pre-existing directory or file.
  if (!std::filesystem::create_directory(folder)) return 1;
  const auto path = folder / "export.pdf";
  assert(WriteDocument(path, {1, 2, 3}));
  std::ifstream input(path, std::ios::binary);
  const std::vector<uint8_t> actual((std::istreambuf_iterator<char>(input)), {});
  assert((actual == std::vector<uint8_t>{1, 2, 3}));
  input.close();
  assert(!WriteDocument(folder / "missing" / "export.pdf", {4}));
  std::filesystem::remove(path);
  std::filesystem::remove(folder);
}
