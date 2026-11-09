#include "retro_host.h"

#include "dynlib.h"
#include "ra_client.h"

#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cstdarg>
#include <cstdio>
#include <cstring>

using namespace godot;

// libretro callbacks are plain C functions with no user pointer, so only one
// RetroHost can own the loaded core at a time.
static RetroHost *s_active = nullptr;

namespace {

String to_global(const String &p_path) {
	if (p_path.is_empty()) {
		return p_path;
	}
	return ProjectSettings::get_singleton()->globalize_path(p_path);
}

void RETRO_CALLCONV cb_log(enum retro_log_level p_level, const char *p_fmt, ...) {
	char buf[2048];
	va_list args;
	va_start(args, p_fmt);
	vsnprintf(buf, sizeof(buf), p_fmt, args);
	va_end(args);

	String msg = String::utf8(buf).strip_edges();
	if (msg.is_empty()) {
		return;
	}
	switch (p_level) {
		case RETRO_LOG_ERROR:
			UtilityFunctions::push_error("[core] ", msg);
			break;
		case RETRO_LOG_WARN:
			UtilityFunctions::push_warning("[core] ", msg);
			break;
		case RETRO_LOG_INFO:
			UtilityFunctions::print("[core] ", msg);
			break;
		default:
			UtilityFunctions::print_verbose("[core] ", msg);
			break;
	}
}

bool RETRO_CALLCONV cb_environment(unsigned p_cmd, void *p_data) {
	return s_active ? s_active->on_environment(p_cmd, p_data) : false;
}

void RETRO_CALLCONV cb_video(const void *p_data, unsigned p_w, unsigned p_h, size_t p_pitch) {
	if (s_active) {
		s_active->on_video(p_data, p_w, p_h, p_pitch);
	}
}

void RETRO_CALLCONV cb_audio_sample(int16_t p_left, int16_t p_right) {
	if (s_active) {
		int16_t frame[2] = { p_left, p_right };
		s_active->on_audio(frame, 1);
	}
}

size_t RETRO_CALLCONV cb_audio_batch(const int16_t *p_data, size_t p_frames) {
	if (s_active) {
		s_active->on_audio(p_data, p_frames);
	}
	return p_frames;
}

void RETRO_CALLCONV cb_input_poll() {
	// Input is pushed from Godot with set_button(), nothing to poll here.
}

int16_t RETRO_CALLCONV cb_input_state(unsigned p_port, unsigned p_device, unsigned p_index, unsigned p_id) {
	return s_active ? s_active->on_input_state(p_port, p_device, p_index, p_id) : 0;
}

} // namespace

RetroHost::RetroHost() {
	frame_image.instantiate();
	texture.instantiate();
}

RetroHost::~RetroHost() {
	unload_core();
}

// ---------------------------------------------------------------- lifecycle

