#pragma once

#include <godot_cpp/classes/audio_stream_generator_playback.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

#include <cstdint>
#include <deque>
#include <map>
#include <string>
#include <vector>

#include "libretro.h"

namespace godot {

class RAClient;

// RetroHost loads one libretro core and one game, runs it at the core's
// frame rate inside _process, and exposes the picture as an ImageTexture and
// the sound through an AudioStreamGeneratorPlayback.
class RetroHost : public Node {
	GDCLASS(RetroHost, Node)

public:
	RetroHost();
	~RetroHost();

	// Core and game lifecycle
	bool load_core(const String &p_path);
	void unload_core();
	bool is_core_loaded() const { return lib_handle != nullptr; }
	bool load_game(const String &p_path);
	void unload_game();
	bool is_game_loaded() const { return game_loaded; }
	void reset();

	// Running
	void set_paused(bool p_paused) { paused = p_paused; }
	bool is_paused() const { return paused; }
	void step_frame();
	void set_speed(double p_speed) { speed = p_speed < 0.25 ? 0.25 : (p_speed > 8.0 ? 8.0 : p_speed); }
	double get_speed() const { return speed; }

	// Rewind: a ring of compressed save states, recorded while the game runs.
	void set_rewind_enabled(bool p_enabled);
	bool is_rewind_enabled() const { return rewind_enabled; }
	void set_rewind_budget_mb(int p_mb) { rewind_budget = size_t(p_mb < 4 ? 4 : p_mb) * 1024 * 1024; }
	void set_rewinding(bool p_rewinding) { rewinding = p_rewinding; }
	bool is_rewinding() const { return rewinding; }
	int get_rewind_depth() const { return int(rewind_deltas.size()); }

	// Cheats (Game Genie, Action Replay, raw codes - whatever the core accepts)
	void cheat_reset();
	void cheat_set(int p_index, bool p_enabled, const String &p_code);

	// Raw memory for achievements / tools (RETRO_MEMORY_*)
	PackedByteArray get_memory(int p_id) const;

	// Used by RAClient (C++ only)
	void set_achievements_client(RAClient *p_client) { ra = p_client; }
	const retro_memory_map *get_memory_map() const { return has_mmap ? &mmap : nullptr; }
	void *core_memory_data(unsigned p_id) const { return game_loaded && core.get_memory_data ? core.get_memory_data(p_id) : nullptr; }
	size_t core_memory_size(unsigned p_id) const { return game_loaded && core.get_memory_size ? core.get_memory_size(p_id) : 0; }
	const std::vector<uint8_t> &rom_bytes() const { return rom_data; }

	// Input: libretro joypad ids (RETRO_DEVICE_ID_JOYPAD_*) for ports 0..3
	void set_button(int p_port, int p_id, bool p_pressed);
	void clear_input();

	// Video / audio
	Ref<ImageTexture> get_texture() const { return texture; }
	Ref<Image> get_frame_image() const { return frame_image; }
	Vector2i get_frame_size() const { return Vector2i(frame_w, frame_h); }
	double get_aspect_ratio() const;
	double get_fps() const { return av_info.timing.fps; }
	double get_sample_rate() const { return av_info.timing.sample_rate; }
	void set_audio_playback(const Ref<AudioStreamGeneratorPlayback> &p_playback) { audio_playback = p_playback; }
	int get_last_audio_frames() const { return last_audio_frames; }

	// Folders the core may use (BIOS files, battery saves)
	void set_system_directory(const String &p_dir);
	String get_system_directory() const { return system_dir; }
	void set_save_directory(const String &p_dir);
	String get_save_directory() const { return save_dir; }

	Dictionary get_core_info() const;

	// Save states
	PackedByteArray save_state();
	bool load_state(const PackedByteArray &p_data);

	void _process(double p_delta) override;

	// Called from the static libretro callbacks
	bool on_environment(unsigned p_cmd, void *p_data);
	void on_video(const void *p_data, unsigned p_width, unsigned p_height, size_t p_pitch);
	void on_audio(const int16_t *p_data, size_t p_frames);
	int16_t on_input_state(unsigned p_port, unsigned p_device, unsigned p_index, unsigned p_id);

protected:
	static void _bind_methods();

private:
	struct CoreApi {
		void (*init)(void) = nullptr;
		void (*deinit)(void) = nullptr;
		unsigned (*api_version)(void) = nullptr;
		void (*get_system_info)(retro_system_info *) = nullptr;
		void (*get_system_av_info)(retro_system_av_info *) = nullptr;
		void (*set_environment)(retro_environment_t) = nullptr;
		void (*set_video_refresh)(retro_video_refresh_t) = nullptr;
		void (*set_audio_sample)(retro_audio_sample_t) = nullptr;
		void (*set_audio_sample_batch)(retro_audio_sample_batch_t) = nullptr;
		void (*set_input_poll)(retro_input_poll_t) = nullptr;
		void (*set_input_state)(retro_input_state_t) = nullptr;
		void (*set_controller_port_device)(unsigned, unsigned) = nullptr;
		void (*reset)(void) = nullptr;
		void (*run)(void) = nullptr;
		size_t (*serialize_size)(void) = nullptr;
		bool (*serialize)(void *, size_t) = nullptr;
		bool (*unserialize)(const void *, size_t) = nullptr;
		bool (*load_game)(const retro_game_info *) = nullptr;
		void (*unload_game)(void) = nullptr;
		void *(*get_memory_data)(unsigned) = nullptr;
		size_t (*get_memory_size)(unsigned) = nullptr;
		void (*cheat_reset)(void) = nullptr;
		void (*cheat_set)(unsigned, bool, const char *) = nullptr;
	};

	void rewind_push();
	bool rewind_pop();
	void rewind_clear();

	void flush_audio();
	void load_sram();
	void write_sram();
	String sram_path() const;

	CoreApi core;
	void *lib_handle = nullptr;
	bool core_initialized = false;
	bool game_loaded = false;
	bool paused = false;

	String core_path;
	String game_path;
	String core_name;
	String core_version;
	String valid_extensions;
	std::vector<uint8_t> rom_data;
	std::string game_path_utf8;

	String system_dir;
	String save_dir;
	std::string system_dir_utf8;
	std::string save_dir_utf8;

	std::map<std::string, std::string> variables;

	retro_system_av_info av_info{};
	retro_pixel_format pixel_format = RETRO_PIXEL_FORMAT_0RGB1555;

	Ref<Image> frame_image;
	Ref<ImageTexture> texture;
	PackedByteArray frame_rgba;
	int frame_w = 0;
	int frame_h = 0;

	Ref<AudioStreamGeneratorPlayback> audio_playback;
	PackedVector2Array audio_buffer;
	int audio_buffer_frames = 0;
	int last_audio_frames = 0;

	uint16_t input_mask[4] = { 0, 0, 0, 0 };

	double time_accumulator = 0.0;
	double speed = 1.0;

	bool rewind_enabled = false;
	bool rewinding = false;
	size_t rewind_budget = 48 * 1024 * 1024;
	size_t rewind_bytes = 0;
	int rewind_counter = 0;
	std::vector<uint8_t> rewind_current;            // newest full state
	std::deque<std::vector<uint8_t>> rewind_deltas; // XOR(older, newer), run-length coded
	bool mute_frame = false;

	RAClient *ra = nullptr;
	std::vector<retro_memory_descriptor> mmap_descriptors;
	retro_memory_map mmap{};
	bool has_mmap = false;
};

} // namespace godot
