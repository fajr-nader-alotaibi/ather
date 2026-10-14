extends Node2D

const WORLD_WIDTH: float = 3000.0
const FLOOR_THICKNESS: float = 240.0
const SEEDS_REQUIRED: int = 3

@onready var player: AtharPlayer = $Player
@onready var companion: Node2D = $Companion
@onready var background: Sprite2D = $Background

var seed_nodes: Array[Area2D] = []
var seed_count: int = 0
var creature_rescued: bool = false
var rune_progress: int = 0
var rune_nodes: Array[Node2D] = []
var rune_icon_sprites: Array[Sprite2D] = []
var game_active: bool = false
var game_won: bool = false
var current_language: String = "ar"
var checkpoint_position: Vector2 = Vector2(120.0, 642.0)

var creature_node: Node2D
var restored_plant_node: Sprite2D
var crate_body: RigidBody2D
var gate_sprite: Sprite2D

var hud_layer: CanvasLayer
var hud_root: Control
var title_label: Label
var stats_label: Label
var objective_label: Label
var hint_label: Label
var language_button: Button
var pause_button: Button
var overlay: Control
var overlay_title: Label
var overlay_body: Label
var overlay_language_button: Button
var overlay_primary: Button
var overlay_secondary: Button
var overlay_tertiary: Button
var overlay_mode: String = "menu"
var last_hint: String = ""
var hint_lock_timer: float = 0.0

func _ready() -> void:
	_build_level()
	_build_hud()
	player.interacted.connect(_on_player_interacted)
	player.set_physics_process(false)
	player.set_process(false)
	companion.set_process(false)
	_refresh_hud()
	_show_overlay("menu")

func _process(delta: float) -> void:
	if not game_active:
		return
	# The distant forest drifts more slowly than the foreground to suggest depth.
	background.position.x = 1500.0 + (player.global_position.x - 120.0) * 0.35
	background.position.y = 450.0 + (player.global_position.y - 642.0) * 0.12
	if player.global_position.y > 980.0:
		player.global_position = checkpoint_position
		player.velocity = Vector2.ZERO
		_set_hint(_tr("fell_back"))
	if player.global_position.x > 1430.0 and player.is_on_floor():
		checkpoint_position = Vector2(1480.0, 642.0)
	if hint_lock_timer > 0.0:
		hint_lock_timer = maxf(hint_lock_timer - delta, 0.0)
	else:
		_update_interaction_hint()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if overlay.visible and overlay_mode == "pause":
			_resume_game()
		elif game_active:
			_show_overlay("pause")

func _build_level() -> void:
	# Safe ground and low, readable jumps for the first playable slice.
	_add_platform(0.0, 680.0, 540.0, FLOOR_THICKNESS)
	_add_platform(540.0, 650.0, 490.0, 270.0)
	_add_platform(1030.0, 620.0, 390.0, 280.0)
	_add_platform(1420.0, 680.0, 610.0, FLOOR_THICKNESS)
	_add_platform(2030.0, 640.0, 450.0, 280.0)
	_add_platform(2480.0, 680.0, 520.0, FLOOR_THICKNESS)
	# Raised stepping stones: optional shortcuts and safe places to collect seeds.
	_add_platform(955.0, 555.0, 155.0, 26.0)
	_add_platform(1870.0, 555.0, 150.0, 26.0)

	_add_prop("res://assets/glow_mushroom.png", Vector2(330, 646), 0.78, 2)
	_add_prop("res://assets/blue_crystal.png", Vector2(485, 650), 0.62, 2)
	_add_prop("res://assets/glow_mushroom.png", Vector2(730, 623), 0.62, 2)
	_add_prop("res://assets/blue_crystal.png", Vector2(1002, 527), 0.58, 2)
	_add_prop("res://assets/glow_mushroom.png", Vector2(1280, 590), 0.7, 2)
	_add_prop("res://assets/blue_crystal.png", Vector2(1505, 645), 0.72, 2)
	_add_prop("res://assets/glow_mushroom.png", Vector2(1790, 641), 0.9, 2)
	_add_prop("res://assets/blue_crystal.png", Vector2(1992, 527), 0.58, 2)
	_add_prop("res://assets/glow_mushroom.png", Vector2(2240, 609), 0.72, 2)
	_add_prop("res://assets/blue_crystal.png", Vector2(2580, 647), 0.68, 2)
	_add_prop("res://assets/glow_mushroom.png", Vector2(2710, 645), 0.82, 2)

	_create_seed(Vector2(405, 590))
	_create_seed(Vector2(1040, 490))
	_create_seed(Vector2(2200, 574))
	_create_crate(Vector2(850, 618))
	_create_rescue_creature(Vector2(1660, 655))
	_create_gate(Vector2(2860, 560))
	_create_runes()