bool RetroHost::load_core(const String &p_path) {
	unload_core();

	if (s_active && s_active != this) {
		UtilityFunctions::push_error("RetroHost: another RetroHost already owns a core.");
		return false;
	}

	std::string err;
	std::string path = to_global(p_path).utf8().get_data();
	lib_handle = redox::dynlib_open(path, err);
	if (!lib_handle) {
		UtilityFunctions::push_error("RetroHost: could not load core ", p_path, ": ", String::utf8(err.c_str()));
		return false;
	}

	bool ok = true;
#define LOAD_SYM(field, name)                                                              \
	core.field = reinterpret_cast<decltype(core.field)>(redox::dynlib_symbol(lib_handle, name)); \
	if (!core.field) {                                                                     \
		UtilityFunctions::push_error("RetroHost: core is missing symbol ", name);          \
		ok = false;                                                                        \
	}

	LOAD_SYM(init, "retro_init");
	LOAD_SYM(deinit, "retro_deinit");
	LOAD_SYM(api_version, "retro_api_version");
	LOAD_SYM(get_system_info, "retro_get_system_info");
	LOAD_SYM(get_system_av_info, "retro_get_system_av_info");
	LOAD_SYM(set_environment, "retro_set_environment");
	LOAD_SYM(set_video_refresh, "retro_set_video_refresh");
	LOAD_SYM(set_audio_sample, "retro_set_audio_sample");
	LOAD_SYM(set_audio_sample_batch, "retro_set_audio_sample_batch");
	LOAD_SYM(set_input_poll, "retro_set_input_poll");
	LOAD_SYM(set_input_state, "retro_set_input_state");
	LOAD_SYM(set_controller_port_device, "retro_set_controller_port_device");
	LOAD_SYM(reset, "retro_reset");
	LOAD_SYM(run, "retro_run");
	LOAD_SYM(serialize_size, "retro_serialize_size");
	LOAD_SYM(serialize, "retro_serialize");
	LOAD_SYM(unserialize, "retro_unserialize");
	LOAD_SYM(load_game, "retro_load_game");
	LOAD_SYM(unload_game, "retro_unload_game");
	LOAD_SYM(get_memory_data, "retro_get_memory_data");
	LOAD_SYM(get_memory_size, "retro_get_memory_size");
#undef LOAD_SYM
	// optional
	core.cheat_reset = reinterpret_cast<decltype(core.cheat_reset)>(redox::dynlib_symbol(lib_handle, "retro_cheat_reset"));
	core.cheat_set = reinterpret_cast<decltype(core.cheat_set)>(redox::dynlib_symbol(lib_handle, "retro_cheat_set"));

	if (!ok) {
		redox::dynlib_close(lib_handle);
		lib_handle = nullptr;
		core = CoreApi();
		return false;
	}

	if (core.api_version() != RETRO_API_VERSION) {
		UtilityFunctions::push_warning("RetroHost: core API version ", core.api_version(), " differs from ", RETRO_API_VERSION);
	}

	s_active = this;
	core_path = p_path;
	pixel_format = RETRO_PIXEL_FORMAT_0RGB1555;
	variables.clear();
	has_mmap = false;
	frame_time_cb = {};
	mmap_descriptors.clear();

	core.set_environment(cb_environment);
	core.set_video_refresh(cb_video);
	core.set_audio_sample(cb_audio_sample);
	core.set_audio_sample_batch(cb_audio_batch);
	core.set_input_poll(cb_input_poll);
	core.set_input_state(cb_input_state);
	core.init();
	core_initialized = true;

	retro_system_info info{};
	core.get_system_info(&info);
	core_name = String::utf8(info.library_name ? info.library_name : "");
	core_version = String::utf8(info.library_version ? info.library_version : "");
	valid_extensions = String::utf8(info.valid_extensions ? info.valid_extensions : "");

	UtilityFunctions::print("RetroHost: loaded core ", core_name, " ", core_version);
	return true;
}

void RetroHost::unload_core() {
	unload_game();
	if (core_initialized && core.deinit) {
		core.deinit();
	}
	core_initialized = false;
	if (lib_handle) {
		redox::dynlib_close(lib_handle);
		lib_handle = nullptr;
	}
	core = CoreApi();
	if (s_active == this) {
		s_active = nullptr;
	}
	core_name = String();
	core_version = String();
	valid_extensions = String();
}

bool RetroHost::load_game(const String &p_path) {
	if (!lib_handle) {
		UtilityFunctions::push_error("RetroHost: load a core before loading a game.");
		return false;
	}
	unload_game();

	retro_system_info info{};
	core.get_system_info(&info);

	game_path_utf8 = to_global(p_path).utf8().get_data();
	retro_game_info game{};
	game.path = game_path_utf8.c_str();

	if (!info.need_fullpath) {
		PackedByteArray bytes = FileAccess::get_file_as_bytes(p_path);
		if (bytes.is_empty()) {
			UtilityFunctions::push_error("RetroHost: could not read game file ", p_path);
			return false;
		}
		rom_data.assign(bytes.ptr(), bytes.ptr() + bytes.size());
		game.data = rom_data.data();
		game.size = rom_data.size();
	}

	if (!core.load_game(&game)) {
		UtilityFunctions::push_error("RetroHost: core refused the game ", p_path);
		rom_data.clear();
		return false;
	}

	game_loaded = true;
	game_path = p_path;
	core.get_system_av_info(&av_info);
	core.set_controller_port_device(0, RETRO_DEVICE_JOYPAD);
	core.set_controller_port_device(1, RETRO_DEVICE_JOYPAD);

	frame_w = int(av_info.geometry.base_width);
	frame_h = int(av_info.geometry.base_height);
	time_accumulator = 0.0;
	paused = false;
	speed = 1.0;
	rewinding = false;
	rewind_clear();
	clear_input();
	load_sram();
	set_process(true);

	UtilityFunctions::print("RetroHost: game loaded ", p_path, " (", frame_w, "x", frame_h, " @ ", av_info.timing.fps, " fps, ",
			av_info.timing.sample_rate, " Hz)");
	return true;
}

