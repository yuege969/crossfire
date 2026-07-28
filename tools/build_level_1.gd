extends SceneTree

const LEVEL_PATH := "res://scenes/levels/level_1.tscn"
const LEVEL_UID_TEXT := "uid://dijfid84ad4nx"
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const SUBWAY_TEXTURE := preload("res://graphics/tilesets/subway.png")
const WALLS_TEXTURE := preload("res://graphics/tilesets/walls.png")

const TILE_SIZE := Vector2i(16, 16)
const MAP_SIZE := Vector2i(256, 30)
const SOURCE_SUBWAY := 0
const SOURCE_WALLS := 1
const GROUND_TILE := Vector2i(0, 0)
const WALL_FILL_TILE := Vector2i(26, 4)


func _initialize() -> void:
	var level := _build_level()
	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(level)
	if pack_error != OK:
		push_error("Failed to pack Level 1: %s" % error_string(pack_error))
		quit(1)
		return

	var save_error := ResourceSaver.save(packed_scene, LEVEL_PATH)
	if save_error != OK:
		push_error("Failed to save Level 1: %s" % error_string(save_error))
		level.free()
		quit(1)
		return
	var uid_error := ResourceSaver.set_uid(LEVEL_PATH, ResourceUID.text_to_id(LEVEL_UID_TEXT))
	if uid_error != OK:
		push_error("Failed to restore Level 1 UID: %s" % error_string(uid_error))
		level.free()
		quit(1)
		return
	var sanitize_error := _strip_volatile_node_ids()
	if sanitize_error != OK:
		push_error("Failed to stabilize Level 1 node IDs: %s" % error_string(sanitize_error))
		level.free()
		quit(1)
		return

	print("Built %s" % LEVEL_PATH)
	level.free()
	quit(0)


func _strip_volatile_node_ids() -> Error:
	var read_file := FileAccess.open(LEVEL_PATH, FileAccess.READ)
	if read_file == null:
		return FileAccess.get_open_error()
	var scene_source := read_file.get_as_text()
	read_file.close()

	var volatile_id_pattern := RegEx.new()
	var compile_error := volatile_id_pattern.compile(" unique_id=\\d+")
	if compile_error != OK:
		return compile_error
	scene_source = volatile_id_pattern.sub(scene_source, "", true)

	var write_file := FileAccess.open(LEVEL_PATH, FileAccess.WRITE)
	if write_file == null:
		return FileAccess.get_open_error()
	write_file.store_string(scene_source)
	write_file.close()
	return OK


func _build_level() -> Node2D:
	var tile_set := _build_tile_set()

	var level := Node2D.new()
	level.name = "Level1"

	var layers := Node2D.new()
	layers.name = "Layers"
	level.add_child(layers)
	layers.owner = level

	var background := _create_layer("BGLayer", tile_set, -20, false)
	var background_detail := _create_layer("BGDetailLayer", tile_set, -10, false)
	var collision := _create_layer("CollisionLayer", tile_set, 0, true)
	var foreground := _create_layer("FGLayer", tile_set, 20, false)
	for layer in [background, background_detail, collision, foreground]:
		layers.add_child(layer)
		layer.owner = level

	_build_background(background)
	_build_background_details(background_detail)
	_build_collision_route(collision)
	_build_foreground(foreground)

	var entities := Node2D.new()
	entities.name = "Entities"
	entities.z_index = 10
	level.add_child(entities)
	entities.owner = level

	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.name = "Player"
	player.position = Vector2(72, 336)
	entities.add_child(player)
	player.owner = level
	level.set_editable_instance(player, true)
	_configure_player_camera(player)

	var level_exit := Marker2D.new()
	level_exit.name = "LevelExit"
	level_exit.position = Vector2(3720, 320)
	entities.add_child(level_exit)
	level_exit.owner = level

	var bullets := Node2D.new()
	bullets.name = "bullets"
	level.add_child(bullets)
	bullets.owner = level

	return level


func _build_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 1)

	var subway_source := _create_atlas_source(SUBWAY_TEXTURE, Vector2i(25, 25))
	var walls_source := _create_atlas_source(WALLS_TEXTURE, Vector2i(35, 43))
	tile_set.add_source(subway_source, SOURCE_SUBWAY)
	tile_set.add_source(walls_source, SOURCE_WALLS)

	var ground_data := walls_source.get_tile_data(GROUND_TILE, 0)
	ground_data.add_collision_polygon(0)
	ground_data.set_collision_polygon_points(
		0,
		0,
		PackedVector2Array([
			Vector2(-8, -8),
			Vector2(8, -8),
			Vector2(8, 8),
			Vector2(-8, 8),
		])
	)

	return tile_set


