# Drone Chain Explosion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a drone explodes, nearby drones chain-explode after a short delay, cascading up to a configurable depth.

**Architecture:** A new `trigger_chain_explosion(chain_depth)` method on the drone becomes the single entry point for all explosion triggers. Both `on_hit_by_bullet()` and `_on_hit_player()` delegate to it. The method sets DYING state immediately, then after `chain_delay` scans the `"Drones"` group for nearby non-DYING drones and recurses at `chain_depth + 1`, guarded by `max_chain_depth`.

**Tech Stack:** Godot 4.4+, GDScript, `SceneTreeTimer` for async delays, `get_tree().get_nodes_in_group("Drones")` for neighbor scanning

## Global Constraints

- Only modify `scenes/drone.gd` — no new files, no scene changes
- All new parameters are `@export` with sensible defaults for editor tuning
- Existing behavior (player freeze, game over UI, bullet hit) remains identical
- `"Drones"` group (from scene file `groups=["Drones"]`) is used for scanning; `"drone"` group (from `_ready()`) is left untouched

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `scenes/drone.gd` | Modify | New export vars, new `trigger_chain_explosion()` method, refactor two existing explode triggers |

---

### Task 1: Add export variables for chain explosion tuning

**Files:**
- Modify: `scenes/drone.gd` — insert after `@export var speed` line

**Interfaces:**
- Produces: `chain_radius: float`, `chain_delay: float`, `max_chain_depth: int` — consumed by Task 2

- [ ] **Step 1: Add three @export variables**

Open `scenes/drone.gd`. After line 1 (`@export var speed: float = 150.0`), add:

```gdscript
@export var chain_radius: float = 50.0
@export var chain_delay: float = 0.15
@export var max_chain_depth: int = 3
```

The file should now have these export vars at the top:

```gdscript
extends CharacterBody2D

@export var speed: float = 150.0
@export var chain_radius: float = 50.0
@export var chain_delay: float = 0.15
@export var max_chain_depth: int = 3
```

- [ ] **Step 2: Verify the file parses without errors**

Open the project in the Godot editor and check the Output panel for errors.

- [ ] **Step 3: Commit**

```bash
git add scenes/drone.gd
git commit -m "feat: add chain_radius, chain_delay, max_chain_depth export vars to drone"
```

---

### Task 2: Implement `trigger_chain_explosion()` method

**Files:**
- Modify: `scenes/drone.gd` — new method before `_on_animation_finished()`

**Interfaces:**
- Consumes: `chain_radius`, `chain_delay`, `max_chain_depth` (from Task 1), `state` enum, `_collision_shape`, `_detection_area`, `_animated_sprite`, `"Drones"` group
- Produces: `trigger_chain_explosion(chain_depth: int) -> void` — entry point for all explosion triggers (consumed by Tasks 3, 4)

- [ ] **Step 1: Add the `trigger_chain_explosion()` method**

Insert before `func _on_animation_finished()` (before line 65 in current file):

```gdscript
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
```

- [ ] **Step 2: Verify Godot syntax**

Open the project in the Godot editor. Check the Output panel for parse errors.

- [ ] **Step 3: Commit**

```bash
git add scenes/drone.gd
git commit -m "feat: add trigger_chain_explosion and _trigger_nearby_drones methods"
```

---

### Task 3: Refactor `on_hit_by_bullet()` and `_on_hit_player()` to use `trigger_chain_explosion()`

**Files:**
- Modify: `scenes/drone.gd` — `on_hit_by_bullet()` and `_on_hit_player()`

**Interfaces:**
- Consumes: `trigger_chain_explosion(chain_depth: int)` from Task 2

- [ ] **Step 1: Refactor `on_hit_by_bullet()`**

Replace:

```gdscript
func on_hit_by_bullet() -> void:
	if state == State.DYING:
		return
	state = State.DYING
	_collision_shape.set_deferred("disabled", true)
	_detection_area.set_deferred("monitoring", false)
	_animated_sprite.play("die")
```

With:

```gdscript
func on_hit_by_bullet() -> void:
	trigger_chain_explosion(0)
```

- [ ] **Step 2: Refactor `_on_hit_player()`**

Replace:

```gdscript
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
```

With:

```gdscript
func _on_hit_player(p: Node2D) -> void:
	if state == State.DYING:
		return
	_stored_player = p
	_hit_player = true
	if p.has_method("freeze"):
		p.freeze()
	trigger_chain_explosion(0)
```

Key: `_stored_player`, `_hit_player`, and `p.freeze()` are set BEFORE `trigger_chain_explosion(0)` so `_on_animation_finished()` still correctly handles the game-over path.

- [ ] **Step 3: Verify in Godot editor**

Open `drone.gd` in the Godot editor. Confirm no parse errors.

- [ ] **Step 4: Commit**

```bash
git add scenes/drone.gd
git commit -m "refactor: delegate on_hit_by_bullet and _on_hit_player to trigger_chain_explosion"
```

---

### Task 4: Manual integration test

**Files:**
- No code changes — test the running game

- [ ] **Step 1: Add multiple drone instances to level_1.tscn for testing**

Open `scenes/levels/level_1.tscn` in the Godot editor. Under the `Entities` node, add 3-4 additional `Drone` instances positioned close to each other (within ~50px spacing).

Suggested positions:
- Drone 1: (283, 345) — existing
- Drone 2: (320, 345) — ~37px right
- Drone 3: (283, 380) — ~35px below
- Drone 4: (320, 380) — diagonal ~52px

- [ ] **Step 2: Run and test bullet-hit chain**

Run the project. Shoot the first drone. Observe:
- First drone explodes at t=0
- Nearby drones within `chain_radius` explode at ~t=0.15s
- Additional waves at ~t=0.30s and ~t=0.45s
- No game-over UI appears (bullet-hit path)

- [ ] **Step 3: Run and test player-collision chain**

Walk the player into a drone. Observe:
- Player freezes immediately
- First drone plays explosion
- Chain reaction propagates to nearby drones
- After first drone's die animation finishes, game-over UI appears
- Chain-exploded drones do NOT trigger additional game-over UIs

- [ ] **Step 4: Test chain depth limit**

Position 5+ drones in a line with ~40px spacing. Shoot the first. Verify chain stops after `max_chain_depth` (3) waves.

- [ ] **Step 5: Clean up or keep test instances**

Remove extra test drones and restore `Entities` edit lock, or leave them for gameplay.

---

### Task 5: Final verification

- [ ] **Step 1: Review git diff**

```bash
git diff HEAD~3..HEAD
```

Confirm all changes are in `scenes/drone.gd` only.

- [ ] **Step 2: Final smoke test**

Run the project, verify all drone behaviors: chase, stop, bullet-hit, player-hit, chain reaction.

- [ ] **Step 3: Commit any remaining scene changes**

```bash
git add scenes/levels/level_1.tscn
git commit -m "feat: add multiple drone instances for chain explosion gameplay"
```