func _add_platform(start_x: float, top_y: float, width: float, height: float) -> void:
	var body := StaticBody2D.new()
	body.name = "ForestPlatform"
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = Vector2(start_x + width * 0.5, top_y + height * 0.5)
	body.z_index = 1
	add_child(body)

	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(width, height)
	var collision := CollisionShape2D.new()
	collision.shape = rectangle
	body.add_child(collision)

	var dirt := Polygon2D.new()
	dirt.polygon = PackedVector2Array([
		Vector2(-width * 0.5, -height * 0.5),
		Vector2(width * 0.5, -height * 0.5),
		Vector2(width * 0.5, height * 0.5),
		Vector2(-width * 0.5, height * 0.5)
	])
	dirt.color = Color(0.24, 0.17, 0.29, 1.0)
	body.add_child(dirt)

	var soil_band := Polygon2D.new()
	soil_band.polygon = PackedVector2Array([
		Vector2(-width * 0.5, -height * 0.5 + 15.0),
		Vector2(width * 0.5, -height * 0.5 + 15.0),
		Vector2(width * 0.5, -height * 0.5 + 34.0),
		Vector2(-width * 0.5, -height * 0.5 + 34.0)
	])
	soil_band.color = Color(0.40, 0.23, 0.34, 1.0)
	body.add_child(soil_band)

	var grass := Polygon2D.new()
	grass.polygon = PackedVector2Array([
		Vector2(-width * 0.5, -height * 0.5 - 3.0),
		Vector2(width * 0.5, -height * 0.5 - 3.0),
		Vector2(width * 0.5, -height * 0.5 + 11.0),
		Vector2(-width * 0.5, -height * 0.5 + 11.0)
	])
	grass.color = Color(0.20, 0.46, 0.39, 1.0)
	body.add_child(grass)

	# Small irregular grass tips break the edge into a hand-made silhouette.
	for i in range(int(width / 34.0)):
		var blade_x := -width * 0.5 + 12.0 + float(i) * 34.0
		var blade := Polygon2D.new()
		blade.polygon = PackedVector2Array([
			Vector2(blade_x, -height * 0.5 + 8.0),
			Vector2(blade_x + 5.0, -height * 0.5 - 4.0),
			Vector2(blade_x + 9.0, -height * 0.5 + 8.0)
		])
		blade.color = Color(0.29, 0.60, 0.43, 1.0) if i % 2 == 0 else Color(0.17, 0.40, 0.36, 1.0)
		body.add_child(blade)

func _add_prop(texture_path: String, world_position: Vector2, scale_factor: float, draw_layer: int) -> Sprite2D:
	var prop := Sprite2D.new()
	prop.texture = load(texture_path) as Texture2D
	prop.position = world_position
	prop.scale = Vector2.ONE * scale_factor
	prop.z_index = draw_layer
	add_child(prop)
	return prop

func _create_seed(world_position: Vector2) -> void:
	var seed_area := Area2D.new()
	seed_area.name = "LuminousSeed"
	seed_area.position = world_position
	seed_area.collision_layer = 0
	seed_area.collision_mask = 1
	seed_area.set_meta("collected", false)
	seed_area.z_index = 7
	add_child(seed_area)

	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	collision.shape = circle
	seed_area.add_child(collision)

	var glow := Sprite2D.new()
	glow.texture = load("res://assets/seed.png") as Texture2D
	glow.scale = Vector2(0.9, 0.9)
	seed_area.add_child(glow)
	seed_area.body_entered.connect(_on_seed_body_entered.bind(seed_area))
	seed_nodes.append(seed_area)