void RetroHost::unload_game() {
	if (!game_loaded) {
		return;
	}
	write_sram();
	if (ra) {
		ra->unload_game();
	}
	core.unload_game();
	game_loaded = false;
	rewind_clear();
	rom_data.clear();
	audio_buffer.clear();
	audio_buffer_frames = 0;
	set_process(false);
}

void RetroHost::reset() {
	if (game_loaded) {
		core.reset();
		if (ra) {
			ra->on_reset();
		}
	}
}

// ------------------------------------------------------------------ running

void RetroHost::_process(double p_delta) {
	if (!game_loaded) {
		return;
	}
	if (paused) {
		if (ra) {
			ra->idle(); // keeps the achievement session alive while paused
		}
		return;
	}
	const double fps = av_info.timing.fps > 1.0 ? av_info.timing.fps : 60.0;
	const double frame_time = 1.0 / fps;
	const double rate = rewinding ? 1.0 : speed;
	const int max_frames = 4 * int(rate + 0.999);

	time_accumulator += p_delta * rate;
	int frames = 0;
	while (time_accumulator >= frame_time && frames < max_frames) {
		if (rewinding) {
			// step back one recorded state, then run a silent frame to show it
			if (rewind_pop()) {
				mute_frame = true;
				step_frame();
				mute_frame = false;
			}
		} else {
			// fast forward: keep the sound of only one frame per tick
			mute_frame = speed > 1.0 && frames > 0;
			step_frame();
			mute_frame = false;
			if (rewind_enabled && ++rewind_counter >= 2) {
				rewind_counter = 0;
				rewind_push();
			}
		}
		time_accumulator -= frame_time;
		frames++;
	}
	// After a long stall (loading, window drag) don't try to catch up.
	if (time_accumulator > frame_time * 4.0) {
		time_accumulator = 0.0;
	}
}

void RetroHost::step_frame() {
	if (!game_loaded) {
		return;
	}
	audio_buffer_frames = 0;
	if (frame_time_cb.callback) {
		// emulated time: one frame at the core's own rate, whatever the real speed
		retro_usec_t usec = frame_time_cb.reference;
		if (usec <= 0 && av_info.timing.fps > 0.0) {
			usec = static_cast<retro_usec_t>(1000000.0 / av_info.timing.fps);
		}
		frame_time_cb.callback(usec);
	}
	core.run();
	if (ra) {
		ra->do_frame();
	}
	if (mute_frame) {
		last_audio_frames = audio_buffer_frames;
		audio_buffer_frames = 0;
	} else {
		flush_audio();
	}
}

// ------------------------------------------------------------------ rewind
//
// Only the newest state is kept whole. Each older one is stored as the XOR
// with its successor, run-length coded: consecutive emulator states differ in
// a few hundred bytes, so a delta is usually tiny.
//   delta format: repeated [u32 equal_run][u32 literal_len][literal xor bytes]

namespace {

void rle_xor_encode(const std::vector<uint8_t> &a, const std::vector<uint8_t> &b, std::vector<uint8_t> &out) {
	out.clear();
	const size_t n = a.size();
	auto put32 = [&out](uint32_t v) {
		for (int k = 0; k < 4; k++) {
			out.push_back(uint8_t(v >> (k * 8)));
		}
	};
	size_t i = 0;
	while (i < n) {
		size_t z = i;
		while (z < n && a[z] == b[z]) {
			z++;
		}
		if (z == n) {
			break; // trailing equal bytes need no record
		}
		// literal run: until 8 equal bytes in a row (or the end)
		size_t l = z;
		size_t same = 0;
		while (l < n) {
			if (a[l] == b[l]) {
				same++;
				if (same >= 8) {
					l = l + 1 - same;
					break;
				}
			} else {
				same = 0;
			}
			l++;
		}
		if (l >= n) {
			l = n;
		}
		put32(uint32_t(z - i));
		put32(uint32_t(l - z));
		for (size_t k = z; k < l; k++) {
			out.push_back(uint8_t(a[k] ^ b[k]));
		}
		i = l;
	}
}

void rle_xor_apply(const std::vector<uint8_t> &delta, std::vector<uint8_t> &state) {
	size_t p = 0, i = 0;
	auto get32 = [&delta, &p]() {
		uint32_t v = 0;
		for (int k = 0; k < 4; k++) {
			v |= uint32_t(delta[p++]) << (k * 8);
		}
		return v;
	};
	while (p + 8 <= delta.size()) {
		i += get32();
		const uint32_t len = get32();
		for (uint32_t k = 0; k < len && i < state.size() && p < delta.size(); k++) {
			state[i++] ^= delta[p++];
		}
	}
}

} // namespace

