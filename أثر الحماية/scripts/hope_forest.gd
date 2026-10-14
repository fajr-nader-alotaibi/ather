extends Node2D
## First playable slice with host-authoritative collection, restoration, and team camera.

const TextCatalog = preload("res://scripts/localization.gd")
const PlayerScene = preload("res://scenes/player.tscn")

const WORLD_END := 3600.0
const SPAWN_POINT := Vector2(160, 572)
const PLANT_POINT := Vector2(2186, 544)
const GATE_POINT := Vector2(3370, 558)
const GATE_TRIGGER_RADIUS := 145.0

@onready var players_root: Node2D = $Players
@onready var companion: Node2D = $Companion
@onready var hud: Control = $HUD/Interface
@onready var backdrop: Sprite2D = $Backdrop
@onready var team_camera: Camera2D = $TeamCamera

var player_nodes: Dictionary = {}
var local_player: CharacterBody2D
var seed_count := 0
var plant_restored := false
var has_won := false
var _bridge: StaticBody2D
var _grove_light: PointLight2D
var _gate_light: PointLight2D
var _float_clock := 0.0
var _hud_refresh_left := 0.0
var _goal_hint := ""
var _seed_pickups: Dictionary = {}
var _collected_seed_ids: Array[int] = []
var _sparkle_bursts: Array[Dictionary] = []
var _death_reset_requested := false


func _ready() -> void:
	_setup_input_map()
	_spawn_players()
	local_player = player_nodes.get(multiplayer.get_unique_id() if GameSession.is_networked else 1)
	if not is_instance_valid(local_player):
		local_player = player_nodes.values()[0] as CharacterBody2D
	companion.set("target", local_player)
	team_camera.make_current()
	team_camera.limit_left = 0
	team_camera.limit_right = int(WORLD_END)
	team_camera.limit_top = 0
	team_camera.limit_bottom = 720
	_grove_light = _add_world_light(PLANT_POINT + Vector2(0, -56), Color("a3ebb0"), 1.8, 0.0)
	_gate_light = _add_world_light(GATE_POINT + Vector2(0, -44), Color("a9d6ee"), 1.4, 0.38)
	create_terrain(0, 1110, 620)
	create_terrain(735, 1015, 524)
	create_terrain(1080, 1360, 620)
	create_terrain(1415, 1535, 554)
	create_terrain(1620, 1750, 520)
	create_terrain(1775, 2325, 620)
	create_terrain(2510, 2700, 505)
	create_terrain(2680, WORLD_END, 620)
	add_pickup(Vector2(505, 470), 0)
	add_pickup(Vector2(928, 414), 1)
	add_pickup(Vector2(1652, 438), 2)
	hud.connect("pause_changed", Callable(self, "_on_pause_changed"))
	hud.connect("restart_requested", Callable(self, "_on_restart_button"))
	hud.connect("main_menu_requested", Callable(self, "_return_to_menu"))
	GameSession.player_state_updated.connect(_on_player_state_updated)
	GameSession.player_left.connect(_on_player_left)
	GameSession.seed_collect_requested.connect(_on_network_seed_collect)
	GameSession.interact_requested.connect(_on_network_interact)
	GameSession.world_state_updated.connect(_on_network_world_state)
	GameSession.restart_requested.connect(_restart_level)
	GameSession.session_ended.connect(_return_to_menu)
	update_hud()
	if GameSession.is_networked:
		GameSession.request_world_snapshot()


func _process(delta: float) -> void:
	_float_clock += delta
	_hud_refresh_left -= delta
	for index in range(_sparkle_bursts.size() - 1, -1, -1):
		_sparkle_bursts[index]["time"] = float(_sparkle_bursts[index]["time"]) + delta
		if float(_sparkle_bursts[index]["time"]) > 0.55:
			_sparkle_bursts.remove_at(index)
	if player_nodes.size() > 0:
		_update_team_camera(delta)
	if local_player.global_position.y > 900.0:
		if not _death_reset_requested:
			_death_reset_requested = true
			GameSession.request_restart()
		return
	# The host checks every teammate and announces chapter completion to the party.
	if plant_restored and not has_won and (not GameSession.is_networked or GameSession.is_host):
		for peer_id in player_nodes.keys():
			var candidate := player_nodes[peer_id] as Node2D
			if is_instance_valid(candidate) and candidate.global_position.distance_to(GATE_POINT) < GATE_TRIGGER_RADIUS:
				_complete_level()
				break
	if not has_won and _hud_refresh_left <= 0.0:
		_hud_refresh_left = 0.12
		update_hud()
	if plant_restored or not _sparkle_bursts.is_empty():
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		hud.call("_on_pause_pressed")
		get_viewport().set_input_as_handled()