func _create_crate(world_position: Vector2) -> void:
	crate_body = RigidBody2D.new()
	crate_body.name = "PushableWoodCrate"
	crate_body.position = world_position
	crate_body.mass = 2.0
	crate_body.collision_layer = 1
	crate_body.collision_mask = 1
	crate_body.linear_damp = 4.0
	crate_body.angular_damp = 8.0
	crate_body.add_to_group("pushable")
	crate_body.z_index = 4
	add_child(crate_body)

	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(54.0, 50.0)
	collision.shape = rectangle
	crate_body.add_child(collision)

	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/wood_crate.png") as Texture2D
	sprite.scale = Vector2(0.59, 0.59)
	crate_body.add_child(sprite)

func _create_rescue_creature(world_position: Vector2) -> void:
	creature_node = Node2D.new()
	creature_node.name = "ForestlingToRescue"
	creature_node.position = world_position
	creature_node.z_index = 5
	add_child(creature_node)

	var creature_sprite := Sprite2D.new()
	creature_sprite.texture = load("res://assets/forest_creature.png") as Texture2D
	creature_node.add_child(creature_sprite)

	restored_plant_node = Sprite2D.new()
	restored_plant_node.texture = load("res://assets/restored_plant.png") as Texture2D
	restored_plant_node.position = Vector2(0.0, -18.0)
	restored_plant_node.scale = Vector2(0.85, 0.85)
	restored_plant_node.z_index = 4
	restored_plant_node.visible = false
	add_child(restored_plant_node)
	restored_plant_node.global_position = world_position + Vector2(0.0, -18.0)


func _create_runes() -> void:
	var rune_textures: Array[String] = [
		"res://assets/rune_moon.png",
		"res://assets/rune_leaf.png",
		"res://assets/rune_star.png"
	]
	for index in range(rune_textures.size()):
		var altar := Node2D.new()
		altar.name = "RuneAltar_%d" % index
		altar.position = Vector2(2520.0 + float(index) * 95.0, 650.0)
		altar.z_index = 4
		add_child(altar)

		var pedestal := Polygon2D.new()
		pedestal.polygon = PackedVector2Array([
			Vector2(-23.0, 10.0), Vector2(-17.0, 1.0),
			Vector2(17.0, 1.0), Vector2(23.0, 10.0),
			Vector2(20.0, 29.0), Vector2(-20.0, 29.0)
		])
		pedestal.color = Color(0.22, 0.28, 0.43, 1.0)
		altar.add_child(pedestal)

		var rim := Polygon2D.new()
		rim.polygon = PackedVector2Array([
			Vector2(-18.0, 7.0), Vector2(18.0, 7.0),
			Vector2(16.0, 12.0), Vector2(-16.0, 12.0)
		])
		rim.color = Color(0.36, 0.55, 0.65, 1.0)
		altar.add_child(rim)

		var icon := Sprite2D.new()
		icon.texture = load(rune_textures[index]) as Texture2D
		icon.position = Vector2(0.0, -25.0)
		icon.scale = Vector2(0.78, 0.78)
		altar.add_child(icon)
		rune_nodes.append(altar)
		rune_icon_sprites.append(icon)

func _activate_rune(index: int) -> void:
	if seed_count < SEEDS_REQUIRED or not creature_rescued:
		_set_hint(_tr("runes_need_requirements"))
		return
	if index < rune_progress:
		_set_hint(_tr("rune_already"))
		return
	if index != rune_progress:
		_reset_runes()
		_set_hint(_tr("rune_wrong"))
		_refresh_hud()
		_update_gate_appearance()
		return

	rune_progress += 1
	rune_icon_sprites[index].modulate = Color(0.65, 1.0, 0.77, 1.0)
	if rune_progress >= 3:
		_set_hint(_tr("rune_done"))
	else:
		_set_hint(_tr("rune_next"))
	_refresh_hud()
	_update_gate_appearance()

func _reset_runes() -> void:
	rune_progress = 0
	for icon in rune_icon_sprites:
		icon.modulate = Color.WHITE

func _create_gate(world_position: Vector2) -> void:
	gate_sprite = Sprite2D.new()
	gate_sprite.name = "AncientForestGate"
	gate_sprite.texture = load("res://assets/ancient_gate.png") as Texture2D
	gate_sprite.position = world_position
	gate_sprite.z_index = 6
	add_child(gate_sprite)

func _on_seed_body_entered(body: Node2D, seed_area: Area2D) -> void:
	if body != player or bool(seed_area.get_meta("collected", false)):
		return
	seed_area.set_meta("collected", true)
	seed_area.visible = false
	seed_area.set_deferred("monitoring", false)
	seed_count += 1
	_set_hint(_tr("seed_found"))
	_update_gate_appearance()
	_refresh_hud()

