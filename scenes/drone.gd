extends CharacterBody2D

@export var speed: float = 150.0
@export var chain_radius: float = 50.0
@export var chain_delay: float = 0.15
@export var max_chain_depth: int = 3

enum State { IDLE, CHASE, DYING }
var state: State = State.IDLE
var _player: CharacterBody2D = null
var _hit_player: bool = false
var _stored_player: CharacterBody2D = null

@onready var _detection_area: Area2D = $DetctionArea
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("drone")
	_detection_area.body_entered.connect(_on_detection_body_entered)
	_detection_area.body_exited.connect(_on_detection_body_exited)
	_animated_sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(_delta: float) -> void:
	match state:
		State.IDLE:
			pass
		State.CHASE:
			if _player:
				var direction := (_player.global_position - global_position).normalized()
				velocity = direction * speed
				move_and_slide()

				for i in get_slide_collision_count():
					var collider := get_slide_collision(i).get_collider()
					if collider.is_in_group("player"):
						_on_hit_player(collider)
		State.DYING:
			pass


func _on_detection_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if state == State.DYING:
		return
	if state == State.IDLE or (state == State.CHASE and _player == null):
		_player = body
		state = State.CHASE


func _on_detection_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null


func on_hit_by_bullet() -> void:
	if state == State.DYING:
		return
	state = State.DYING
	_collision_shape.set_deferred("disabled", true)
	_detection_area.set_deferred("monitoring", false)
	_animated_sprite.play("die")


func trigger_chain_explosion(chain_depth: int) -> void:
	if state == State.DYING:
		return

	state = State.DYING
	_collision_shape.set_deferred("disabled", true)
	_detection_area.set_deferred("monitoring", false)
	_animated_sprite.play("die")

	if chain_depth < max_chain_depth:
		await get_tree().create_timer(chain_delay).timeout
		_trigger_nearby_drones(chain_depth)


func _trigger_nearby_drones(chain_depth: int) -> void:
	var drones: Array[Node] = get_tree().get_nodes_in_group("Drones")
	for drone in drones:
		if drone == self:
			continue
		if not drone is CharacterBody2D:
			continue
		if drone.state == State.DYING:
			continue
		var distance := global_position.distance_to(drone.global_position)
		if distance <= chain_radius:
			drone.trigger_chain_explosion(chain_depth + 1)


func _on_animation_finished() -> void:
	if _animated_sprite.animation == "die":
		if _hit_player and _stored_player and _stored_player.has_method("die"):
			_stored_player.die()
		queue_free()


func _on_hit_player(p: Node2D) -> void:
	if state == State.DYING:
		return
	_stored_player = p
	_hit_player = true
	state = State.DYING
	_collision_shape.set_deferred("disabled", true)
	_detection_area.set_deferred("monitoring", false)
	_animated_sprite.play("die")
	if p.has_method("freeze"):
		p.freeze()
