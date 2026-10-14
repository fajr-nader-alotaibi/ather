extends Node2D
## Slow fireflies and pollen motes add a soft living glow without imported effects.

const WORLD_WIDTH := 3600.0
const WORLD_HEIGHT := 720.0
var _rng := RandomNumberGenerator.new()
var _positions: Array[Vector2] = []
var _phases: Array[float] = []
var _drifts: Array[float] = []
var _clock := 0.0
var _redraw_left := 0.0


func _ready() -> void:
	_rng.seed = 77331
	for index in range(74):
		_positions.append(Vector2(_rng.randf_range(30.0, WORLD_WIDTH - 30.0), _rng.randf_range(45.0, WORLD_HEIGHT - 40.0)))
		_phases.append(_rng.randf_range(0.0, TAU))
		_drifts.append(_rng.randf_range(-5.0, 8.0))
	z_index = -4


func _process(delta: float) -> void:
	_clock += delta
	_redraw_left -= delta
	if _redraw_left > 0.0:
		return
	_redraw_left = 0.075
	for index in range(_positions.size()):
		_positions[index].x += _drifts[index] * delta
		if _positions[index].x < 0.0:
			_positions[index].x = WORLD_WIDTH
		elif _positions[index].x > WORLD_WIDTH:
			_positions[index].x = 0.0
	queue_redraw()


func _draw() -> void:
	for index in range(_positions.size()):
		var point := _positions[index] + Vector2(0.0, sin(_clock * 0.7 + _phases[index]) * 7.0)
		var pulse := 0.48 + 0.42 * sin(_clock * 1.8 + _phases[index])
		var palette := [Color("b8f0c5"), Color("f6d894"), Color("9ce9e4")]
		var color: Color = palette[index % palette.size()]
		color.a = 0.12 + pulse * 0.12
		draw_circle(point, 8.0 + pulse * 2.0, color)
		color.a = 0.30 + pulse * 0.35
		draw_circle(point, 2.0 + pulse * 1.1, color)
		if index % 9 == 0:
			var glint := Color("fff2cc")
			glint.a = 0.18 + pulse * 0.35
			draw_line(point + Vector2(-5, 0), point + Vector2(5, 0), glint, 1.4, true)
			draw_line(point + Vector2(0, -5), point + Vector2(0, 5), glint, 1.4, true)