func _on_player_interacted() -> void:
	if not game_active:
		return
	if not creature_rescued and player.global_position.distance_to(creature_node.global_position) < 125.0:
		creature_rescued = true
		creature_node.visible = false
		restored_plant_node.visible = true
		_set_hint(_tr("rescued_message"))
		_refresh_hud()
		_update_gate_appearance()
		return
	for index in range(rune_nodes.size()):
		if player.global_position.distance_to(rune_nodes[index].global_position) < 78.0:
			_activate_rune(index)
			return
	if player.global_position.distance_to(gate_sprite.global_position) < 165.0:
		if seed_count < SEEDS_REQUIRED or not creature_rescued:
			_set_hint(_tr("gate_locked"))
		elif rune_progress < 3:
			_set_hint(_tr("runes_need_requirements"))
		else:
			_win_game()
		return
	if player.global_position.distance_to(crate_body.global_position) < 98.0:
		crate_body.apply_central_impulse(Vector2(float(player.facing_direction) * 170.0, -20.0))
		_set_hint(_tr("crate_pushed"))
		return
	_set_hint(_tr("nothing_nearby"))

func _update_interaction_hint() -> void:
	var new_hint := _tr("default_hint")
	if not creature_rescued and player.global_position.distance_to(creature_node.global_position) < 145.0:
		new_hint = _tr("hint_creature")
	else:
		for index in range(rune_nodes.size()):
			if player.global_position.distance_to(rune_nodes[index].global_position) < 90.0:
				new_hint = _tr("hint_rune")
				break
		if new_hint == _tr("default_hint") and player.global_position.distance_to(gate_sprite.global_position) < 190.0:
			new_hint = _tr("hint_gate")
		elif new_hint == _tr("default_hint") and player.global_position.distance_to(crate_body.global_position) < 115.0:
			new_hint = _tr("hint_crate")
	_set_hint(new_hint)

func _set_hint(message: String) -> void:
	if hint_label == null or last_hint == message:
		return
	last_hint = message
	hint_label.text = message
	hint_lock_timer = 1.8

func _update_gate_appearance() -> void:
	if gate_sprite == null:
		return
	if seed_count >= SEEDS_REQUIRED and creature_rescued and rune_progress >= 3:
		gate_sprite.modulate = Color(0.72, 1.0, 0.91, 1.0)
	else:
		gate_sprite.modulate = Color.WHITE

func _win_game() -> void:
	game_active = false
	game_won = true
	player.set_physics_process(false)
	player.set_process(false)
	companion.set_process(false)
	_show_overlay("win")

func _restart_game() -> void:
	seed_count = 0
	creature_rescued = false
	_reset_runes()
	game_won = false
	last_hint = ""
	hint_lock_timer = 0.0
	checkpoint_position = Vector2(120.0, 642.0)
	player.global_position = Vector2(120.0, 642.0)
	player.velocity = Vector2.ZERO
	player.facing_direction = 1
	for seed_area in seed_nodes:
		seed_area.set_meta("collected", false)
		seed_area.visible = true
		seed_area.set_deferred("monitoring", true)
	creature_node.visible = true
	restored_plant_node.visible = false
	crate_body.freeze = true
	crate_body.global_position = Vector2(850.0, 618.0)
	crate_body.linear_velocity = Vector2.ZERO
	crate_body.angular_velocity = 0.0
	crate_body.rotation = 0.0
	crate_body.freeze = false
	_update_gate_appearance()
	_resume_game()
	_refresh_hud()

func _start_game() -> void:
	game_won = false
	game_active = true
	overlay.visible = false
	player.set_physics_process(true)
	player.set_process(true)
	companion.set_process(true)
	_refresh_hud()

func _resume_game() -> void:
	game_active = true
	overlay.visible = false
	player.set_physics_process(true)
	player.set_process(true)
	companion.set_process(true)
	_refresh_hud()

func _return_to_menu() -> void:
	_restart_game()
	_show_overlay("menu")

func _on_overlay_primary() -> void:
	match overlay_mode:
		"menu":
			_start_game()
		"pause":
			_resume_game()
		"win":
			_restart_game()

func _on_overlay_secondary() -> void:
	match overlay_mode:
		"pause":
			_restart_game()
		"win":
			_return_to_menu()

