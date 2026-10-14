extends CharacterBody2D
## Responsive platform movement with buffered/coyote jump and true pose-based sprite animation.

signal interact_requested
signal double_jump_triggered(at: Vector2)

const CharacterLibrary = preload("res://scripts/character_library.gd")

@export var run_speed := 300.0
@export var ground_acceleration := 1900.0
@export var air_acceleration := 1250.0
@export var gravity := 1750.0
@export var jump_velocity := -650.0
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.13

var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _jump_count := 0
var _facing := 1
var _bob_clock := 0.0
var _spin_elapsed := -1.0
var _double_jump_pose_left := 0.0
var _spin_direction := 1
var _landing_squash := 0.0
var _state_send_left := 0.0
var _net_target := Vector2.ZERO
var _net_velocity := Vector2.ZERO
var _remote_facing := 1
var _remote_avatar_code := -1
var _avatar_code := 0
var _was_airborne := false
var _interaction_left := 0.0
var _landing_left := 0.0
var _animation_name := ""

@onready var _art: AnimatedSprite2D = $Art


func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 14.0
	floor_max_angle = 0.82
	floor_stop_on_slope = true
	_net_target = global_position
	_apply_difficulty()
	_set_avatar(GameSession.current_avatar_code())
	_create_name_tag()


func _apply_difficulty() -> void:
	var selected := str(GameSession.game_settings.get("difficulty", GameSession.difficulty))
	match selected:
		"easy":
			run_speed = 310.0
			jump_velocity = -710.0
			gravity = 1650.0
		"hard":
			run_speed = 290.0
			jump_velocity = -610.0
			gravity = 1880.0
		_:
			run_speed = 300.0
			jump_velocity = -650.0
			gravity = 1750.0


func _create_name_tag() -> void:
	var tag := Label.new()
	tag.name = "NameTag"
	tag.position = Vector2(-80, -94)
	tag.size = Vector2(160, 24)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.text = GameSession.name_for_peer(get_multiplayer_authority())
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", Color("fff1c7"))
	tag.add_theme_color_override("font_outline_color", Color("173432"))
	tag.add_theme_constant_override("outline_size", 4)
	add_child(tag)


func configure_avatar(avatar_code: int, display_name: String) -> void:
	_set_avatar(avatar_code)
	var tag := get_node_or_null("NameTag") as Label
	if is_instance_valid(tag):
		tag.text = display_name


func get_avatar_code() -> int:
	return _avatar_code


func _set_avatar(avatar_code: int) -> void:
	_avatar_code = clampi(avatar_code, 0, 11)
	CharacterLibrary.configure_sprite(_art, floori(float(_avatar_code) / 6.0), _avatar_code % 6)
	_art.position = Vector2(0.0, -15.0)
	_art.scale = Vector2(0.55, 0.55)
	_animation_name = ""
	_play_animation("idle")


