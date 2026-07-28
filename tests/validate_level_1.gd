extends SceneTree

const LEVEL_PATH := "res://scenes/levels/level_1.tscn"
const REQUIRED_LAYERS := [
	"Layers/BGLayer",
	"Layers/BGDetailLayer",
	"Layers/CollisionLayer",
	"Layers/FGLayer",
]

var failures: Array[String] = []


func _initialize() -> void:
	var packed := load(LEVEL_PATH) as PackedScene
	_expect(packed != null, "Level1 scene must load")
	if packed == null:
		_finish()
		return

	var level := packed.instantiate()
	root.add_child(level)

	var shared_tile_set: TileSet
	for path in REQUIRED_LAYERS:
		var layer := level.get_node_or_null(path) as TileMapLayer
		_expect(layer != null, "%s must be a TileMapLayer" % path)
		if layer == null:
			continue
		_expect(layer.tile_set != null, "%s must have a TileSet" % path)
		_expect(layer.get_used_cells().size() > 0, "%s must contain cells" % path)
		if shared_tile_set == null:
			shared_tile_set = layer.tile_set
		else:
			_expect(layer.tile_set == shared_tile_set, "%s must share the level TileSet" % path)

	var collision := level.get_node_or_null("Layers/CollisionLayer") as TileMapLayer
	if collision and collision.tile_set:
		_expect(
			collision.tile_set.get_physics_layers_count() == 1,
			"TileSet must contain exactly one physics layer"
		)
		_expect(
			collision.get_used_rect().size.x >= 240,
			"Collision route must span at least six camera screens"
		)
		_expect(
			collision.get_used_rect().end.y <= 30,
			"Collision geometry must stay inside the 30-row level"
		)

	var player := level.get_node_or_null("Entities/Player") as CharacterBody2D
	var level_exit := level.get_node_or_null("Entities/LevelExit") as Marker2D
	_expect(player != null, "Player must exist under Entities")
	_expect(level_exit != null, "LevelExit marker must exist")
	_expect(level.get_node_or_null("bullets") != null, "bullets container must be preserved")
	if player:
		_expect(player.position == Vector2(72, 336), "Player must use the safe spawn position")
	if level_exit:
		_expect(level_exit.position == Vector2(4024, 320), "LevelExit must mark the final platform")

	level.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("Level 1 validation passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