func _on_overlay_tertiary() -> void:
	if overlay_mode == "pause":
		_return_to_menu()

func _toggle_language() -> void:
	current_language = "en" if current_language == "ar" else "ar"
	last_hint = ""
	hint_lock_timer = 0.0
	_refresh_hud()
	_set_hint(_tr("default_hint"))
	if overlay.visible:
		_refresh_overlay_text()

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUD"
	add_child(hud_layer)
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(hud_root)

	var info_panel := PanelContainer.new()
	info_panel.position = Vector2(22.0, 20.0)
	info_panel.size = Vector2(380.0, 174.0)
	info_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.12, 0.88), Color(0.28, 0.66, 0.70, 0.9)))
	hud_root.add_child(info_panel)
	var info_stack := VBoxContainer.new()
	info_stack.add_theme_constant_override("separation", 4)
	info_panel.add_child(info_stack)

	title_label = _make_label("أثر | ATHAR", 24, Color(0.76, 0.98, 0.91, 1.0))
	info_stack.add_child(title_label)
	stats_label = _make_label("", 16, Color(0.92, 0.94, 1.0, 1.0))
	info_stack.add_child(stats_label)
	objective_label = _make_label("", 14, Color(0.76, 0.84, 0.94, 1.0))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_stack.add_child(objective_label)

	var bottom_panel := PanelContainer.new()
	bottom_panel.position = Vector2(235.0, 651.0)
	bottom_panel.size = Vector2(810.0, 48.0)
	bottom_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.035, 0.08, 0.84), Color(0.22, 0.49, 0.59, 0.75)))
	hud_root.add_child(bottom_panel)
	hint_label = _make_label("", 16, Color(0.90, 0.97, 1.0, 1.0))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom_panel.add_child(hint_label)

	language_button = _make_button("EN", Vector2(1100.0, 22.0), Vector2(70.0, 44.0))
	language_button.pressed.connect(_toggle_language)
	hud_root.add_child(language_button)
	pause_button = _make_button("Ⅱ", Vector2(1180.0, 22.0), Vector2(72.0, 44.0))
	pause_button.pressed.connect(func() -> void:
		if game_active:
			_show_overlay("pause")
	)
	hud_root.add_child(pause_button)

	overlay = Control.new()
	overlay.name = "ScreenOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	hud_layer.add_child(overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.035, 0.09, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(630.0, 455.0)
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.075, 0.15, 0.97), Color(0.30, 0.74, 0.75, 1.0)))
	center.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 15)
	card.add_child(stack)
	overlay_title = _make_label("ATHAR | أثر", 36, Color(0.76, 0.98, 0.91, 1.0))
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(overlay_title)
	overlay_body = _make_label("", 18, Color(0.86, 0.91, 1.0, 1.0))
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_body.custom_minimum_size = Vector2(500.0, 105.0)
	stack.add_child(overlay_body)
	overlay_language_button = _make_button("", Vector2.ZERO, Vector2(0.0, 38.0))
	overlay_language_button.custom_minimum_size = Vector2(150.0, 38.0)
	overlay_language_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	overlay_language_button.pressed.connect(_toggle_language)
	stack.add_child(overlay_language_button)
	overlay_primary = _make_button("", Vector2.ZERO, Vector2(0.0, 50.0))
	overlay_primary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	overlay_primary.custom_minimum_size = Vector2(300.0, 50.0)
	overlay_primary.pressed.connect(_on_overlay_primary)
	stack.add_child(overlay_primary)
	overlay_secondary = _make_button("", Vector2.ZERO, Vector2(0.0, 46.0))
	overlay_secondary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	overlay_secondary.custom_minimum_size = Vector2(260.0, 46.0)
	overlay_secondary.pressed.connect(_on_overlay_secondary)
	stack.add_child(overlay_secondary)
	overlay_tertiary = _make_button("", Vector2.ZERO, Vector2(0.0, 42.0))
	overlay_tertiary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	overlay_tertiary.custom_minimum_size = Vector2(220.0, 42.0)
	overlay_tertiary.pressed.connect(_on_overlay_tertiary)
	stack.add_child(overlay_tertiary)

