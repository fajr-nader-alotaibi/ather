extends Node
## Shared profile and host-authoritative ENet session for direct-IP co-op.

signal connection_status_changed(message: String)
signal lobby_changed
signal game_started(settings: Dictionary)
signal player_state_updated(peer_id: int, position: Vector2, velocity: Vector2, facing: int, outfit_index: int)
signal player_left(peer_id: int)
signal restart_requested
signal session_ended
signal seed_collect_requested(peer_id: int, seed_id: int)
signal interact_requested(peer_id: int)
signal world_state_updated(seed_count: int, restored: bool, has_won: bool, collected_ids: Array)

const DEFAULT_PORT := 24567
const MAX_PLAYERS := 4

var language := "ar"
var difficulty := "normal"
var outfit_index := 0
var player_name := "حارسة"
var is_networked := false
var is_host := false
var game_running := false
var lobby_names: Dictionary = {}
var lobby_outfits: Dictionary = {}
var game_settings: Dictionary = {}
var status_message := ""
var music_volume := 0.72
var sfx_volume := 0.82
var ui_volume := 0.72
var muted := false
var graphics_quality := "balanced"
var run_result: Dictionary = {}

var _world_seed_count := 0
var _world_restored := false
var _world_won := false
var _world_collected: Array = []


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("user://athar_settings.cfg") == OK:
		language = str(config.get_value("settings", "language", "ar"))
		difficulty = str(config.get_value("settings", "difficulty", "normal"))
		outfit_index = clampi(int(config.get_value("settings", "outfit", 0)), 0, 5)
		player_name = str(config.get_value("settings", "player_name", "حارسة"))
		music_volume = clampf(float(config.get_value("settings", "music_volume", 0.72)), 0.0, 1.0)
		sfx_volume = clampf(float(config.get_value("settings", "sfx_volume", 0.82)), 0.0, 1.0)
		ui_volume = clampf(float(config.get_value("settings", "ui_volume", 0.72)), 0.0, 1.0)
		muted = bool(config.get_value("settings", "muted", false))
		graphics_quality = str(config.get_value("settings", "graphics_quality", "balanced"))
	_ensure_audio_buses()
	apply_audio_settings()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "language", language)
	config.set_value("settings", "difficulty", difficulty)
	config.set_value("settings", "outfit", outfit_index)
	config.set_value("settings", "player_name", player_name)
	config.set_value("settings", "music_volume", music_volume)
	config.set_value("settings", "sfx_volume", sfx_volume)
	config.set_value("settings", "ui_volume", ui_volume)
	config.set_value("settings", "muted", muted)
	config.set_value("settings", "graphics_quality", graphics_quality)
	config.save("user://athar_settings.cfg")


func set_player_name(value: String) -> void:
	var cleaned := value.strip_edges().left(18)
	player_name = cleaned if not cleaned.is_empty() else ("حارسة" if language == "ar" else "Keeper")
	save_profile()


func settings_snapshot() -> Dictionary:
	return {
		"language": language,
		"difficulty": difficulty,
		"outfit_index": outfit_index,
		"player_name": player_name
	}


func start_solo() -> void:
	leave_lobby()
	_reset_world_snapshot()
	run_result.clear()
	game_settings = settings_snapshot()
	game_running = true
	game_started.emit(game_settings)


func host_lobby() -> Error:
	leave_lobby()
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(DEFAULT_PORT, MAX_PLAYERS - 1)
	if result != OK:
		_set_status(_localized("تعذر فتح الغرفة على المنفذ %d." % DEFAULT_PORT, "Could not open the room on port %d." % DEFAULT_PORT))
		return result
	multiplayer.multiplayer_peer = peer
	is_networked = true
	is_host = true
	game_running = false
	lobby_names = {1: player_name}
	lobby_outfits = {1: outfit_index}
	_set_status(_localized("الغرفة جاهزة. أعطِ الأصدقاء عنوان IP والمنفذ %d." % DEFAULT_PORT, "Room ready. Share your IP and port %d with friends." % DEFAULT_PORT))
	lobby_changed.emit()
	return OK


func join_lobby(address: String, port := DEFAULT_PORT) -> Error:
	leave_lobby()
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(address.strip_edges(), port)
	if result != OK:
		_set_status(_localized("تعذر بدء الاتصال (%d)." % result, "Could not start connection (%d)." % result))
		return result
	multiplayer.multiplayer_peer = peer
	is_networked = true
	is_host = false
	game_running = false
	_set_status(_localized("جارٍ الاتصال بالمضيف...", "Connecting to host..."))
	return OK