func _spawn_players() -> void:
	var ids := GameSession.active_peer_ids()
	for index in range(ids.size()):
		var peer_id := ids[index]
		if player_nodes.has(peer_id):
			continue
		var player := PlayerScene.instantiate() as CharacterBody2D
		player.name = "Player_%d" % peer_id
		player.set_multiplayer_authority(peer_id)
		players_root.add_child(player)
		player.global_position = SPAWN_POINT + Vector2(float(index) * 42.0, 0.0)
		player.call("configure_avatar", GameSession.outfit_for_peer(peer_id), GameSession.name_for_peer(peer_id))
		player.interact_requested.connect(_on_local_interact.bind(peer_id))
		player.double_jump_triggered.connect(_on_double_jump)
		player_nodes[peer_id] = player


func _update_team_camera(delta: float) -> void:
	var min_x := INF
	var max_x := -INF
	var sum_y := 0.0
	for player_variant in player_nodes.values():
		var player := player_variant as Node2D
		if not is_instance_valid(player):
			continue
		min_x = minf(min_x, player.global_position.x)
		max_x = maxf(max_x, player.global_position.x)
		sum_y += player.global_position.y
	var count := maxf(1.0, float(player_nodes.size()))
	var span := max_x - min_x
	var view_width := get_viewport_rect().size.x
	var desired_zoom := clampf(view_width / maxf(860.0, span + 420.0), 0.68, 1.0)
	team_camera.zoom = team_camera.zoom.lerp(Vector2.ONE * desired_zoom, minf(1.0, delta * 2.0))
	var half_view := view_width * 0.5 / team_camera.zoom.x
	var center_x := (min_x + max_x) * 0.5
	team_camera.global_position.x = clampf(center_x, half_view, WORLD_END - half_view)
	var center_y := sum_y / count - 72.0
	team_camera.global_position.y = lerpf(team_camera.global_position.y, clampf(center_y, 300.0, 445.0), minf(1.0, delta * 1.4))


func _on_player_state_updated(peer_id: int, position: Vector2, new_velocity: Vector2, facing: int, outfit: int) -> void:
	if not player_nodes.has(peer_id):
		return
	player_nodes[peer_id].call("receive_network_state", position, new_velocity, facing, outfit)


func _on_player_left(peer_id: int) -> void:
	if not player_nodes.has(peer_id):
		return
	var player: Node = player_nodes[peer_id]
	player_nodes.erase(peer_id)
	player.queue_free()


