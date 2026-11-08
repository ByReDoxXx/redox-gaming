#pragma once

#include <string>

// Small cross-platform wrapper for loading libretro cores (.dll / .so).
// Kept in its own file so <windows.h> never meets the godot-cpp headers.
namespace redox {

void *dynlib_open(const std::string &utf8_path, std::string &r_error);
void *dynlib_symbol(void *handle, const char *name);
void dynlib_close(void *handle);

} // namespace redox
