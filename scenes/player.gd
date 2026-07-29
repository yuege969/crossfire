extends CharacterBody2D

@export var speed: float = 400.0
@export var jump_velocity: float = -500.0
@export var gravity: float = 1200.0
@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.15
@export var marker_distance: float = 40.0

var _fire_timer: float = 0.0
@onready var _legs_sprite: Sprite2D = $Legs
@onready var _legs_anim: AnimationPlayer = $Legs/AnimationPlayer
@onready var _torso_sprite: Sprite2D = $Torso
@onready var _marker: Sprite2D = $Marker

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
	_update_animation(direction)
	_update_torso_direction()
	_update_marker()

func _update_animation(direction: float) -> void:
	if direction < 0.0:
		_legs_sprite.flip_h = true
	elif direction > 0.0:
		_legs_sprite.flip_h = false

	if not is_on_floor():
		_legs_anim.play("jump")
	elif direction != 0.0:
		_legs_anim.play("run")
	else:
		_legs_anim.play("idle")

func _shoot() -> void:
	var bullet := bullet_scene.instantiate() as Area2D
	var mouse_pos := get_global_mouse_position()
	var angle := (mouse_pos - global_position).angle()
	if angle < 0:
		angle += 2 * PI
	# Snap to 8 directions (same as torso facing)
	var snapped_angle := float(roundi(angle / (PI / 4.0)) % 8) * (PI / 4.0)
	bullet.direction = Vector2(cos(snapped_angle), sin(snapped_angle))
	bullet.global_position = global_position + bullet.direction * 20.0
	get_tree().current_scene.add_child(bullet)

	# Marker scale pop feedback
	var tween := create_tween()
	tween.tween_property(_marker, "scale", Vector2(0.3, 0.3), 0.05)
	tween.tween_property(_marker, "scale", Vector2(0.5, 0.5), 0.1).set_ease(Tween.EASE_OUT)

func _update_torso_direction() -> void:
	var mouse_pos := get_global_mouse_position()
	var angle := (mouse_pos - global_position).angle()
	# Normalize angle from [-PI, PI] to [0, 2*PI)
	if angle < 0:
		angle += 2 * PI
	# 8 directions, frame 0 = right (0°), each frame rotates 45° clockwise
	# Frame mapping: 0→, 1↘, 2↓, 3↙, 4←, 5↖, 6↑, 7↗
	var frame := roundi(angle / (PI / 4.0)) % 8
	_torso_sprite.frame = frame

func _update_marker() -> void:
	var mouse_pos := get_global_mouse_position()
	var angle := (mouse_pos - global_position).angle()
	if angle < 0:
		angle += 2 * PI
	var dir_index := roundi(angle / (PI / 4.0)) % 8
	var angle_snapped := float(dir_index) * PI / 4.0
	var direction := Vector2(cos(angle_snapped), sin(angle_snapped))
	_marker.global_position = global_position + direction * marker_distance


func _ready() -> void:
	add_to_group("player")


func die() -> void:
	set_process(false)
	set_physics_process(false)
	hide()
	var ui: Node = load("res://scenes/game_over_ui.tscn").instantiate()
	get_tree().current_scene.add_child(ui)


func freeze() -> void:
	set_physics_process(false)
	set_process(false)
