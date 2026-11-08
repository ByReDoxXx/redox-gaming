#include "retro_host.h"

#include "dynlib.h"

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
	core.unload_game();
	game_loaded = false;
	rom_data.clear();
	audio_buffer.clear();
	audio_buffer_frames = 0;
	set_process(false);
}

void RetroHost::reset() {
	if (game_loaded) {
		core.reset();
	}
}

// ------------------------------------------------------------------ running

void RetroHost::_process(double p_delta) {
	if (!game_loaded || paused) {
		return;
	}
	const double fps = av_info.timing.fps > 1.0 ? av_info.timing.fps : 60.0;
	const double frame_time = 1.0 / fps;

	time_accumulator += p_delta;
	int frames = 0;
	while (time_accumulator >= frame_time && frames < 4) {
		step_frame();
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
	core.run();
	flush_audio();
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
}

int16_t RetroHost::on_input_state(unsigned p_port, unsigned p_device, unsigned p_index, unsigned p_id) {
	if (p_port > 3 || (p_device & RETRO_DEVICE_MASK) != RETRO_DEVICE_JOYPAD) {
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

	for (int y = 0; y < h; y++) {
		const uint8_t *row = src + size_t(y) * p_pitch;
		uint8_t *out = dst + size_t(y) * w * 4;
		switch (pixel_format) {
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
	out.resize(int64_t(size));
	if (!core.serialize(out.ptrw(), size)) {
		out.clear();
	}
	return out;
}

bool RetroHost::load_state(const PackedByteArray &p_data) {
	if (!game_loaded || p_data.is_empty()) {
		return false;
	}
	return core.unserialize(p_data.ptr(), size_t(p_data.size()));
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

	ClassDB::bind_method(D_METHOD("set_button", "port", "id", "pressed"), &RetroHost::set_button);
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
