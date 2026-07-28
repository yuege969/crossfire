# Level 1 TileMapLayer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a polished, collision-enabled, 6–8-screen horizontal Level 1 from the existing subway and walls tile atlases.

**Architecture:** A deterministic Godot editor script constructs the shared 16×16 `TileSet`, stamps four purpose-specific `TileMapLayer` nodes, preserves the existing Player and bullets container contract, and saves `level_1.tscn`. A headless validation script loads the generated scene and checks layer responsibilities, map bounds, collision configuration, spawn safety, and endpoint placement.

**Tech Stack:** Godot 4.7.1, GDScript, `TileSetAtlasSource`, `TileMapLayer`, headless Godot validation

## Global Constraints

- Use only `graphics/tilesets/subway.png` and `graphics/tilesets/walls.png` for TileMap visuals.
- Use a 16×16 integer grid and nearest-neighbor texture filtering.
- Keep the existing `res://scenes/player.tscn` instance and the `bullets` node.
- Do not modify `scenes/player.tscn` or introduce enemies, hazards, respawn, or checkpoint logic.
- Keep every fall inside the map and provide a traversable low route back to the main route.
- Produce four populated layers named `BGLayer`, `BGDetailLayer`, `CollisionLayer`, and `FGLayer`.

---

## File Structure

- `tools/build_level_1.gd`: deterministic scene builder; owns atlas creation, collision tile configuration, module stamping, layer ordering, and scene saving.
- `tests/validate_level_1.gd`: headless structural and playability-contract checks for the saved scene.
- `scenes/levels/level_1.tscn`: generated playable Level 1 scene and project main scene.
- `project.godot`: references Level 1 by stable resource path so regeneration does not depend on the editor UID cache.

### Task 1: Level validation contract

**Files:**
- Create: `tests/validate_level_1.gd`
- Test: `tests/validate_level_1.gd`

**Interfaces:**
- Consumes: `res://scenes/levels/level_1.tscn`
- Produces: process exit code `0` for a valid level and `1` with explicit assertion messages for invalid structure

- [ ] **Step 1: Write the failing structural validation**

Create a `SceneTree` script that loads and instantiates Level 1, then checks:

```gdscript
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
	for path in REQUIRED_LAYERS:
		var layer := level.get_node_or_null(path) as TileMapLayer
		_expect(layer != null, "%s must be a TileMapLayer" % path)
		if layer:
			_expect(layer.tile_set != null, "%s must share a TileSet" % path)
			_expect(layer.get_used_cells().size() > 0, "%s must contain cells" % path)
	var collision := level.get_node_or_null("Layers/CollisionLayer") as TileMapLayer
	if collision and collision.tile_set:
		_expect(collision.tile_set.get_physics_layers_count() == 1, "TileSet must contain one physics layer")
		_expect(collision.get_used_rect().size.x >= 240, "Level must span at least six camera screens")
		_expect(collision.get_used_rect().end.y <= 30, "Collision geometry must stay inside the level")
	_expect(level.get_node_or_null("Entities/Player") != null, "Player must exist under Entities")
	_expect(level.get_node_or_null("Entities/LevelExit") != null, "LevelExit marker must exist")
	_expect(level.get_node_or_null("bullets") != null, "bullets container must be preserved")
	level.queue_free()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("Level 1 validation passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
```

- [ ] **Step 2: Run validation to verify it fails**

Run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/validate_level_1.gd
```

Expected: exit `1` because three layers are empty, they do not share a TileSet, no physics layer exists, and `LevelExit` is absent.

- [ ] **Step 3: Commit the validation contract**

```bash
git add tests/validate_level_1.gd
git commit -m "test: define Level 1 tilemap contract"
```

### Task 2: Deterministic TileSet and level builder

**Files:**
- Create: `tools/build_level_1.gd`
- Modify: `scenes/levels/level_1.tscn`
- Modify: `project.godot`
- Test: `tests/validate_level_1.gd`

**Interfaces:**
- Consumes: the two `Texture2D` resources at `res://graphics/tilesets/subway.png` and `res://graphics/tilesets/walls.png`
- Produces: `_build_tile_set() -> TileSet`, `_stamp_atlas_rect(layer: TileMapLayer, source_id: int, source_origin: Vector2i, size: Vector2i, destination: Vector2i)`, and a saved `PackedScene` at `res://scenes/levels/level_1.tscn`

- [ ] **Step 1: Implement atlas construction**

Create `tools/build_level_1.gd` as a `SceneTree` script. `_build_tile_set()` must:

- create a `TileSet` with `tile_size = Vector2i(16, 16)`;
- add one physics layer with collision layer and mask `1`;
- create atlas source `0` for `subway.png` with a 25×25 grid;
- create atlas source `1` for `walls.png` with a 35×43 grid;
- create every atlas cell fully inside each texture;
- add a full-cell collision polygon to the selected solid ground tile;
- return the shared TileSet.

