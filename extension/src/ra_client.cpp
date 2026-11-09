#include "ra_client.h"

#include "retro_host.h"

#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cstring>

using namespace godot;

namespace {

// rc_libretro asks for the core's memory blocks through a plain function.
RetroHost *s_memory_host = nullptr;

void RC_CCONV cb_core_memory_info(uint32_t p_id, rc_libretro_core_memory_info_t *p_info) {
	p_info->data = nullptr;
	p_info->size = 0;
	if (s_memory_host) {
		p_info->data = static_cast<uint8_t *>(s_memory_host->core_memory_data(p_id));
		p_info->size = s_memory_host->core_memory_size(p_id);
	}
}

RAClient *self_of(const rc_client_t *p_client) {
	return static_cast<RAClient *>(rc_client_get_userdata(p_client));
}

uint32_t RC_CCONV cb_read_memory(uint32_t p_address, uint8_t *p_buffer, uint32_t p_bytes, rc_client_t *p_client) {
	RAClient *self = self_of(p_client);
	return self ? self->read_memory(p_address, p_buffer, p_bytes) : 0;
}

void RC_CCONV cb_server_call(const rc_api_request_t *p_request, rc_client_server_callback_t p_callback, void *p_data, rc_client_t *p_client) {
	RAClient *self = self_of(p_client);
	if (self) {
		self->server_call(p_request, p_callback, p_data);
	}
}

void RC_CCONV cb_event(const rc_client_event_t *p_event, rc_client_t *p_client) {
	RAClient *self = self_of(p_client);
	if (self) {
		self->on_event(p_event);
	}
}

void RC_CCONV cb_log(const char *p_message, const rc_client_t *) {
	UtilityFunctions::print_verbose("[rcheevos] ", String::utf8(p_message));
}

void RC_CCONV cb_login(int p_result, const char *p_error, rc_client_t *p_client, void *) {
	RAClient *self = self_of(p_client);
	if (self) {
		self->finish_login(p_result, p_error);
	}
}

void RC_CCONV cb_load(int p_result, const char *p_error, rc_client_t *p_client, void *) {
	RAClient *self = self_of(p_client);
	if (self) {
		self->finish_load(p_result, p_error);
	}
}

rc_clock_t RC_CCONV cb_time(const rc_client_t *) {
	return rc_clock_t(Time::get_singleton()->get_ticks_msec());
}

String str(const char *p) {
	return p ? String::utf8(p) : String();
}

} // namespace

RAClient::RAClient() {
	client = rc_client_create(cb_read_memory, cb_server_call);
	rc_client_set_userdata(client, this);
	rc_client_set_event_handler(client, cb_event);
	rc_client_set_get_time_millisecs_function(client, cb_time);
	rc_client_enable_logging(client, RC_CLIENT_LOG_LEVEL_INFO, cb_log);
	rc_client_set_hardcore_enabled(client, 0);
}

RAClient::~RAClient() {
	if (host) {
		host->set_achievements_client(nullptr);
	}
	if (regions_ready) {
		rc_libretro_memory_destroy(&regions);
	}
	if (client) {
		rc_client_destroy(client);
		client = nullptr;
	}
}

// ------------------------------------------------------------------ user

void RAClient::set_hardcore(bool p_enabled) {
	rc_client_set_hardcore_enabled(client, p_enabled ? 1 : 0);
}

bool RAClient::is_hardcore() const {
	return rc_client_get_hardcore_enabled(client) != 0;
}

void RAClient::login_with_password(const String &p_user, const String &p_password) {
	rc_client_begin_login_with_password(client, p_user.utf8().get_data(), p_password.utf8().get_data(), cb_login, nullptr);
}

void RAClient::login_with_token(const String &p_user, const String &p_token) {
	rc_client_begin_login_with_token(client, p_user.utf8().get_data(), p_token.utf8().get_data(), cb_login, nullptr);
}

void RAClient::logout() {
	rc_client_logout(client);
}

bool RAClient::is_logged_in() const {
	return rc_client_get_user_info(client) != nullptr;
}

Dictionary RAClient::get_user() const {
	Dictionary d;
	const rc_client_user_t *u = rc_client_get_user_info(client);
	if (u) {
		d["name"] = str(u->display_name);
		d["username"] = str(u->username);
		d["token"] = str(u->token);
		d["score"] = u->score;
		d["score_softcore"] = u->score_softcore;
		d["avatar_url"] = str(u->avatar_url);
	}
	return d;
}

void RAClient::finish_login(int p_result, const char *p_error) {
	emit_signal("login_done", p_result == RC_OK, str(p_error));
}

// ------------------------------------------------------------------ game

