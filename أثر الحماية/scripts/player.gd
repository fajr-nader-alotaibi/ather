extends CharacterBody2D
## Responsive 2D platform movement with a short coyote window and jump buffer.

signal interact_requested

@export var run_speed := 300.0
@export var ground_acceleration := 1900.0
@export var air_acceleration := 1250.0
@export var gravity := 1750.0
@export var jump_velocity := -650.0
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.13

var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _facing := 1
var _bob_clock := 0.0

@onready var _art: Sprite2D = $Art


func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 14.0
	floor_max_angle = 0.82
	floor_stop_on_slope = true


func _physics_process(delta: float) -> void:
	_bob_clock += delta
	if is_on_floor():
		_coyote_left = coyote_time
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_left = jump_buffer_time
	else:
		_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)

	if Input.is_action_just_pressed("interact"):
		interact_requested.emit()

	var axis := Input.get_axis("move_left", "move_right")
	if absf(axis) > 0.05:
		_facing = 1 if axis > 0.0 else -1
		_art.flip_h = _facing < 0
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, axis * run_speed, acceleration * delta)
	if absf(axis) < 0.05 and is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, ground_acceleration * 0.72 * delta)

	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
	elif not is_on_floor():
		velocity.y += gravity * delta

	# Releasing jump trims the arc, making small hops easier on touch screens.
	if not Input.is_action_pressed("jump") and velocity.y < -240.0:
		velocity.y += gravity * delta * 0.8

	move_and_slide()
	_art.position.y = -13.0 + (sin(_bob_clock * 8.0) * 2.0 if is_on_floor() and absf(axis) > 0.1 else 0.0)


func reset_to_spawn(spawn_point: Vector2) -> void:
	global_position = spawn_point
	velocity = Vector2.ZERO
	_coyote_left = 0.0
	_jump_buffer_left = 0.0

