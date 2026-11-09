#pragma once

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include <map>

extern "C" {
#include "rc_client.h"
#include "rc_libretro.h"
}

namespace godot {

class RetroHost;

// RetroAchievements through rcheevos' rc_client. One instance lives for the
// whole app (Achievements autoload). HTTP is done by Godot: rc_client asks
// for a request -> signal http_request(id, ...) -> GDScript downloads ->
// http_response(id, ...). Memory is read from the attached RetroHost's core.
class RAClient : public Node {
	GDCLASS(RAClient, Node)

public:
	RAClient();
	~RAClient();

	void set_hardcore(bool p_enabled);
	bool is_hardcore() const;

	void login_with_password(const String &p_user, const String &p_password);
	void login_with_token(const String &p_user, const String &p_token);
	void logout();
	bool is_logged_in() const;
	Dictionary get_user() const;

	// p_host: the RetroHost that has the game loaded. console_id: RC_CONSOLE_*
	void load_game(Object *p_host, const String &p_path, int p_console_id);
	void unload_game();
	bool is_game_loaded() const;
	Dictionary get_game() const;
	Array get_achievements();
	String get_rich_presence();

	void http_response(int p_id, int p_status, const PackedByteArray &p_body);

	// Called by RetroHost
	void do_frame();
	void idle();
	void on_reset();
	void on_state_loaded();
	uint32_t read_memory(uint32_t p_address, uint8_t *p_buffer, uint32_t p_bytes);

	// Called from the static rc_client callbacks
	void server_call(const rc_api_request_t *p_request, rc_client_server_callback_t p_callback, void *p_data);
	void on_event(const rc_client_event_t *p_event);
	void finish_login(int p_result, const char *p_error);
	void finish_load(int p_result, const char *p_error);

protected:
	static void _bind_methods();

private:
	struct Pending {
		rc_client_server_callback_t callback = nullptr;
		void *data = nullptr;
	};

	rc_client_t *client = nullptr;
	RetroHost *host = nullptr;
	rc_libretro_memory_regions_t regions{};
	bool regions_ready = false;
	std::map<int, Pending> pending;
	int next_id = 1;

	void init_regions(int p_console_id);
	static Dictionary achievement_dict(const rc_client_achievement_t *p_a);
};

} // namespace godot
