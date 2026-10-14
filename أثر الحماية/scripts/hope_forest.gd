extends Node2D
## First playable slice: traverse, collect, restore the root bridge, and reach the lantern gate.

const TextCatalog = preload("res://scripts/localization.gd")

const WORLD_END := 3600.0
const SPAWN_POINT := Vector2(160, 572)
const PLANT_POINT := Vector2(2186, 544)
const GATE_POINT := Vector2(3370, 558)

@onready var player: CharacterBody2D = $Player
@onready var companion: Node2D = $Companion
@onready var hud: Control = $HUD/Interface
@onready var backdrop: Sprite2D = $Backdrop

var seed_count := 0
var plant_restored := false
var has_won := false
var _bridge: StaticBody2D
var _float_clock := 0.0
var _hud_refresh_left := 0.0
var _goal_hint := ""


func _ready() -> void:
	_setup_input_map()
	player.global_position = SPAWN_POINT
	player.connect("interact_requested", Callable(self, "_try_interact"))
	companion.set("target", player)
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = 0
	camera.limit_right = int(WORLD_END)
	camera.limit_top = 0
	camera.limit_bottom = 720
	create_terrain(0, 1110, 620)
	create_terrain(735, 1015, 524)
	create_terrain(1080, 1360, 620)
	create_terrain(1415, 1535, 554)
	create_terrain(1620, 1750, 520)
	create_terrain(1775, 2325, 620)
	create_terrain(2510, 2700, 505)
	create_terrain(2680, WORLD_END, 620)
	add_pickup(Vector2(505, 470))
	add_pickup(Vector2(928, 414))
	add_pickup(Vector2(1652, 438))
	hud.connect("pause_changed", Callable(self, "_on_pause_changed"))
	hud.connect("restart_requested", Callable(self, "_restart_level"))
	update_hud()


func _process(delta: float) -> void:
	_float_clock += delta
	_hud_refresh_left -= delta
	if player.global_position.y > 900.0:
		player.call("reset_to_spawn", SPAWN_POINT)
	if not has_won and _hud_refresh_left <= 0.0:
		_hud_refresh_left = 0.12
		update_hud()
	if plant_restored:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		hud.call("_on_pause_pressed")
		get_viewport().set_input_as_handled()


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


func add_pickup(point: Vector2) -> void:
	var pickup := load("res://scenes/seed_pickup.tscn").instantiate() as Area2D
	pickup.position = point
	pickup.connect("collected", Callable(self, "_on_seed_collected"))
	add_child(pickup)


func _on_seed_collected(pickup: Node2D) -> void:
	seed_count += 1
	pickup.queue_free()
	update_hud()


func _try_interact() -> void:
	if get_tree().paused or has_won:
		return
	if player.global_position.distance_to(PLANT_POINT) < 130.0 and not plant_restored:
		if seed_count < 3:
			_goal_hint = TextCatalog.text("need_seeds", str(hud.get("language")))
		else:
			_restore_grove()
		return
	if player.global_position.distance_to(GATE_POINT) < 135.0:
		if plant_restored:
			has_won = true
			var progress := ConfigFile.new()
			progress.set_value("progress", "hope_forest_complete", true)
			progress.save("user://athar_save.cfg")
			update_hud()
		else:
			_goal_hint = TextCatalog.text("bridge_first", str(hud.get("language")))


func _restore_grove() -> void:
	plant_restored = true
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
	if not plant_restored and player.global_position.distance_to(PLANT_POINT) < 180.0:
		return TextCatalog.text("prompt_plant", current_language) if seed_count >= 3 else TextCatalog.text("prompt_need", current_language)
	if player.global_position.distance_to(GATE_POINT) < 190.0:
		return TextCatalog.text("prompt_gate", current_language) if plant_restored else TextCatalog.text("prompt_gate_wait", current_language)
	return TextCatalog.text("controls", current_language)


func _on_pause_changed(is_paused: bool) -> void:
	get_tree().paused = is_paused


func _restart_level() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


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

