extends CharacterBody2D
class_name AtharPlayer

signal interacted

@export var move_speed: float = 265.0
@export var jump_velocity: float = -555.0
@export var gravity: float = 1320.0
@export var acceleration: float = 1650.0
@export var friction: float = 1900.0

const COYOTE_DURATION: float = 0.13
const JUMP_BUFFER_DURATION: float = 0.14

var facing_direction: int = 1
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var animation_clock: float = 0.0

@onready var character_sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_add_action_keys("move_left", [KEY_A, KEY_LEFT])
	_add_action_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_action_keys("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_action_keys("interact", [KEY_E])
	_add_action_keys("pause", [KEY_ESCAPE])
	collision_layer = 1
	collision_mask = 1
	add_to_group("player")

func _add_action_keys(action_name: StringName, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for key_value in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key_value
		if not InputMap.action_has_event(action_name, key_event):
			InputMap.action_add_event(action_name, key_event)

func _physics_process(delta: float) -> void:
	animation_clock += delta
	var direction := Input.get_axis("move_left", "move_right")
	if absf(direction) > 0.01:
		velocity.x = move_toward(velocity.x, direction * move_speed, acceleration * delta)
		facing_direction = 1 if direction > 0.0 else -1
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if is_on_floor():
		coyote_timer = COYOTE_DURATION
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_DURATION
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
	elif not is_on_floor():
		velocity.y += gravity * delta
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	if Input.is_action_just_pressed("interact"):
		interacted.emit()

	move_and_slide()
	_push_crates(direction)
	_update_visuals(direction)

func _push_crates(direction: float) -> void:
	if absf(direction) < 0.05:
		return
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var other := collision.get_collider()
		if other is RigidBody2D and other.is_in_group("pushable"):
			other.apply_central_impulse(Vector2(direction * 42.0, -7.0))

func _update_visuals(direction: float) -> void:
	if absf(direction) > 0.05:
		character_sprite.flip_h = direction < 0.0
	var bob: float = 0.0
	if is_on_floor():
		if absf(velocity.x) > 12.0:
			bob = sin(animation_clock * 11.0) * 2.0
		else:
			bob = sin(animation_clock * 2.4) * 1.0
	character_sprite.position.y = -32.0 + bob
