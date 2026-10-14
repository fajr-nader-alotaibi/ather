extends Node2D
## Local guide follows the hero and points toward nearby goals.

var target: Node2D
var _clock := 0.0
var _art: Sprite2D
var _glow: PointLight2D


func _ready() -> void:
	_art = Sprite2D.new()
	_art.texture = load("res://assets/companion.svg")
	_art.scale = Vector2(0.62, 0.62)
	_art.z_index = 1
	add_child(_art)
	_glow = PointLight2D.new()
	_glow.texture = load("res://assets/glow.svg")
	_glow.color = Color("75e9d2")
	_glow.energy = 0.58
	_glow.texture_scale = 1.15
	add_child(_glow)


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	_clock += delta
	var target_point := target.global_position + Vector2(-48.0, -78.0 + sin(_clock * 2.8) * 10.0)
	global_position = global_position.lerp(target_point, minf(1.0, delta * 4.0))
	_art.rotation = sin(_clock * 2.0) * 0.06
	_glow.energy = 0.5 + sin(_clock * 2.1) * 0.08
	_art.scale = Vector2.ONE * (0.62 + sin(_clock * 3.3) * 0.018)

