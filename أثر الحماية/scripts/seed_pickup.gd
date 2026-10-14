extends Area2D
signal collected(pickup: Node2D)

var _clock := 0.0
@onready var _art: Sprite2D = $Art


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_clock += delta
	_art.position.y = sin(_clock * 2.6) * 5.0
	_art.rotation = sin(_clock * 1.7) * 0.08


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collected.emit(self)