func _add_world_light(point: Vector2, tint: Color, scale: float, brightness: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = load("res://assets/glow.svg")
	light.position = point
	light.color = tint
	light.energy = brightness
	light.texture_scale = scale
	add_child(light)
	return light


func create_terrain(left: float, right: float, top: float, restored := false) -> StaticBody2D:
	var terrain := StaticBody2D.new()
	terrain.set_script(load("res://scripts/terrain.gd"))
	terrain.set("span", right - left)
	terrain.set("thickness", 68.0)
	terrain.set("reclaimed", restored)
	_terrain_position(terrain, left, top)
	terrain.z_index = 1
	add_child(terrain)
	return terrain


func _terrain_position(terrain: Node2D, left: float, top: float) -> void:
	terrain.position = Vector2(left, top)


func add_pickup(point: Vector2, seed_id: int) -> void:
	var pickup := load("res://scenes/seed_pickup.tscn").instantiate() as Area2D
	pickup.position = point
	pickup.set_meta("seed_id", seed_id)
	pickup.collected.connect(_on_seed_collected)
	add_child(pickup)
	_seed_pickups[seed_id] = pickup


func _on_seed_collected(pickup: Node2D) -> void:
	if not is_instance_valid(pickup):
		return
	var seed_id := int(pickup.get_meta("seed_id", -1))
	if GameSession.is_networked and not GameSession.is_host:
		GameSession.request_seed_collect(seed_id)
		return
	var peer_id := _closest_player_id(pickup.global_position)
	_collect_seed_for_peer(peer_id, seed_id)


func _closest_player_id(point: Vector2) -> int:
	var closest_id := 1
	var closest_distance := INF
	for peer_variant in player_nodes.keys():
		var player := player_nodes[peer_variant] as Node2D
		if not is_instance_valid(player):
			continue
		var distance := player.global_position.distance_to(point)
		if distance < closest_distance:
			closest_distance = distance
			closest_id = int(peer_variant)
	return closest_id


func _collect_seed_for_peer(peer_id: int, seed_id: int) -> void:
	if GameSession.is_networked and not GameSession.is_host:
		return
	if not _seed_pickups.has(seed_id) or not player_nodes.has(peer_id):
		return
	var pickup := _seed_pickups[seed_id] as Area2D
	var player := player_nodes[peer_id] as Node2D
	if not is_instance_valid(pickup) or not is_instance_valid(player):
		return
	if player.global_position.distance_to(pickup.global_position) > 92.0:
		return
	_collected_seed_ids.append(seed_id)
	_seed_pickups.erase(seed_id)
	seed_count += 1
	pickup.queue_free()
	update_hud()
	_publish_world_state()


func _on_network_seed_collect(peer_id: int, seed_id: int) -> void:
	_collect_seed_for_peer(peer_id, seed_id)


func _on_local_interact(peer_id: int) -> void:
	if GameSession.is_networked and not GameSession.is_host:
		GameSession.request_interact()
	else:
		_interact_at_player(peer_id)


func _on_network_interact(peer_id: int) -> void:
	_interact_at_player(peer_id)


func _interact_at_player(peer_id: int) -> void:
	if get_tree().paused or has_won or not player_nodes.has(peer_id):
		return
	var player := player_nodes[peer_id] as Node2D
	if player.global_position.distance_to(PLANT_POINT) < 130.0 and not plant_restored:
		if seed_count < 3:
			_goal_hint = TextCatalog.text("need_seeds", str(hud.get("language")))
		else:
			_restore_grove()
		return
	if player.global_position.distance_to(GATE_POINT) < GATE_TRIGGER_RADIUS:
		if plant_restored:
			_complete_level()
		else:
			_goal_hint = TextCatalog.text("bridge_first", str(hud.get("language")))


func _complete_level() -> void:
	if has_won:
		return
	has_won = true
	_gate_light.color = Color("fff0c0")
	_gate_light.energy = 1.35
	var progress := ConfigFile.new()
	progress.set_value("progress", "hope_forest_complete", true)
	progress.save("user://athar_save.cfg")
	update_hud()
	_publish_world_state()


func _restore_grove() -> void:
	if plant_restored:
		return
	plant_restored = true
	_grove_light.color = Color("d1f49b")
	var light_tween := create_tween()
	light_tween.tween_property(_grove_light, "energy", 1.25, 0.9)
	_gate_light.color = Color("ffe0a3")
	_gate_light.energy = 0.9
	seed_count -= 3
	_bridge = create_terrain(2320, 2684, 620, true)
	_bridge.scale = Vector2(0.04, 1.0)
	create_twig(PLANT_POINT + Vector2(57, 60))
	var tween := create_tween()
	tween.tween_property(_bridge, "scale", Vector2.ONE, 0.72).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var glow := create_tween()
	glow.tween_property(backdrop, "modulate", Color(1.08, 1.08, 1.04, 1.0), 1.1)
	_goal_hint = TextCatalog.text("bridge_awake", str(hud.get("language")))
	update_hud()
	_publish_world_state()


func _publish_world_state() -> void:
	GameSession.publish_world_state(seed_count, plant_restored, has_won, _collected_seed_ids)


func _on_network_world_state(count: int, restored: bool, won: bool, collected: Array) -> void:
	for seed_variant in collected:
		var seed_id := int(seed_variant)
		if _seed_pickups.has(seed_id):
			var pickup := _seed_pickups[seed_id] as Node
			_seed_pickups.erase(seed_id)
			pickup.queue_free()
	_collected_seed_ids.clear()
	for seed_variant in collected:
		_collected_seed_ids.append(int(seed_variant))
	var was_restored := plant_restored
	seed_count = count
	plant_restored = restored
	has_won = won
	if plant_restored and not was_restored:
		_grove_light.color = Color("d1f49b")
		_grove_light.energy = 1.25
		_gate_light.color = Color("ffe0a3")
		_gate_light.energy = 0.9
		_bridge = create_terrain(2320, 2684, 620, true)
		_bridge.scale = Vector2(0.04, 1.0)
		create_twig(PLANT_POINT + Vector2(57, 60))
		var tween := create_tween()
		tween.tween_property(_bridge, "scale", Vector2.ONE, 0.72).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		backdrop.modulate = Color(1.08, 1.08, 1.04, 1.0)
	if won:
		has_won = true
		_gate_light.color = Color("fff0c0")
		_gate_light.energy = 1.35
	update_hud()


func _on_double_jump(at: Vector2) -> void:
	_sparkle_bursts.append({"position": at, "time": 0.0})


func _on_pause_changed(is_paused: bool) -> void:
	get_tree().paused = is_paused


func _on_restart_button() -> void:
	GameSession.request_restart()


func _restart_level() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _return_to_menu() -> void:
	get_tree().paused = false
	GameSession.leave_lobby()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _setup_input_map() -> void:
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_bind_keys("interact", [KEY_E])
	_bind_keys("pause", [KEY_ESCAPE])


func _bind_keys(action: String, keycodes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for keycode in keycodes:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)


func _draw() -> void:
	_draw_wilted_sprout(Vector2(PLANT_POINT.x, 620.0), plant_restored)
	_draw_gate(GATE_POINT, plant_restored)
	_draw_mushroom(Vector2(685, 600), 0.85, Color("c77e77"))
	_draw_mushroom(Vector2(1160, 600), 0.62, Color("da9777"))
	_draw_mushroom(Vector2(1880, 600), 0.72, Color("b97881"))
	_draw_mushroom(Vector2(2900, 600), 0.9, Color("d08c78"))
	if plant_restored:
		for i in range(5):
			var x := 2240.0 + float(i) * 86.0
			var y := 577.0 + sin(_float_clock * 2.1 + float(i)) * 9.0
			draw_circle(Vector2(x, y), 5.0 + sin(_float_clock * 3.0 + float(i)) * 1.0, Color(0.76, 0.96, 0.72, 0.75))
	for burst in _sparkle_bursts:
		var point: Vector2 = burst["position"]
		var progress := clampf(float(burst["time"]) / 0.55, 0.0, 1.0)
		var alpha := 1.0 - progress
		draw_circle(point, 8.0 + progress * 34.0, Color(0.64, 0.95, 0.87, 0.12 * alpha))
		draw_arc(point, 12.0 + progress * 25.0, 0.0, TAU, 24, Color(0.86, 1.0, 0.73, 0.8 * alpha), 2.2, true)
		for ray in range(8):
			var direction := Vector2.RIGHT.rotated(float(ray) * TAU / 8.0)
			draw_line(point + direction * (8.0 + progress * 8.0), point + direction * (14.0 + progress * 27.0), Color(1.0, 0.9, 0.59, alpha), 2.0, true)


func _draw_wilted_sprout(base: Vector2, alive: bool) -> void:
	var stem := Color("72b995") if alive else Color("8f7770")
	var petal := Color("f7cc83") if alive else Color("917d88")
	draw_line(base, base + Vector2(0, -58), stem, 8.0, true)
	draw_line(base + Vector2(0, -28), base + Vector2(-26, -48 if alive else -35), stem, 6.0, true)
	draw_line(base + Vector2(0, -37), base + Vector2(24, -58 if alive else -43), stem, 6.0, true)
	if alive:
		_draw_leaf(base + Vector2(-28, -50), -0.4, Color("a6d77b"))
		_draw_leaf(base + Vector2(25, -60), 0.55, Color("8bcf88"))
		for angle in range(5):
			var direction := Vector2.RIGHT.rotated(float(angle) * TAU / 5.0)
			draw_circle(base + Vector2(0, -65) + direction * 12.0, 7.0, petal)
		draw_circle(base + Vector2(0, -65), 7.0, Color("fff1b0"))
	else:
		_draw_leaf(base + Vector2(-22, -37), 1.1, Color("788267"))
		_draw_leaf(base + Vector2(22, -44), -0.9, Color("726d68"))
		draw_circle(base + Vector2(0, -56), 10.0, Color("82717a"))
	if alive:
		draw_circle(base + Vector2(0, -58), 34.0 + sin(_float_clock * 2.5) * 3.0, Color(0.72, 0.93, 0.71, 0.08))


func _draw_leaf(at: Vector2, rotation: float, color: Color) -> void:
	var points := PackedVector2Array([Vector2(-4, 0), Vector2(0, -19), Vector2(15, -14), Vector2(18, -3), Vector2(8, 6)])
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append(at + point.rotated(rotation))
	draw_colored_polygon(transformed, color)


func _draw_gate(at: Vector2, open: bool) -> void:
	var frame_color := Color("d8b57b") if open else Color("8293a2")
	draw_arc(at + Vector2(0, -2), 51.0, PI, TAU, 32, frame_color, 10.0, true)
	draw_line(at + Vector2(-51, -2), at + Vector2(-51, 12), frame_color, 9.0, true)
	draw_line(at + Vector2(51, -2), at + Vector2(51, 12), frame_color, 9.0, true)
	var lamp := Color("f9d586") if open else Color("8e9da9")
	draw_circle(at + Vector2(0, -47), 13.0 + sin(_float_clock * 2.2) * 2.0, lamp)
	draw_circle(at + Vector2(0, -47), 25.0, Color(lamp.r, lamp.g, lamp.b, 0.12))
	draw_line(at + Vector2(-18, -20), at + Vector2(18, -20), Color("526d65"), 3.0, true)


func _draw_mushroom(base: Vector2, scale_factor: float, cap: Color) -> void:
	var height := 48.0 * scale_factor
	var width := 47.0 * scale_factor
	draw_rect(Rect2(base.x - width * 0.22, base.y - height, width * 0.44, height), Color("d7ac91"))
	draw_arc(base + Vector2(0, -height), width, PI, TAU, 24, Color("553e43"), 4.0 * scale_factor, true)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-width, -height), base + Vector2(-width * 0.78, -height * 1.55),
		base + Vector2(-width * 0.22, -height * 1.92), base + Vector2(width * 0.42, -height * 1.8),
		base + Vector2(width, -height)
	]), cap)
	draw_line(base + Vector2(-width * 0.7, -height - 3), base + Vector2(width * 0.7, -height - 3), Color("f2c8a1"), 4.0 * scale_factor, true)
	for dot in [Vector2(-0.35, -1.43), Vector2(0.26, -1.62), Vector2(0.62, -1.26)]:
		draw_circle(base + Vector2(dot.x * width, dot.y * height), 3.2 * scale_factor, Color("f2d7ad"))