// Some cores write (VecX) or read past the size they report for a save state.
// Every state buffer handed to a core gets this much spare room.
static constexpr size_t STATE_SLACK = 4096;

void RetroHost::set_rewind_enabled(bool p_enabled) {
	rewind_enabled = p_enabled;
	if (!p_enabled) {
		rewind_clear();
	}
}

void RetroHost::rewind_clear() {
	rewind_current.clear();
	rewind_deltas.clear();
	rewind_bytes = 0;
	rewind_counter = 0;
}

void RetroHost::rewind_push() {
	const size_t size = core.serialize_size();
	if (size == 0) {
		return;
	}
	std::vector<uint8_t> next(size + STATE_SLACK);
	if (!core.serialize(next.data(), size)) {
		return;
	}
	next.resize(size);
	if (rewind_current.size() != size) {
		rewind_clear();
		rewind_current.swap(next);
		return;
	}
	std::vector<uint8_t> delta;
	rle_xor_encode(rewind_current, next, delta);
	rewind_bytes += delta.size();
	rewind_deltas.push_back(std::move(delta));
	rewind_current.swap(next);
	while (rewind_bytes > rewind_budget && !rewind_deltas.empty()) {
		rewind_bytes -= rewind_deltas.front().size();
		rewind_deltas.pop_front();
	}
}

bool RetroHost::rewind_pop() {
	if (rewind_current.empty()) {
		return false;
	}
	if (!rewind_deltas.empty()) {
		rle_xor_apply(rewind_deltas.back(), rewind_current);
		rewind_bytes -= rewind_deltas.back().size();
		rewind_deltas.pop_back();
	}
	// at the oldest state we keep showing it
	const size_t size = rewind_current.size();
	rewind_current.resize(size + STATE_SLACK);
	const bool ok = core.unserialize(rewind_current.data(), size);
	rewind_current.resize(size);
	return ok;
}

// ------------------------------------------------------------------ cheats

void RetroHost::cheat_reset() {
	if (game_loaded && core.cheat_reset) {
		core.cheat_reset();
	}
}

void RetroHost::cheat_set(int p_index, bool p_enabled, const String &p_code) {
	if (game_loaded && core.cheat_set) {
		core.cheat_set(unsigned(p_index), p_enabled, p_code.utf8().get_data());
	}
}

PackedByteArray RetroHost::get_memory(int p_id) const {
	PackedByteArray out;
	if (!game_loaded) {
		return out;
	}
	void *mem = core.get_memory_data(unsigned(p_id));
	const size_t size = core.get_memory_size(unsigned(p_id));
	if (mem && size) {
		out.resize(int64_t(size));
		memcpy(out.ptrw(), mem, size);
	}
	return out;
}

// ------------------------------------------------------------------- input

void RetroHost::set_button(int p_port, int p_id, bool p_pressed) {
	if (p_port < 0 || p_port > 3 || p_id < 0 || p_id > 15) {
		return;
	}
	const uint16_t bit = uint16_t(1u << p_id);
	if (p_pressed) {
		input_mask[p_port] |= bit;
	} else {
		input_mask[p_port] &= uint16_t(~bit);
	}
}

void RetroHost::clear_input() {
	for (uint16_t &m : input_mask) {
		m = 0;
	}
	pointer_pressed = false;
}

void RetroHost::set_pointer(double p_x, double p_y, bool p_pressed) {
	auto to_retro = [](double v) {
		const double c = v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v);
		return int16_t(c * 0xFFFE - 0x7FFF);
	};
	pointer_x = to_retro(p_x);
	pointer_y = to_retro(p_y);
	pointer_pressed = p_pressed;
}