The full-cell polygon is:

```gdscript
PackedVector2Array([
	Vector2(-8, -8),
	Vector2(8, -8),
	Vector2(8, 8),
	Vector2(-8, 8),
])
```

- [ ] **Step 2: Implement reusable stamping helpers**

Add these focused helpers:

```gdscript
func _fill_rect(layer: TileMapLayer, rect: Rect2i, source_id: int, atlas: Vector2i) -> void
func _stamp_atlas_rect(
	layer: TileMapLayer,
	source_id: int,
	source_origin: Vector2i,
	size: Vector2i,
	destination: Vector2i
) -> void
func _platform(layer: TileMapLayer, x_from: int, x_to: int, y: int) -> void
func _decorate_module(layer: TileMapLayer, module_index: int, x_origin: int) -> void
```

`_fill_rect` must iterate every cell in `rect`; `_stamp_atlas_rect` must preserve the source atlas adjacency; `_platform` must write the collision-enabled tile from `x_from` through `x_to`; `_decorate_module` must choose a fixed decoration composition for each of the six modules without randomness.

- [ ] **Step 3: Build the node hierarchy and layer ordering**

The generated scene must have:

```text
Level1
├── Layers
│   ├── BGLayer            z_index = -20
│   ├── BGDetailLayer      z_index = -10
│   ├── CollisionLayer     z_index = 0
│   └── FGLayer            z_index = 20
├── Entities               z_index = 10
│   ├── Player
│   └── LevelExit
└── bullets
```

Assign the same TileSet to all four layers. Fill the background through `Rect2i(0, 0, 256, 30)`, then stamp wall frames and subway detail compositions by module. Keep decoration cells off the collision layer.

- [ ] **Step 4: Build the traversable collision route**

Write:

- a full-width safety floor on rows `28` and `29`;
- left and right enclosing walls;
- a safe start platform at row `22`;
- six horizontal modules connected by 2–4-cell jumps;
- two drop-through gaps leading to row `27`;
- staircase platforms with no vertical step larger than three cells;
- an exit platform at row `21`.

Place Player at `Vector2(72, 336)` and align `LevelExit` with the green exit structure at `Vector2(3720, 320)`. No platform may be narrower than four cells.

- [ ] **Step 5: Save the generated scene**

Pack the root with `PackedScene.pack(level)` and save with:

```gdscript
var error := ResourceSaver.save(packed_scene, "res://scenes/levels/level_1.tscn")
if error != OK:
	push_error("Failed to save Level 1: %s" % error_string(error))
	quit(1)
quit(0)
```

Run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/build_level_1.gd
```

Expected: exit `0` and a regenerated `level_1.tscn`.

Set `application/run/main_scene` in `project.godot` to `res://scenes/levels/level_1.tscn`. This stable path remains valid when the deterministic builder rewrites the scene and the headless resource UID cache has not yet been refreshed.

- [ ] **Step 6: Run the validation contract**

Run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/validate_level_1.gd
```

Expected: `Level 1 validation passed` and exit `0`.

- [ ] **Step 7: Commit the builder and generated scene**

```bash
git add tools/build_level_1.gd scenes/levels/level_1.tscn
git commit -m "feat: build Level 1 TileMapLayer scene"
```

### Task 3: Runtime and visual verification

**Files:**
- Modify only if verification reveals a defect: `tools/build_level_1.gd`
- Regenerate after any builder change: `scenes/levels/level_1.tscn`
- Test: `tests/validate_level_1.gd`

**Interfaces:**
- Consumes: the generated main scene and current Player controller
- Produces: a parse-clean, runnable project with an evidence-backed final visual check

- [ ] **Step 1: Run a project import and parse check**

Run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
```

Expected: exit `0` with no scene parse errors, missing resources, invalid tiles, or GDScript errors.

- [ ] **Step 2: Run the main scene smoke test**

Run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 120
```

Expected: exit `0` without runtime errors during the first 120 frames.

- [ ] **Step 3: Inspect the rendered level**

Open the project in Godot, run the main scene, and inspect the start, each module transition, both low routes, and the exit. Check for:

- incorrect atlas seams or transparent holes;
- decoration that obscures the player or route;
- collision surfaces that do not match visible platforms;
- missing green direction cues;
- repetitive room composition without visual breaks.

If a defect is found, edit the deterministic module composition in `tools/build_level_1.gd`, regenerate the scene, and repeat Steps 1–3.

- [ ] **Step 4: Run final validation**

Run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/validate_level_1.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
```

Expected: both commands exit `0`.

- [ ] **Step 5: Commit any visual polish corrections**

```bash
git add tools/build_level_1.gd scenes/levels/level_1.tscn tests/validate_level_1.gd
git commit -m "fix: polish Level 1 layout and collision"
```