func _show_overlay(mode: String) -> void:
	overlay_mode = mode
	overlay.visible = true
	if mode == "menu":
		game_active = false
		player.set_physics_process(false)
		player.set_process(false)
		companion.set_process(false)
	elif mode == "pause":
		game_active = false
		player.set_physics_process(false)
		player.set_process(false)
		companion.set_process(false)
	_refresh_overlay_text()

func _refresh_overlay_text() -> void:
	match overlay_mode:
		"menu":
			overlay_title.text = _tr("menu_title")
			overlay_body.text = _tr("menu_body")
			overlay_primary.text = _tr("start")
			overlay_secondary.visible = false
			overlay_tertiary.visible = false
		"pause":
			overlay_title.text = _tr("pause_title")
			overlay_body.text = _tr("pause_body")
			overlay_primary.text = _tr("resume")
			overlay_secondary.text = _tr("restart")
			overlay_tertiary.text = _tr("home")
			overlay_secondary.visible = true
			overlay_tertiary.visible = true
		"win":
			overlay_title.text = _tr("win_title")
			overlay_body.text = _tr("win_body")
			overlay_primary.text = _tr("play_again")
			overlay_secondary.text = _tr("home")
			overlay_tertiary.visible = false
	language_button.text = "EN" if current_language == "ar" else "عربي"
	overlay_language_button.text = "English" if current_language == "ar" else "العربية"

func _refresh_hud() -> void:
	if title_label == null:
		return
	title_label.text = _tr("title")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if current_language == "ar" else HORIZONTAL_ALIGNMENT_LEFT
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if current_language == "ar" else HORIZONTAL_ALIGNMENT_LEFT
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if current_language == "ar" else HORIZONTAL_ALIGNMENT_LEFT
	stats_label.text = _tr("stats_seeds") % [seed_count, SEEDS_REQUIRED]
	stats_label.text += "\n" + _tr("stats_creature") % (1 if creature_rescued else 0)
	stats_label.text += "\n" + _tr("stats_runes") % [rune_progress, 3]
	if seed_count >= SEEDS_REQUIRED and creature_rescued and rune_progress >= 3:
		objective_label.text = _tr("objective_done")
	elif seed_count >= SEEDS_REQUIRED and creature_rescued:
		objective_label.text = _tr("objective_runes")
	else:
		objective_label.text = _tr("objective")
	language_button.text = "EN" if current_language == "ar" else "عربي"
	if last_hint == "":
		hint_label.text = _tr("default_hint")
	else:
		# Keep the last event message, but let location hints update each frame after it fades naturally.
		hint_label.text = last_hint