int16_t RetroHost::on_input_state(unsigned p_port, unsigned p_device, unsigned p_index, unsigned p_id) {
	const unsigned device = p_device & RETRO_DEVICE_MASK;
	if (device == RETRO_DEVICE_POINTER) {
		if (p_port != 0 || p_index != 0) {
			return 0;
		}
		switch (p_id) {
			case RETRO_DEVICE_ID_POINTER_X: return pointer_x;
			case RETRO_DEVICE_ID_POINTER_Y: return pointer_y;
			case RETRO_DEVICE_ID_POINTER_PRESSED: return pointer_pressed ? 1 : 0;
			case RETRO_DEVICE_ID_POINTER_COUNT: return pointer_pressed ? 1 : 0;
			default: return 0;
		}
	}
	if (p_port > 3 || device != RETRO_DEVICE_JOYPAD) {
		return 0;
	}
	if (p_id == RETRO_DEVICE_ID_JOYPAD_MASK) {
		return int16_t(input_mask[p_port]);
	}
	if (p_id > 15) {
		return 0;
	}
	return (input_mask[p_port] >> p_id) & 1;
}

// ------------------------------------------------------------------- video

double RetroHost::get_aspect_ratio() const {
	if (av_info.geometry.aspect_ratio > 0.0f) {
		return av_info.geometry.aspect_ratio;
	}
	return frame_h > 0 ? double(frame_w) / double(frame_h) : 4.0 / 3.0;
}

void RetroHost::on_video(const void *p_data, unsigned p_width, unsigned p_height, size_t p_pitch) {
	if (!p_data || p_data == RETRO_HW_FRAME_BUFFER_VALID || p_width == 0 || p_height == 0) {
		return; // duplicated frame: keep the previous picture
	}

	const int w = int(p_width);
	const int h = int(p_height);
	const int64_t needed = int64_t(w) * h * 4;
	if (frame_rgba.size() != needed) {
		frame_rgba.resize(needed);
	}
	uint8_t *dst = frame_rgba.ptrw();
	const uint8_t *src = static_cast<const uint8_t *>(p_data);

	// Some cores (VecX without a GL context) ask for XRGB8888, are told yes,
	// then fall back to a 16-bit RGB565 software frame. Trust the pitch: a row
	// too short for 4 bytes per pixel cannot be XRGB8888.
	retro_pixel_format fmt = pixel_format;
	if (fmt == RETRO_PIXEL_FORMAT_XRGB8888 && p_pitch < size_t(w) * 4) {
		fmt = RETRO_PIXEL_FORMAT_RGB565;
	}

	for (int y = 0; y < h; y++) {
		const uint8_t *row = src + size_t(y) * p_pitch;
		uint8_t *out = dst + size_t(y) * w * 4;
		switch (fmt) {
			case RETRO_PIXEL_FORMAT_XRGB8888: {
				const uint32_t *px = reinterpret_cast<const uint32_t *>(row);
				for (int x = 0; x < w; x++) {
					const uint32_t c = px[x];
					out[x * 4 + 0] = uint8_t(c >> 16);
					out[x * 4 + 1] = uint8_t(c >> 8);
					out[x * 4 + 2] = uint8_t(c);
					out[x * 4 + 3] = 255;
				}
			} break;
			case RETRO_PIXEL_FORMAT_RGB565: {
				const uint16_t *px = reinterpret_cast<const uint16_t *>(row);
				for (int x = 0; x < w; x++) {
					const uint16_t c = px[x];
					const uint8_t r = (c >> 11) & 0x1F, g = (c >> 5) & 0x3F, b = c & 0x1F;
					out[x * 4 + 0] = uint8_t((r << 3) | (r >> 2));
					out[x * 4 + 1] = uint8_t((g << 2) | (g >> 4));
					out[x * 4 + 2] = uint8_t((b << 3) | (b >> 2));
					out[x * 4 + 3] = 255;
				}
			} break;
			default: { // 0RGB1555
				const uint16_t *px = reinterpret_cast<const uint16_t *>(row);
				for (int x = 0; x < w; x++) {
					const uint16_t c = px[x];
					const uint8_t r = (c >> 10) & 0x1F, g = (c >> 5) & 0x1F, b = c & 0x1F;
					out[x * 4 + 0] = uint8_t((r << 3) | (r >> 2));
					out[x * 4 + 1] = uint8_t((g << 3) | (g >> 2));
					out[x * 4 + 2] = uint8_t((b << 3) | (b >> 2));
					out[x * 4 + 3] = 255;
				}
			} break;
		}
	}

	const bool size_changed = (w != frame_w || h != frame_h || frame_image->is_empty());
	frame_image->set_data(w, h, false, Image::FORMAT_RGBA8, frame_rgba);
	if (size_changed || texture->get_width() != w || texture->get_height() != h) {
		texture->set_image(frame_image);
		frame_w = w;
		frame_h = h;
		emit_signal("video_size_changed", Vector2i(w, h));
	} else {
		texture->update(frame_image);
	}
}