func _create_atlas_source(texture: Texture2D, grid_size: Vector2i) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = TILE_SIZE
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			source.create_tile(Vector2i(x, y))
	return source


func _create_layer(
	layer_name: String,
	tile_set: TileSet,
	layer_z_index: int,
	has_collision: bool
) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.z_index = layer_z_index
	layer.collision_enabled = has_collision
	return layer


func _build_background(layer: TileMapLayer) -> void:
	layer.modulate = Color(0.47, 0.54, 0.49, 1.0)
	# Overscan keeps the camera clear color outside every reachable view.
	_fill_rect(layer, Rect2i(-24, -12, 304, 54), SOURCE_WALLS, WALL_FILL_TILE)


func _build_background_details(layer: TileMapLayer) -> void:
	layer.modulate = Color(0.82, 0.86, 0.76, 1.0)
	var module_origins := [0, 42, 84, 126, 168, 210]
	for module_index in range(module_origins.size()):
		_decorate_module(layer, module_index, module_origins[module_index])

	# Long floor-side conduits bind the six rooms into one continuous facility.
	for x in range(0, MAP_SIZE.x, 25):
		_stamp_atlas_rect(layer, SOURCE_SUBWAY, Vector2i(0, 14), Vector2i(25, 4), Vector2i(x, 24))


func _build_collision_route(layer: TileMapLayer) -> void:
	# Safety floor and enclosing walls keep every fall inside the map.
	_fill_rect(layer, Rect2i(0, 28, MAP_SIZE.x, 2), SOURCE_WALLS, GROUND_TILE)
	_fill_rect(layer, Rect2i(0, 0, 1, 28), SOURCE_WALLS, GROUND_TILE)
	_fill_rect(layer, Rect2i(MAP_SIZE.x - 1, 0, 1, 28), SOURCE_WALLS, GROUND_TILE)

	# Main route: generous combat decks linked by readable, medium jumps.
	var main_platforms := [
		Vector3i(0, 36, 22),
		Vector3i(40, 57, 21),
		Vector3i(61, 81, 19),
		Vector3i(86, 112, 22),
		Vector3i(117, 133, 20),
		Vector3i(138, 153, 18),
		Vector3i(158, 181, 22),
		Vector3i(186, 202, 20),
		Vector3i(207, 226, 18),
		Vector3i(231, 255, 21),
	]
	for platform in main_platforms:
		_platform(layer, platform.x, platform.y, platform.z)

	# Low-route landings and stair-step recovery platforms.
	_platform(layer, 33, 63, 27)
	_platform(layer, 54, 67, 25)
	_platform(layer, 62, 73, 23)
	_platform(layer, 106, 163, 27)
	_platform(layer, 143, 157, 25)
	_platform(layer, 151, 164, 23)
	_platform(layer, 178, 213, 27)
	_platform(layer, 197, 211, 25)
	_platform(layer, 204, 217, 23)

	# Small cover blocks shape future combat spaces without creating dead ends.
	_fill_rect(layer, Rect2i(25, 20, 3, 2), SOURCE_WALLS, GROUND_TILE)
	_fill_rect(layer, Rect2i(95, 20, 4, 2), SOURCE_WALLS, GROUND_TILE)
	_fill_rect(layer, Rect2i(169, 20, 3, 2), SOURCE_WALLS, GROUND_TILE)
	_fill_rect(layer, Rect2i(239, 19, 4, 2), SOURCE_WALLS, GROUND_TILE)


func _build_foreground(layer: TileMapLayer) -> void:
	layer.modulate = Color(0.61, 0.68, 0.61, 0.94)
	for x in [8, 50, 92, 134, 176, 218]:
		_stamp_atlas_rect(layer, SOURCE_SUBWAY, Vector2i(8, 0), Vector2i(5, 3), Vector2i(x, 1))
	# Sparse near-camera framing along the top edge; it never covers the route.
	for x in [0, 84, 168, 246]:
		_stamp_atlas_rect(layer, SOURCE_WALLS, Vector2i(0, 30), Vector2i(2, 9), Vector2i(x, 0))


func _fill_rect(
	layer: TileMapLayer,
	rect: Rect2i,
	source_id: int,
	atlas: Vector2i
) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			layer.set_cell(Vector2i(x, y), source_id, atlas)


