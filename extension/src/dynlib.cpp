#include "dynlib.h"

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#else
#include <dlfcn.h>
#endif

namespace redox {

#ifdef _WIN32

void *dynlib_open(const std::string &utf8_path, std::string &r_error) {
	int len = MultiByteToWideChar(CP_UTF8, 0, utf8_path.c_str(), -1, nullptr, 0);
	std::wstring wide(len > 0 ? len : 1, L'\0');
	MultiByteToWideChar(CP_UTF8, 0, utf8_path.c_str(), -1, wide.data(), len);

	// Lets the core find DLLs that sit next to it.
	HMODULE h = LoadLibraryExW(wide.c_str(), nullptr, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
	if (!h) {
		r_error = "LoadLibrary failed, Windows error " + std::to_string(GetLastError());
	}
	return reinterpret_cast<void *>(h);
}

void *dynlib_symbol(void *handle, const char *name) {
	return reinterpret_cast<void *>(GetProcAddress(reinterpret_cast<HMODULE>(handle), name));
}

void dynlib_close(void *handle) {
	if (handle) {
		FreeLibrary(reinterpret_cast<HMODULE>(handle));
	}
}

#else

void *dynlib_open(const std::string &utf8_path, std::string &r_error) {
	void *h = dlopen(utf8_path.c_str(), RTLD_NOW | RTLD_LOCAL);
	if (!h) {
		const char *e = dlerror();
		r_error = e ? e : "dlopen failed";
	}
	return h;
}

void *dynlib_symbol(void *handle, const char *name) {
	return dlsym(handle, name);
}

void dynlib_close(void *handle) {
	if (handle) {
		dlclose(handle);
	}
}

#endif

} // namespace redox