// ------------------------------------------------------------------- audio

void RetroHost::on_audio(const int16_t *p_data, size_t p_frames) {
	const int64_t start = audio_buffer_frames;
	const int64_t needed = start + int64_t(p_frames);
	if (audio_buffer.size() < needed) {
		audio_buffer.resize(needed);
	}
	Vector2 *out = audio_buffer.ptrw();
	constexpr float k = 1.0f / 32768.0f;
	for (size_t i = 0; i < p_frames; i++) {
		out[start + i] = Vector2(p_data[i * 2] * k, p_data[i * 2 + 1] * k);
	}
	audio_buffer_frames = int(needed);
}

void RetroHost::flush_audio() {
	last_audio_frames = audio_buffer_frames;
	if (audio_buffer_frames == 0 || audio_playback.is_null()) {
		return;
	}
	int count = audio_buffer_frames;
	const int available = audio_playback->get_frames_available();
	if (available <= 0) {
		return; // buffer is full: drop this frame's sound rather than block
	}
	if (count > available) {
		count = available;
	}
	if (count == audio_buffer.size()) {
		audio_playback->push_buffer(audio_buffer);
	} else {
		audio_playback->push_buffer(audio_buffer.slice(0, count));
	}
}

// ------------------------------------------------------------- environment

bool RetroHost::on_environment(unsigned p_cmd, void *p_data) {
	switch (p_cmd) {
		case RETRO_ENVIRONMENT_GET_LOG_INTERFACE: {
			static_cast<retro_log_callback *>(p_data)->log = cb_log;
			return true;
		}
		case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
			const retro_pixel_format fmt = *static_cast<const retro_pixel_format *>(p_data);
			if (fmt == RETRO_PIXEL_FORMAT_XRGB8888 || fmt == RETRO_PIXEL_FORMAT_RGB565 || fmt == RETRO_PIXEL_FORMAT_0RGB1555) {
				pixel_format = fmt;
				return true;
			}
			return false;
		}
		case RETRO_ENVIRONMENT_GET_CAN_DUPE: {
			*static_cast<bool *>(p_data) = true;
			return true;
		}
		case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY: {
			*static_cast<const char **>(p_data) = system_dir_utf8.empty() ? nullptr : system_dir_utf8.c_str();
			return !system_dir_utf8.empty();
		}
		case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY: {
			*static_cast<const char **>(p_data) = save_dir_utf8.empty() ? nullptr : save_dir_utf8.c_str();
			return !save_dir_utf8.empty();
		}
		case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS: {
			return true;
		}
		case RETRO_ENVIRONMENT_SET_VARIABLES: {
			// Legacy options: "key" -> "Description; default|other|..."
			const retro_variable *vars = static_cast<const retro_variable *>(p_data);
			for (; vars && vars->key; vars++) {
				std::string value = vars->value ? vars->value : "";
				size_t semi = value.find("; ");
				std::string choices = semi == std::string::npos ? value : value.substr(semi + 2);
				size_t bar = choices.find('|');
				if (variables.find(vars->key) == variables.end()) {
					variables[vars->key] = bar == std::string::npos ? choices : choices.substr(0, bar);
				}
			}
			return true;
		}
		case RETRO_ENVIRONMENT_GET_VARIABLE: {
			retro_variable *var = static_cast<retro_variable *>(p_data);
			if (!var || !var->key) {
				return false;
			}
			auto it = variables.find(var->key);
			if (it == variables.end()) {
				var->value = nullptr;
				return false;
			}
			var->value = it->second.c_str();
			return true;
		}
		case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE: {
			*static_cast<bool *>(p_data) = false;
			return true;
		}
		case RETRO_ENVIRONMENT_SET_GEOMETRY: {
			av_info.geometry = *static_cast<const retro_game_geometry *>(p_data);
			return true;
		}
		case RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO: {
			av_info = *static_cast<const retro_system_av_info *>(p_data);
			return true;
		}
		case RETRO_ENVIRONMENT_SET_MEMORY_MAPS: {
			// kept for achievements: where the console's RAM lives in the core
			const retro_memory_map *m = static_cast<const retro_memory_map *>(p_data);
			if (m && m->descriptors && m->num_descriptors) {
				mmap_descriptors.assign(m->descriptors, m->descriptors + m->num_descriptors);
				mmap.descriptors = mmap_descriptors.data();
				mmap.num_descriptors = unsigned(mmap_descriptors.size());
				has_mmap = true;
			}
			return true;
		}
		case RETRO_ENVIRONMENT_SET_FRAME_TIME_CALLBACK: {
			frame_time_cb = *static_cast<const retro_frame_time_callback *>(p_data);
			return true;
		}
		case RETRO_ENVIRONMENT_GET_INPUT_DEVICE_CAPABILITIES: {
			// joypad, and a touch screen / mouse pointer (Nintendo DS)
			*static_cast<uint64_t *>(p_data) = (1ull << RETRO_DEVICE_JOYPAD) | (1ull << RETRO_DEVICE_POINTER);
			return true;
		}
		case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
		case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
		case RETRO_ENVIRONMENT_SET_SUPPORT_ACHIEVEMENTS:
		case RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL:
			return true;
		default:
			return false;
	}
}

