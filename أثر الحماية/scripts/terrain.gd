extends StaticBody2D
## Hand-painted soil ledge; collision follows its moss-covered top edge.

@export var span := 400.0
@export var thickness := 68.0
@export var reclaimed := false


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(span, thickness)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(span * 0.5, thickness * 0.5)
	add_child(collision)
	queue_redraw()


func _draw() -> void:
	var soil := Color("745349") if not reclaimed else Color("796344")
	var deep_soil := Color("4c4140") if not reclaimed else Color("575249")
	var moss := Color("76945d") if not reclaimed else Color("b3ce76")
	var edge := Color("a8b86f") if not reclaimed else Color("e2d88c")
	var outline := Color("354448")
	var shape := PackedVector2Array([
		Vector2(0, 6), Vector2(10, 0), Vector2(span * 0.22, 3),
		Vector2(span * 0.48, 0), Vector2(span * 0.75, 5),
		Vector2(span - 9, 0), Vector2(span, 8), Vector2(span, thickness),
		Vector2(0, thickness)
	])
	draw_colored_polygon(shape, outline)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3, 10), Vector2(12, 5), Vector2(span * 0.22, 8),
		Vector2(span * 0.48, 5), Vector2(span * 0.75, 10),
		Vector2(span - 11, 5), Vector2(span - 3, 11),
		Vector2(span - 3, thickness - 3), Vector2(3, thickness - 3)
	]), soil)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, 39), Vector2(span * 0.19, 34), Vector2(span * 0.43, 42),
		Vector2(span * 0.7, 33), Vector2(span - 4, 39),
		Vector2(span - 4, thickness - 3), Vector2(4, thickness - 3)
	]), deep_soil)
	draw_colored_polygon(PackedVector2Array([
		Vector2(5, 8), Vector2(span * 0.2, 6), Vector2(span * 0.38, 11),
		Vector2(span * 0.61, 5), Vector2(span * 0.79, 10),
		Vector2(span - 5, 6), Vector2(span - 5, 18),
		Vector2(span * 0.77, 16), Vector2(span * 0.55, 20),
		Vector2(span * 0.31, 15), Vector2(5, 19)
	]), moss)
	draw_line(Vector2(5, 9), Vector2(span - 5, 9), edge, 3.0, true)
	for i in range(7, int(span) - 12, 32):
		var seed := sin(float(i) * 4.73) * 0.5 + 0.5
		var x := float(i)
		var y := 29.0 + seed * 20.0
		draw_circle(Vector2(x, y), 4.0 + seed * 2.0, Color("987366"))
		if i % 3 == 0:
			draw_line(Vector2(x, 7), Vector2(x - 3, 1 + seed * 3), Color("a9b976"), 2.0, true)
	if reclaimed:
		for i in range(34, int(span) - 20, 82):
			var x := float(i)
			draw_line(Vector2(x, 14), Vector2(x + 8, 2), Color("d7c889"), 2.0, true)
			draw_circle(Vector2(x + 8, 2), 3.0, Color("f6d58a"))