void RAClient::load_game(Object *p_host, const String &p_path, int p_console_id) {
	unload_game();
	host = Object::cast_to<RetroHost>(p_host);
	if (!host) {
		emit_signal("game_loaded", false, String("no host"));
		return;
	}
	host->set_achievements_client(this);
	init_regions(p_console_id);

	const String global = ProjectSettings::get_singleton()->globalize_path(p_path);
	const std::vector<uint8_t> &rom = host->rom_bytes();
	if (!rom.empty()) {
		rc_client_begin_identify_and_load_game(client, uint32_t(p_console_id), global.utf8().get_data(), rom.data(), rom.size(), cb_load, nullptr);
	} else {
		rc_client_begin_identify_and_load_game(client, uint32_t(p_console_id), global.utf8().get_data(), nullptr, 0, cb_load, nullptr);
	}
}

void RAClient::finish_load(int p_result, const char *p_error) {
	emit_signal("game_loaded", p_result == RC_OK, str(p_error));
}

void RAClient::unload_game() {
	rc_client_unload_game(client);
	if (host) {
		host->set_achievements_client(nullptr);
		host = nullptr;
	}
	if (regions_ready) {
		rc_libretro_memory_destroy(&regions);
		regions_ready = false;
	}
	s_memory_host = nullptr;
}

bool RAClient::is_game_loaded() const {
	return rc_client_is_game_loaded(client) != 0;
}

void RAClient::init_regions(int p_console_id) {
	if (regions_ready) {
		rc_libretro_memory_destroy(&regions);
		regions_ready = false;
	}
	s_memory_host = host;
	memset(&regions, 0, sizeof(regions));
	regions_ready = rc_libretro_memory_init(&regions, host->get_memory_map(), cb_core_memory_info, uint32_t(p_console_id)) != 0;
}

uint32_t RAClient::read_memory(uint32_t p_address, uint8_t *p_buffer, uint32_t p_bytes) {
	if (!regions_ready) {
		return 0;
	}
	return rc_libretro_memory_read(&regions, p_address, p_buffer, p_bytes);
}

Dictionary RAClient::get_game() const {
	Dictionary d;
	const rc_client_game_t *g = rc_client_get_game_info(client);
	if (!g) {
		return d;
	}
	d["id"] = g->id;
	d["title"] = str(g->title);
	d["badge_url"] = str(g->badge_url);
	rc_client_user_game_summary_t s{};
	rc_client_get_user_game_summary(client, &s);
	d["num_achievements"] = s.num_core_achievements;
	d["num_unlocked"] = s.num_unlocked_achievements;
	d["points"] = s.points_core;
	d["points_unlocked"] = s.points_unlocked;
	return d;
}

Dictionary RAClient::achievement_dict(const rc_client_achievement_t *p_a) {
	Dictionary d;
	d["id"] = p_a->id;
	d["title"] = str(p_a->title);
	d["description"] = str(p_a->description);
	d["points"] = p_a->points;
	d["unlocked"] = p_a->unlocked != 0;
	d["progress"] = String::utf8(p_a->measured_progress);
	d["percent"] = p_a->measured_percent;
	d["badge_url"] = str(p_a->badge_url);
	d["badge_locked_url"] = str(p_a->badge_locked_url);
	d["rarity"] = p_a->rarity;
	return d;
}

Array RAClient::get_achievements() {
	Array out;
	rc_client_achievement_list_t *list = rc_client_create_achievement_list(client, RC_CLIENT_ACHIEVEMENT_CATEGORY_CORE,
			RC_CLIENT_ACHIEVEMENT_LIST_GROUPING_LOCK_STATE);
	if (!list) {
		return out;
	}
	for (uint32_t b = 0; b < list->num_buckets; b++) {
		const rc_client_achievement_bucket_t &bucket = list->buckets[b];
		for (uint32_t i = 0; i < bucket.num_achievements; i++) {
			out.push_back(achievement_dict(bucket.achievements[i]));
		}
	}
	rc_client_destroy_achievement_list(list);
	return out;
}

String RAClient::get_rich_presence() {
	char buf[256] = { 0 };
	rc_client_get_rich_presence_message(client, buf, sizeof(buf));
	return String::utf8(buf);
}

// ------------------------------------------------------------- per frame

void RAClient::do_frame() {
	rc_client_do_frame(client);
}

void RAClient::idle() {
	rc_client_idle(client);
}

void RAClient::on_reset() {
	rc_client_reset(client);
}

void RAClient::on_state_loaded() {
	// achievement progress is not stored in our states: start the checks over
	rc_client_deserialize_progress_sized(client, nullptr, 0);
}

// ------------------------------------------------------------------ http

void RAClient::server_call(const rc_api_request_t *p_request, rc_client_server_callback_t p_callback, void *p_data) {
	const int id = next_id++;
	pending[id] = Pending{ p_callback, p_data };
	emit_signal("http_request", id, str(p_request->url), str(p_request->post_data), str(p_request->content_type));
}

