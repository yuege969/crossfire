extends CharacterBody2D

@export var speed: float = 400.0
@export var jump_velocity: float = -500.0
@export var gravity: float = 1200.0
@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.15

var _fire_timer: float = 0.0

func _physics_process(delta: float) -> void:
	_fire_timer -= delta
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Handle horizontal movement
	var direction := Input.get_axis("left", "right")
	velocity.x = direction * speed

	# Handle shooting
	if Input.is_action_pressed("shoot") and _fire_timer <= 0.0 and bullet_scene:
		_shoot()
		_fire_timer = fire_rate

	move_and_slide()

func _shoot() -> void:
	var bullet := bullet_scene.instantiate() as Area2D
	var mouse_pos := get_global_mouse_position()
	bullet.direction = (mouse_pos - global_position).normalized()
	bullet.global_position = global_position + bullet.direction * 20.0
	get_tree().current_scene.add_child(bullet)