func leave_lobby() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_networked = false
	is_host = false
	game_running = false
	lobby_names.clear()
	lobby_outfits.clear()
	lobby_changed.emit()


func host_start_game() -> void:
	if not is_host:
		return
	_reset_world_snapshot()
	game_settings = settings_snapshot()
	game_settings["lobby_names"] = lobby_names.duplicate(true)
	game_settings["lobby_outfits"] = lobby_outfits.duplicate(true)
	game_running = true
	_broadcast_lobby()
	_start_game_rpc.rpc(game_settings)


func active_peer_ids() -> Array[int]:
	if not is_networked:
		return [1]
	var ids: Array[int] = []
	for key in lobby_names.keys():
		ids.append(int(key))
	if not ids.has(1):
		ids.append(1)
	var local_id := multiplayer.get_unique_id()
	if not ids.has(local_id):
		ids.append(local_id)
	ids.sort()
	return ids


func name_for_peer(peer_id: int) -> String:
	return str(lobby_names.get(peer_id, _localized("حارس", "Keeper")))


func outfit_for_peer(peer_id: int) -> int:
	return clampi(int(lobby_outfits.get(peer_id, 0)), 0, 5)


func send_player_state(peer_id: int, position: Vector2, velocity: Vector2, facing: int, color_index: int) -> void:
	if not is_networked:
		return
	if is_host:
		_player_state_rpc.rpc(peer_id, position, velocity, facing, color_index)
	else:
		_submit_player_state.rpc_id(1, position, velocity, facing, color_index)


func request_seed_collect(seed_id: int) -> void:
	if not is_networked or is_host:
		seed_collect_requested.emit(multiplayer.get_unique_id() if is_networked else 1, seed_id)
	else:
		_request_seed_collect.rpc_id(1, seed_id)


func request_interact() -> void:
	if not is_networked or is_host:
		interact_requested.emit(multiplayer.get_unique_id() if is_networked else 1)
	else:
		_request_interact.rpc_id(1)


func publish_world_state(seed_count: int, restored: bool, has_won: bool, collected_ids: Array) -> void:
	if is_networked and not is_host:
		return
	_world_seed_count = seed_count
	_world_restored = restored
	_world_won = has_won
	_world_collected = collected_ids.duplicate()
	if is_networked:
		_world_state_rpc.rpc(seed_count, restored, has_won, _world_collected)
	else:
		world_state_updated.emit(seed_count, restored, has_won, _world_collected)


func request_world_snapshot() -> void:
	if is_networked and not is_host:
		_request_world_snapshot.rpc_id(1)


func request_restart() -> void:
	if not is_networked:
		_restart_game()
	elif is_host:
		_restart_game.rpc()
	else:
		_request_restart.rpc_id(1)


func _reset_world_snapshot() -> void:
	_world_seed_count = 0
	_world_restored = false
	_world_won = false
	_world_collected.clear()


func _localized(arabic: String, english: String) -> String:
	return arabic if language == "ar" else english


func _set_status(message: String) -> void:
	status_message = message
	connection_status_changed.emit(message)


func _on_peer_connected(peer_id: int) -> void:
	if not is_host:
		return
	if game_running:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	lobby_names[peer_id] = _localized("جارٍ الانضمام...", "Joining...")
	lobby_outfits[peer_id] = peer_id % 6
	_broadcast_lobby()


func _on_peer_disconnected(peer_id: int) -> void:
	lobby_names.erase(peer_id)
	lobby_outfits.erase(peer_id)
	player_left.emit(peer_id)
	if is_host:
		_broadcast_lobby()
	_set_status(_localized("غادر لاعب الغرفة.", "A player left the room."))


func _on_connected_to_server() -> void:
	_set_status(_localized("تم الاتصال. بانتظار بدء المضيف.", "Connected. Waiting for the host to start."))
	_register_player.rpc_id(1, player_name, outfit_index)


func _on_connection_failed() -> void:
	_set_status(_localized("فشل الاتصال. تحقق من العنوان والمنفذ وإعدادات الشبكة.", "Connection failed. Check the address, port, and network settings."))
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_networked = false
	is_host = false
	lobby_changed.emit()


func _on_server_disconnected() -> void:
	_set_status(_localized("انقطع اتصال المضيف.", "The host connection was lost."))
	session_ended.emit()
	leave_lobby()