void RAClient::http_response(int p_id, int p_status, const PackedByteArray &p_body) {
	auto it = pending.find(p_id);
	if (it == pending.end()) {
		return;
	}
	Pending p = it->second;
	pending.erase(it);
	rc_api_server_response_t response{};
	response.body = reinterpret_cast<const char *>(p_body.ptr());
	response.body_length = size_t(p_body.size());
	response.http_status_code = p_status > 0 ? p_status : RC_API_SERVER_RESPONSE_RETRYABLE_CLIENT_ERROR;
	p.callback(&response, p.data);
}

// ---------------------------------------------------------------- events

void RAClient::on_event(const rc_client_event_t *p_event) {
	Dictionary d;
	String type;
	switch (p_event->type) {
		case RC_CLIENT_EVENT_ACHIEVEMENT_TRIGGERED:
			type = "unlocked";
			d = achievement_dict(p_event->achievement);
			break;
		case RC_CLIENT_EVENT_GAME_COMPLETED:
			type = "completed";
			break;
		case RC_CLIENT_EVENT_RESET:
			type = "reset";
			break;
		case RC_CLIENT_EVENT_ACHIEVEMENT_PROGRESS_INDICATOR_SHOW:
		case RC_CLIENT_EVENT_ACHIEVEMENT_PROGRESS_INDICATOR_UPDATE:
			type = "progress";
			d = achievement_dict(p_event->achievement);
			break;
		case RC_CLIENT_EVENT_ACHIEVEMENT_PROGRESS_INDICATOR_HIDE:
			type = "progress_hide";
			break;
		case RC_CLIENT_EVENT_LEADERBOARD_STARTED:
		case RC_CLIENT_EVENT_LEADERBOARD_SUBMITTED:
		case RC_CLIENT_EVENT_LEADERBOARD_FAILED:
			type = p_event->type == RC_CLIENT_EVENT_LEADERBOARD_STARTED ? "lb_started" : (p_event->type == RC_CLIENT_EVENT_LEADERBOARD_SUBMITTED ? "lb_submitted" : "lb_failed");
			d["title"] = str(p_event->leaderboard->title);
			d["description"] = str(p_event->leaderboard->description);
			break;
		case RC_CLIENT_EVENT_SERVER_ERROR:
			type = "server_error";
			d["message"] = str(p_event->server_error->error_message);
			break;
		case RC_CLIENT_EVENT_DISCONNECTED:
			type = "disconnected";
			break;
		case RC_CLIENT_EVENT_RECONNECTED:
			type = "reconnected";
			break;
		default:
			return;
	}
	emit_signal("event", type, d);
}

// --------------------------------------------------------------- binding

void RAClient::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_hardcore", "enabled"), &RAClient::set_hardcore);
	ClassDB::bind_method(D_METHOD("is_hardcore"), &RAClient::is_hardcore);
	ClassDB::bind_method(D_METHOD("login_with_password", "user", "password"), &RAClient::login_with_password);
	ClassDB::bind_method(D_METHOD("login_with_token", "user", "token"), &RAClient::login_with_token);
	ClassDB::bind_method(D_METHOD("logout"), &RAClient::logout);
	ClassDB::bind_method(D_METHOD("is_logged_in"), &RAClient::is_logged_in);
	ClassDB::bind_method(D_METHOD("get_user"), &RAClient::get_user);
	ClassDB::bind_method(D_METHOD("load_game", "host", "path", "console_id"), &RAClient::load_game);
	ClassDB::bind_method(D_METHOD("unload_game"), &RAClient::unload_game);
	ClassDB::bind_method(D_METHOD("is_game_loaded"), &RAClient::is_game_loaded);
	ClassDB::bind_method(D_METHOD("get_game"), &RAClient::get_game);
	ClassDB::bind_method(D_METHOD("get_achievements"), &RAClient::get_achievements);
	ClassDB::bind_method(D_METHOD("get_rich_presence"), &RAClient::get_rich_presence);
	ClassDB::bind_method(D_METHOD("http_response", "id", "status", "body"), &RAClient::http_response);
	ClassDB::bind_method(D_METHOD("idle"), &RAClient::idle);

	ADD_SIGNAL(MethodInfo("http_request", PropertyInfo(Variant::INT, "id"), PropertyInfo(Variant::STRING, "url"),
			PropertyInfo(Variant::STRING, "post_data"), PropertyInfo(Variant::STRING, "content_type")));
	ADD_SIGNAL(MethodInfo("login_done", PropertyInfo(Variant::BOOL, "ok"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo("game_loaded", PropertyInfo(Variant::BOOL, "ok"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo("event", PropertyInfo(Variant::STRING, "type"), PropertyInfo(Variant::DICTIONARY, "data")));
}
