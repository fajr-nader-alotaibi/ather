extends Node2D

@export var target_path: NodePath
@export var follow_distance: Vector2 = Vector2(-52.0, -72.0)
@export var follow_smoothing: float = 4.5

var target: Node2D
var float_clock: float = 0.0

func _ready() -> void:
	target = get_node_or_null(target_path) as Node2D

func _process(delta: float) -> void:
	if target == null:
		return
	float_clock += delta
	var side: float = follow_distance.x
	var player_target := target as AtharPlayer
	if player_target != null:
		side = -52.0 * float(player_target.facing_direction)
	var destination: Vector2 = target.global_position + Vector2(side, follow_distance.y + sin(float_clock * 2.6) * 7.0)
	global_position = global_position.lerp(destination, 1.0 - exp(-follow_smoothing * delta))
	rotation = sin(float_clock * 1.8) * 0.035