func _physics_process(delta: float) -> void:
	var is_local := not GameSession.is_networked or get_multiplayer_authority() == multiplayer.get_unique_id()
	if not is_local:
		global_position = global_position.lerp(_net_target, minf(1.0, delta * 13.0))
		velocity = _net_velocity
		_art.flip_h = _remote_facing < 0
		if _remote_avatar_code >= 0 and _remote_avatar_code != _avatar_code:
			_set_avatar(_remote_avatar_code)
		_update_animation(_net_velocity.x, _net_velocity.y, absf(_net_velocity.y) < 4.0, delta)
		return

	_bob_clock += delta
	_interaction_left = maxf(0.0, _interaction_left - delta)
	_landing_left = maxf(0.0, _landing_left - delta)
	_double_jump_pose_left = maxf(0.0, _double_jump_pose_left - delta)
	var grounded_before := is_on_floor()
	if grounded_before:
		_coyote_left = coyote_time
		_jump_count = 0
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_left = jump_buffer_time
	else:
		_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)

	if Input.is_action_just_pressed("interact"):
		_interaction_left = 0.34
		interact_requested.emit()

	var axis := Input.get_axis("move_left", "move_right")
	if absf(axis) > 0.05:
		_facing = 1 if axis > 0.0 else -1
		_art.flip_h = _facing < 0
	var acceleration := ground_acceleration if grounded_before else air_acceleration
	velocity.x = move_toward(velocity.x, axis * run_speed, acceleration * delta)
	if absf(axis) < 0.05 and grounded_before:
		velocity.x = move_toward(velocity.x, 0.0, ground_acceleration * 0.72 * delta)

	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		_start_jump(false)
	elif _jump_buffer_left > 0.0 and not grounded_before and _jump_count < 2:
		_start_jump(true)
	elif not grounded_before:
		velocity.y += gravity * delta

	# Releasing jump trims the arc, making short hops easier on touch screens.
	if not Input.is_action_pressed("jump") and velocity.y < -240.0:
		velocity.y += gravity * delta * 0.8

	_was_airborne = not grounded_before
	move_and_slide()
	if is_on_floor():
		if _was_airborne:
			_landing_squash = 0.13
			_landing_left = 0.22
			_spin_elapsed = -1.0
			_art.rotation = 0.0
		_jump_count = 0
	_landing_squash = maxf(0.0, _landing_squash - delta)

	if _spin_elapsed >= 0.0:
		_spin_elapsed += delta
		var spin_duration := 0.42
		if _spin_elapsed >= spin_duration:
			_spin_elapsed = -1.0
			_art.rotation = 0.0
		else:
			_art.rotation = float(_spin_direction) * TAU * (_spin_elapsed / spin_duration)
	elif not is_on_floor():
		_art.rotation = move_toward(_art.rotation, float(_facing) * -0.06, delta * 1.5)
	else:
		_art.rotation = move_toward(_art.rotation, 0.0, delta * 2.5)

	var bob := sin(_bob_clock * 9.0) * 2.0 if is_on_floor() and absf(axis) > 0.1 else 0.0
	_art.position.y = -15.0 + bob
	var stretch := 0.0
	if velocity.y < -100.0:
		stretch = 0.08
	elif velocity.y > 180.0:
		stretch = -0.04
	if _landing_squash > 0.0:
		stretch = -0.14 * (_landing_squash / 0.13)
	_art.scale = Vector2(0.55 * (1.0 - stretch * 0.45), 0.55 * (1.0 + stretch))
	_update_animation(axis * run_speed, velocity.y, is_on_floor(), delta)

	_state_send_left -= delta
	if GameSession.is_networked and _state_send_left <= 0.0:
		_state_send_left = 0.06
		GameSession.send_player_state(get_multiplayer_authority(), global_position, velocity, _facing, _avatar_code)


func _update_animation(horizontal_speed: float, vertical_speed: float, grounded: bool, _delta: float) -> void:
	var next := "idle"
	if _interaction_left > 0.0:
		next = "interact"
	elif grounded and _landing_left > 0.0:
		next = "land"
	elif not grounded and _double_jump_pose_left > 0.0:
		next = "double_jump"
	elif not grounded and _spin_elapsed >= 0.0:
		next = "air_spin"
	elif not grounded and vertical_speed < -35.0:
		next = "jump"
	elif not grounded:
		next = "fall"
	elif absf(horizontal_speed) > run_speed * 0.72:
		next = "run"
	elif absf(horizontal_speed) > 18.0:
		next = "walk"
	_play_animation(next)


func _play_animation(next: String) -> void:
	if _animation_name == next:
		return
	_animation_name = next
	if _art.sprite_frames != null and _art.sprite_frames.has_animation(next):
		_art.play(next)
	else:
		_art.play("idle")


func _start_jump(is_double: bool) -> void:
	velocity.y = jump_velocity * (0.92 if is_double else 1.0)
	_jump_buffer_left = 0.0
	_coyote_left = 0.0
	_landing_left = 0.0
	_jump_count = 2 if is_double else 1
	if is_double:
		_spin_elapsed = 0.0
		_double_jump_pose_left = 0.18
		_spin_direction = _facing
		double_jump_triggered.emit(global_position + Vector2(0, -35))


func receive_network_state(position: Vector2, new_velocity: Vector2, facing: int, avatar_code: int) -> void:
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		return
	_net_target = position
	_net_velocity = new_velocity
	_remote_facing = facing
	_remote_avatar_code = avatar_code


func reset_to_spawn(spawn_point: Vector2) -> void:
	global_position = spawn_point
	_net_target = spawn_point
	velocity = Vector2.ZERO
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_jump_count = 0
	_spin_elapsed = -1.0
	_double_jump_pose_left = 0.0
	_interaction_left = 0.0
	_landing_left = 0.0
	_landing_squash = 0.0
	_was_airborne = false
	_facing = 1
	_art.flip_h = false
	_art.rotation = 0.0
	_art.position = Vector2(0.0, -15.0)
	_art.scale = Vector2(0.55, 0.55)
	_play_animation("idle")
