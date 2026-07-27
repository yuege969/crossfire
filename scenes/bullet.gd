extends Area2D

@export var speed: float = 600.0
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var _grace_period: float = 0.05

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

	_grace_period -= delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(_body: Node2D) -> void:
	if _grace_period > 0.0:
		return
	queue_free()
