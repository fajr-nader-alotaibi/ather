extends Control
## Lightweight ambient motes for title screens.

var _rng := RandomNumberGenerator.new()
var _points: Array[Vector2] = []
var _phase: Array[float] = []
var _clock := 0.0
var _redraw := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	var count := 12 if GameSession.graphics_quality == "low" else 22
	for i in range(count):
		_points.append(Vector2(_rng.randf(), _rng.randf()))
		_phase.append(_rng.randf_range(0.0, TAU))

func _process(delta: float) -> void:
	_clock += delta
	_redraw -= delta
	if _redraw > 0.0:
		return
	_redraw = 0.05
	for i in range(_points.size()):
		_points[i].y -= delta * 0.007
		if _points[i].y < -0.02:
			_points[i] = Vector2(_rng.randf(), 1.02)
	queue_redraw()

func _draw() -> void:
	var bounds := size if size.x > 1.0 else get_viewport_rect().size
	for i in range(_points.size()):
		var p := _points[i] * bounds
		var pulse := 0.5 + 0.5 * sin(_clock * 1.6 + _phase[i])
		var color := Color("fff0a6")
		color.a = 0.18 + pulse * 0.32
		draw_circle(p, 2.0 + pulse * 1.8, color)
		if i % 4 == 0:
			var halo := Color("91f1d7", 0.09)
			draw_circle(p, 8.0 + pulse * 3.0, halo)