// ------------------------------------------------------------ directories

void RetroHost::set_system_directory(const String &p_dir) {
	system_dir = p_dir;
	system_dir_utf8 = to_global(p_dir).utf8().get_data();
	if (!p_dir.is_empty()) {
		DirAccess::make_dir_recursive_absolute(to_global(p_dir));
	}
}

void RetroHost::set_save_directory(const String &p_dir) {
	save_dir = p_dir;
	save_dir_utf8 = to_global(p_dir).utf8().get_data();
	if (!p_dir.is_empty()) {
		DirAccess::make_dir_recursive_absolute(to_global(p_dir));
	}
}

String RetroHost::sram_path() const {
	if (save_dir.is_empty() || game_path.is_empty()) {
		return String();
	}
	return save_dir.path_join(game_path.get_file().get_basename() + ".srm");
}

void RetroHost::load_sram() {
	const String path = sram_path();
	if (path.is_empty() || !FileAccess::file_exists(path)) {
		return;
	}
	void *mem = core.get_memory_data(RETRO_MEMORY_SAVE_RAM);
	const size_t size = core.get_memory_size(RETRO_MEMORY_SAVE_RAM);
	if (!mem || size == 0) {
		return;
	}
	PackedByteArray bytes = FileAccess::get_file_as_bytes(path);
	const size_t n = size < size_t(bytes.size()) ? size : size_t(bytes.size());
	memcpy(mem, bytes.ptr(), n);
}

void RetroHost::write_sram() {
	const String path = sram_path();
	if (path.is_empty()) {
		return;
	}
	void *mem = core.get_memory_data(RETRO_MEMORY_SAVE_RAM);
	const size_t size = core.get_memory_size(RETRO_MEMORY_SAVE_RAM);
	if (!mem || size == 0) {
		return;
	}
	Ref<FileAccess> f = FileAccess::open(path, FileAccess::WRITE);
	if (f.is_null()) {
		UtilityFunctions::push_error("RetroHost: could not write save file ", path);
		return;
	}
	PackedByteArray bytes;
	bytes.resize(int64_t(size));
	memcpy(bytes.ptrw(), mem, size);
	f->store_buffer(bytes);
}

// -------------------------------------------------------------- save states

PackedByteArray RetroHost::save_state() {
	PackedByteArray out;
	if (!game_loaded) {
		return out;
	}
	const size_t size = core.serialize_size();
	if (size == 0) {
		return out;
	}
	out.resize(int64_t(size + STATE_SLACK));
	if (!core.serialize(out.ptrw(), size)) {
		out.clear();
		return out;
	}
	out.resize(int64_t(size));
	return out;
}

bool RetroHost::load_state(const PackedByteArray &p_data) {
	if (!game_loaded || p_data.is_empty()) {
		return false;
	}
	PackedByteArray padded = p_data;
	padded.resize(p_data.size() + int64_t(STATE_SLACK));
	const bool ok = core.unserialize(padded.ptr(), size_t(p_data.size()));
	if (ok && ra) {
		ra->on_state_loaded();
	}
	return ok;
}

Dictionary RetroHost::get_core_info() const {
	Dictionary d;
	d["name"] = core_name;
	d["version"] = core_version;
	d["extensions"] = valid_extensions;
	d["path"] = core_path;
	d["game"] = game_path;
	d["fps"] = av_info.timing.fps;
	d["sample_rate"] = av_info.timing.sample_rate;
	d["aspect_ratio"] = get_aspect_ratio();
	return d;
}