func _stamp_atlas_rect(
	layer: TileMapLayer,
	source_id: int,
	source_origin: Vector2i,
	size: Vector2i,
	destination: Vector2i
) -> void:
	for y in range(size.y):
		for x in range(size.x):
			var target := destination + Vector2i(x, y)
			if target.x < 0 or target.y < 0 or target.x >= MAP_SIZE.x or target.y >= MAP_SIZE.y:
				continue
			layer.set_cell(target, source_id, source_origin + Vector2i(x, y))


func _platform(layer: TileMapLayer, x_from: int, x_to: int, y: int) -> void:
	_fill_rect(layer, Rect2i(x_from, y, x_to - x_from + 1, 1), SOURCE_WALLS, GROUND_TILE)


func _decorate_module(layer: TileMapLayer, module_index: int, x_origin: int) -> void:
	var left_panel_source := Vector2i(0, 0) if module_index % 2 == 0 else Vector2i(0, 11)
	var right_panel_source := Vector2i(12, 11) if module_index % 3 == 0 else Vector2i(12, 0)
	_stamp_atlas_rect(layer, SOURCE_WALLS, left_panel_source, Vector2i(11, 9), Vector2i(x_origin + 2, 8))
	_stamp_atlas_rect(layer, SOURCE_WALLS, right_panel_source, Vector2i(11, 9), Vector2i(x_origin + 26, 8))

	match module_index:
		0:
			_stamp_atlas_rect(layer, SOURCE_SUBWAY, Vector2i(0, 0), Vector2i(8, 6), Vector2i(x_origin + 2, 2))
			_stamp_atlas_rect(layer, SOURCE_SUBWAY, Vector2i(13, 1), Vector2i(3, 4), Vector2i(x_origin + 18, 14))
			_stamp_atlas_rect(layer, SOURCE_SUBWAY, Vector2i(5, 8), Vector2i(8, 5), Vector2i(x_origin + 27, 16))
		1:
			_stamp_atlas_rect(layer, SOURCE_SUBWAY, Vector2i(17, 1), Vector2i(8, 5), Vector2i(x_origin + 5, 14))
			_stamp_atlas_rect(layer, SOURCE_SUBWAY, Vector2i(8, 0), Vector2i(5, 6), Vector2i(x_origin + 20, 3))
			_stamp_atlas_rect(layer, SOURCE_SUBWAY, Vector2i(0, 7), Vector2i(5, 6), Vector2i(x_origin + 30, 13))
		2:
			_stamp_atlas_rect(layer, SOURCE_WALLS, Vector2i(0, 21), Vector2i(11, 9), Vector2i(x_origin + 4, 10))
			_stamp_atlas_rect(layer, SOURCE_SUBWAY, Vector2i(13, 1), Vector2i(3, 4), Vector2i(x_origin + 19, 12))
			_stamp_atlas_rect(layer, SOURCE_SUBWAY, Vector2i(17, 1), Vector2i(8, 5), Vector2i(x_origin + 27, 15))
		3:
			_stamp_atlas_rect(layer, SOURCE_SUBWAY, Vector2i(0, 0), Vector2i(8, 6), Vector2i(x_origin + 4, 4))
			_stamp_atlas_rect(layer, SOURCE_SUBWAY, Vector2i(5, 8), Vector2i(8, 5), Vector2i(x_origin + 17, 14))
			_stamp_atlas_rect(layer, SOURCE_SUBWAY, Vector2i(13, 1), Vector2i(3, 4), Vector2i(x_origin + 33, 12))
		4:
			_stamp_atlas_rect(layer, SOURCE_WALLS, Vector2i(12, 21), Vector2i(11, 9), Vector2i(x_origin + 4, 8))
			_stamp_atlas_rect(layer, SOURCE_SUBWAY, Vector2i(8, 0), Vector2i(5, 6), Vector2i(x_origin + 20, 3))
			_stamp_atlas_rect(layer, SOURCE_SUBWAY, Vector2i(17, 1), Vector2i(8, 5), Vector2i(x_origin + 28, 15))
		5:
			_stamp_atlas_rect(layer, SOURCE_SUBWAY, Vector2i(13, 1), Vector2i(3, 4), Vector2i(x_origin + 4, 13))
			_stamp_atlas_rect(layer, SOURCE_WALLS, Vector2i(12, 21), Vector2i(11, 9), Vector2i(x_origin + 13, 9))
			_stamp_atlas_rect(layer, SOURCE_SUBWAY, Vector2i(17, 1), Vector2i(8, 5), Vector2i(x_origin + 27, 15))


func _configure_player_camera(player: CharacterBody2D) -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = MAP_SIZE.x * TILE_SIZE.x
	camera.limit_bottom = MAP_SIZE.y * TILE_SIZE.y