func _broadcast_lobby() -> void:
	lobby_changed.emit()
	_lobby_snapshot.rpc(lobby_names, lobby_outfits)


@rpc("any_peer", "call_remote", "reliable")
func _register_player(display_name: String, color_index: int) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1:
		return
	lobby_names[sender] = display_name.strip_edges().left(18)
	lobby_outfits[sender] = clampi(color_index, 0, 5)
	_broadcast_lobby()


@rpc("authority", "call_remote", "reliable")
func _lobby_snapshot(names: Dictionary, outfits: Dictionary) -> void:
	lobby_names = names
	lobby_outfits = outfits
	lobby_changed.emit()


@rpc("authority", "call_local", "reliable")
func _start_game_rpc(settings: Dictionary) -> void:
	game_settings = settings.duplicate(true)
	lobby_names = game_settings.get("lobby_names", lobby_names)
	lobby_outfits = game_settings.get("lobby_outfits", lobby_outfits)
	game_settings["language"] = language
	game_settings["outfit_index"] = outfit_index
	_reset_world_snapshot()
	game_running = true
	game_started.emit(game_settings)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_player_state(position: Vector2, velocity: Vector2, facing: int, color_index: int) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1 or not lobby_names.has(sender):
		return
	_player_state_rpc.rpc(sender, position, velocity, facing, color_index)


@rpc("authority", "call_local", "unreliable_ordered")
func _player_state_rpc(peer_id: int, position: Vector2, velocity: Vector2, facing: int, color_index: int) -> void:
	player_state_updated.emit(peer_id, position, velocity, facing, color_index)


@rpc("any_peer", "call_remote", "reliable")
func _request_seed_collect(seed_id: int) -> void:
	if is_host:
		seed_collect_requested.emit(multiplayer.get_remote_sender_id(), seed_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_interact() -> void:
	if is_host:
		interact_requested.emit(multiplayer.get_remote_sender_id())


@rpc("authority", "call_local", "reliable")
func _world_state_rpc(seed_count: int, restored: bool, has_won: bool, collected_ids: Array) -> void:
	_world_seed_count = seed_count
	_world_restored = restored
	_world_won = has_won
	_world_collected = collected_ids.duplicate()
	world_state_updated.emit(seed_count, restored, has_won, _world_collected)


@rpc("any_peer", "call_remote", "reliable")
func _request_world_snapshot() -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	_world_state_rpc.rpc_id(sender, _world_seed_count, _world_restored, _world_won, _world_collected)

@rpc("any_peer", "call_remote", "reliable")
func _request_restart() -> void:
	if is_host and lobby_names.has(multiplayer.get_remote_sender_id()):
		_restart_game.rpc()


@rpc("authority", "call_local", "reliable")
func _restart_game() -> void:
	_reset_world_snapshot()
	restart_requested.emit()

func change_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		_set_status(_localized("المشهد غير موجود: %s" % path, "Scene not found: %s" % path))
		push_error(status_message)
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func local_ip_address() -> String:
	for address in IP.get_local_addresses():
		if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."):
			return address
	return "127.0.0.1"


func restore_defaults() -> void:
	language = "ar"
	difficulty = "normal"
	outfit_index = 0
	player_name = "حارسة"
	music_volume = 0.72
	sfx_volume = 0.82
	ui_volume = 0.72
	muted = false
	graphics_quality = "balanced"
	apply_audio_settings()
	save_profile()


func apply_audio_settings() -> void:
	_ensure_audio_buses()
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("UI"), linear_to_db(maxf(ui_volume, 0.001)))
	Engine.max_fps = 45 if graphics_quality == "low" else (60 if graphics_quality == "balanced" else 0)


func play_ui_click() -> void:
	if muted or ui_volume <= 0.01:
		return
	var samples := PackedByteArray()
	var sample_rate := 22050
	var sample_count := 990
	for index in range(sample_count):
		var fade := 1.0 - float(index) / float(sample_count)
		var sample := int(sin(TAU * 880.0 * float(index) / float(sample_rate)) * 3200.0 * fade)
		samples.append(sample & 0xff)
		samples.append((sample >> 8) & 0xff)
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = sample_rate
	sound.stereo = false
	sound.data = samples
	var player := AudioStreamPlayer.new()
	player.bus = "UI"
	player.stream = sound
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _ensure_audio_buses() -> void:
	for bus_name in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