func create_twig(point: Vector2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([Vector2(0, 0), Vector2(16, -17), Vector2(31, -31), Vector2(49, -40)])
	line.width = 8.0
	line.default_color = Color("b5d879")
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.position = point
	line.z_index = 3
	add_child(line)
	for offset in [Vector2(13, -18), Vector2(30, -31), Vector2(47, -40)]:
		var leaf := Polygon2D.new()
		leaf.polygon = PackedVector2Array([Vector2(-4, 0), Vector2(0, -10), Vector2(9, -6), Vector2(6, 3)])
		leaf.color = Color("a9d67a")
		leaf.position = point + offset
		leaf.z_index = 4
		add_child(leaf)


func update_hud() -> void:
	if not is_instance_valid(hud):
		return
	var hint := _current_hint()
	hud.call("set_world_state", seed_count, plant_restored, has_won, hint)


func _current_hint() -> String:
	var current_language := str(hud.get("language"))
	if not _goal_hint.is_empty():
		var result := _goal_hint
		_goal_hint = ""
		return result
	if not plant_restored and local_player.global_position.distance_to(PLANT_POINT) < 180.0:
		return TextCatalog.text("prompt_plant", current_language) if seed_count >= 3 else TextCatalog.text("prompt_need", current_language)
	if local_player.global_position.distance_to(GATE_POINT) < 190.0:
		return TextCatalog.text("prompt_gate", current_language) if plant_restored else TextCatalog.text("prompt_gate_wait", current_language)
	return TextCatalog.text("controls", current_language)