func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.01, 0.02, 0.05, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _make_button(text_value: String, position_value: Vector2, size_value: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = position_value
	button.size = size_value
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(0.91, 0.99, 0.97, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.10, 0.22, 0.29, 0.97), Color(0.29, 0.70, 0.73, 0.9)))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.14, 0.32, 0.37, 1.0), Color(0.57, 0.91, 0.81, 1.0)))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.08, 0.17, 0.25, 1.0), Color(0.48, 0.80, 0.79, 1.0)))
	button.add_theme_stylebox_override("focus", _panel_style(Color(0.12, 0.25, 0.32, 1.0), Color(0.72, 0.95, 0.82, 1.0)))
	return button

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func _tr(key: String) -> String:
	var dictionary: Dictionary = {
		"title": {"ar": "أثر | حُرّاس الطبيعة", "en": "ATHAR | Guardians of Nature"},
		"stats_seeds": {"ar": "البذور النورانية: %d / %d", "en": "Light seeds: %d / %d"},
		"stats_creature": {"ar": "الكائن المُنقذ: %d / 1", "en": "Forestling rescued: %d / 1"},
		"stats_runes": {"ar": "الرموز: %d / 3", "en": "Runes: %d / 3"},
		"objective": {"ar": "الهدف: اجمعي 3 بذور وأنقذي كائن الغابة.", "en": "Goal: Collect 3 seeds and rescue the forestling."},
		"objective_runes": {"ar": "فعّلي الرموز بالترتيب: القمر، الورقة، النجمة.", "en": "Activate the runes in order: Moon, Leaf, Star."},
		"objective_done": {"ar": "اكتمل الهدف! اقتربي من البوابة واضغطي E.", "en": "Objective complete! Reach the gate and press E."},
		"default_hint": {"ar": "A / D حركة  •  Space قفز  •  E تفاعل  •  Esc إيقاف", "en": "A / D Move  •  Space Jump  •  E Interact  •  Esc Pause"},
		"hint_creature": {"ar": "اضغطي E لمساعدة كائن الغابة", "en": "Press E to rescue the forestling"},
		"hint_gate": {"ar": "اضغطي E لفحص البوابة القديمة", "en": "Press E to inspect the ancient gate"},
		"hint_crate": {"ar": "اضغطي E أو ادفعي الصندوق ليتحرك", "en": "Press E or walk into the crate to push it"},
		"hint_rune": {"ar": "اضغطي E على الرمز. الترتيب: القمر ثم الورقة ثم النجمة.", "en": "Press E at a rune. Order: Moon, Leaf, Star."},
		"runes_need_requirements": {"ar": "تحتاج الرموز إلى البذور الثلاث وإنقاذ كائن الغابة أولًا.", "en": "Collect all 3 seeds and rescue the forestling before activating the runes."},
		"rune_next": {"ar": "أضاء الرمز! تابعي بالترتيب: القمر، الورقة، النجمة.", "en": "Rune lit! Continue in order: Moon, Leaf, Star."},
		"rune_done": {"ar": "اكتمل ترتيب الرموز! عادت البوابة إلى الحياة.", "en": "Rune sequence complete! The gate awakens."},
		"rune_wrong": {"ar": "الترتيب غير صحيح. أعيدت الرموز؛ ابدئي بالقمر.", "en": "Wrong order. The runes reset; begin with the Moon."},
		"rune_already": {"ar": "هذا الرمز مضاء بالفعل.", "en": "That rune is already lit."},
		"seed_found": {"ar": "وجدتِ بذرة نورانية!", "en": "A light seed found!"},
		"rescued_message": {"ar": "عاد النور إلى كائن الغابة. أحسنتِ!", "en": "The forestling is safe. Nature is brighter!"},
		"crate_pushed": {"ar": "تحرّك الصندوق قليلًا.", "en": "You pushed the crate."},
		"gate_locked": {"ar": "البوابة مغلقة. اجمعي البذور الثلاث وأنقذي كائن الغابة.", "en": "The gate is sealed. Collect all 3 seeds and rescue the forestling."},
		"nothing_nearby": {"ar": "لا يوجد شيء يحتاج إلى تفاعل هنا.", "en": "Nothing nearby needs your help."},
		"fell_back": {"ar": "أعادتك الغابة إلى آخر مكان آمن.", "en": "The forest brought you back to safety."},
		"menu_title": {"ar": "أَثَر | ATHAR", "en": "ATHAR | أثر"},
		"menu_body": {"ar": "غابة الأمل — نموذج لعب قابل للتجربة\nاجمعي 3 بذور وأنقذي كائن الغابة، ثم فعّلي الرموز بالترتيب: القمر، الورقة، النجمة.\n\nA / D أو الأسهم للحركة  •  Space للقفز  •  E للتفاعل", "en": "Forest of Hope — playable prototype\nCollect 3 seeds and rescue the forestling, then activate the runes in order: Moon, Leaf, Star.\n\nA / D or arrows to move  •  Space to jump  •  E to interact"},
		"start": {"ar": "ابدئي الرحلة", "en": "Begin Journey"},
		"pause_title": {"ar": "استراحة قصيرة", "en": "Journey Paused"},
		"pause_body": {"ar": "خذي لحظة، فالغابة بانتظارك.", "en": "Take a breath. The forest will be here."},
		"resume": {"ar": "متابعة الرحلة", "en": "Resume"},
		"restart": {"ar": "إعادة المرحلة", "en": "Restart Stage"},
		"home": {"ar": "العودة للقائمة", "en": "Main Menu"},
		"win_title": {"ar": "عاد النور إلى الغابة!", "en": "The Forest Remembers Its Light"},
		"win_body": {"ar": "أنجزتِ نموذج غابة الأمل.\nكل أثر صغير يصنع فرقًا.\n\nهذه بداية ATHAR، وليست اللعبة الكاملة بعد.", "en": "You completed the Forest of Hope prototype.\nEvery small act leaves a meaningful trace.\n\nThis is the first playable slice of ATHAR."},
		"play_again": {"ar": "اللعب من جديد", "en": "Play Again"}
	}
	if not dictionary.has(key):
		return key
	return str(dictionary[key].get(current_language, dictionary[key].get("en", key)))