// ----------------------------------------------------------------- binding

void RetroHost::_bind_methods() {
	ClassDB::bind_method(D_METHOD("load_core", "path"), &RetroHost::load_core);
	ClassDB::bind_method(D_METHOD("unload_core"), &RetroHost::unload_core);
	ClassDB::bind_method(D_METHOD("is_core_loaded"), &RetroHost::is_core_loaded);
	ClassDB::bind_method(D_METHOD("load_game", "path"), &RetroHost::load_game);
	ClassDB::bind_method(D_METHOD("unload_game"), &RetroHost::unload_game);
	ClassDB::bind_method(D_METHOD("is_game_loaded"), &RetroHost::is_game_loaded);
	ClassDB::bind_method(D_METHOD("reset"), &RetroHost::reset);

	ClassDB::bind_method(D_METHOD("set_paused", "paused"), &RetroHost::set_paused);
	ClassDB::bind_method(D_METHOD("is_paused"), &RetroHost::is_paused);
	ClassDB::bind_method(D_METHOD("step_frame"), &RetroHost::step_frame);
	ClassDB::bind_method(D_METHOD("set_speed", "speed"), &RetroHost::set_speed);
	ClassDB::bind_method(D_METHOD("get_speed"), &RetroHost::get_speed);
	ClassDB::bind_method(D_METHOD("set_rewind_enabled", "enabled"), &RetroHost::set_rewind_enabled);
	ClassDB::bind_method(D_METHOD("is_rewind_enabled"), &RetroHost::is_rewind_enabled);
	ClassDB::bind_method(D_METHOD("set_rewind_budget_mb", "mb"), &RetroHost::set_rewind_budget_mb);
	ClassDB::bind_method(D_METHOD("set_rewinding", "rewinding"), &RetroHost::set_rewinding);
	ClassDB::bind_method(D_METHOD("is_rewinding"), &RetroHost::is_rewinding);
	ClassDB::bind_method(D_METHOD("get_rewind_depth"), &RetroHost::get_rewind_depth);
	ClassDB::bind_method(D_METHOD("cheat_reset"), &RetroHost::cheat_reset);
	ClassDB::bind_method(D_METHOD("cheat_set", "index", "enabled", "code"), &RetroHost::cheat_set);
	ClassDB::bind_method(D_METHOD("get_memory", "id"), &RetroHost::get_memory);

	ClassDB::bind_method(D_METHOD("set_button", "port", "id", "pressed"), &RetroHost::set_button);
	ClassDB::bind_method(D_METHOD("set_pointer", "x", "y", "pressed"), &RetroHost::set_pointer);
	ClassDB::bind_method(D_METHOD("clear_input"), &RetroHost::clear_input);

	ClassDB::bind_method(D_METHOD("get_texture"), &RetroHost::get_texture);
	ClassDB::bind_method(D_METHOD("get_frame_image"), &RetroHost::get_frame_image);
	ClassDB::bind_method(D_METHOD("get_frame_size"), &RetroHost::get_frame_size);
	ClassDB::bind_method(D_METHOD("get_aspect_ratio"), &RetroHost::get_aspect_ratio);
	ClassDB::bind_method(D_METHOD("get_fps"), &RetroHost::get_fps);
	ClassDB::bind_method(D_METHOD("get_sample_rate"), &RetroHost::get_sample_rate);
	ClassDB::bind_method(D_METHOD("set_audio_playback", "playback"), &RetroHost::set_audio_playback);
	ClassDB::bind_method(D_METHOD("get_last_audio_frames"), &RetroHost::get_last_audio_frames);

	ClassDB::bind_method(D_METHOD("set_system_directory", "dir"), &RetroHost::set_system_directory);
	ClassDB::bind_method(D_METHOD("get_system_directory"), &RetroHost::get_system_directory);
	ClassDB::bind_method(D_METHOD("set_save_directory", "dir"), &RetroHost::set_save_directory);
	ClassDB::bind_method(D_METHOD("get_save_directory"), &RetroHost::get_save_directory);
	ClassDB::bind_method(D_METHOD("get_core_info"), &RetroHost::get_core_info);

	ClassDB::bind_method(D_METHOD("save_state"), &RetroHost::save_state);
	ClassDB::bind_method(D_METHOD("load_state", "data"), &RetroHost::load_state);

	ADD_SIGNAL(MethodInfo("video_size_changed", PropertyInfo(Variant::VECTOR2I, "size")));
}
