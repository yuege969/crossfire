# Drone Collision Explosion & Follow Logic — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When drone hits player, play explosion animation then show game over screen; drone stops when player leaves detection area.

**Architecture:** Two-file change. `drone.gd` gets a `_hit_player` flag to defer `player.die()` until the explosion animation finishes, and a `body_exited` handler to stop chasing. `player.gd` gets a `freeze()` method to disable input without hiding the sprite.

**Tech Stack:** Godot 4.4+, GDScript

## Global Constraints

- All behavior scoped to `scenes/drone.gd` and `scenes/player.gd`
- Follow existing code patterns: `@onready` vars, `match state`, `set_deferred` for physics changes
- Die animation is non-looping (`"loop": 0` in drone.tscn), `animation_finished` already connected

---

### Task 1: Add `freeze()` method to player

**Files:**
- Modify: `scenes/player.gd`

**Interfaces:**
- Produces: `func freeze() -> void` — disables `_physics_process` and `_process`, keeps sprite visible, does NOT instantiate game over UI

- [ ] **Step 1: Add `freeze()` method**

Add the following method to `player.gd`, after the existing `die()` method (around line 101):

```gdscript
func freeze() -> void:
	set_physics_process(false)
	set_process(false)
```

- [ ] **Step 2: Verify syntax**

Visual check: confirm no syntax errors, consistent tab indentation.

- [ ] **Step 3: Commit**

```bash
git add scenes/player.gd
git commit -m "feat: add freeze() method to player"
```

---

### Task 2: Update drone follow logic — stop when player leaves detection area

**Files:**
- Modify: `scenes/drone.gd`

**Interfaces:**
- Consumes: `DetctionArea.body_exited` signal (already exists on node)
- Produces: `_on_detection_body_exited(body: Node2D)` handler; updated `_on_detection_body_entered()` that also works from CHASE state

- [ ] **Step 1: Connect `body_exited` signal**

In `_ready()`, add after line 17 (`_animated_sprite.animation_finished.connect(...)`):

```gdscript
_detection_area.body_exited.connect(_on_detection_body_exited)
```

- [ ] **Step 2: Add `_on_detection_body_exited()` handler**

Add after `_on_detection_body_entered()` (after line 43):

```gdscript
func _on_detection_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
```

- [ ] **Step 3: Update `_on_detection_body_entered()` to allow re-entry**

Replace the entire `_on_detection_body_entered` function (lines 38-43) with:

```gdscript
func _on_detection_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if state == State.DYING:
		return
	if state == State.IDLE or (state == State.CHASE and _player == null):
		_player = body
		state = State.CHASE
```

- [ ] **Step 4: Verify syntax**

Visual check: all tabs align, no syntax errors.

- [ ] **Step 5: Commit**

```bash
git add scenes/drone.gd
git commit -m "feat: drone stops when player leaves detection area, resumes on re-enter"
```

---

### Task 3: Drone plays explosion on player collision, game over after animation

**Files:**
- Modify: `scenes/drone.gd`

**Interfaces:**
- Consumes: `player.freeze()` (from Task 1), `player.die()` (existing)
- Produces: Updated `_on_hit_player()` that sets DYING state instead of calling `player.die()` directly; updated `_on_animation_finished()` that calls `player.die()` when `_hit_player` is true

- [ ] **Step 1: Add `_hit_player` flag and `_stored_player` ref**

Add these lines after the existing variables (after line 4):

```gdscript
var _hit_player: bool = false
var _stored_player: CharacterBody2D = null
```

- [ ] **Step 2: Rewrite `_on_hit_player()` to trigger DYING**

Replace the existing `_on_hit_player` function (lines 58-60) with:

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

- [ ] **Step 3: Update `_on_animation_finished()` for player-hit case**

Replace the existing `_on_animation_finished` function (lines 53-55) with:

```gdscript
func _on_animation_finished() -> void:
	if _animated_sprite.animation == "die":
		if _hit_player and _stored_player and _stored_player.has_method("die"):
			_stored_player.die()
		queue_free()
```

- [ ] **Step 4: Verify syntax**

Visual check: confirm the complete `drone.gd` is consistent — all tabs align, no syntax errors.

- [ ] **Step 5: Commit**

```bash
git add scenes/drone.gd
git commit -m "feat: drone plays explosion on player collision, game over after animation"
```

---

### Task 4: Manual test and verification

- [ ] **Step 1: Launch the game**

Open the project in Godot editor and run `level_1` scene.

- [ ] **Step 2: Test follow-stop behavior**

1. Walk into drone detection area → drone should fly toward player
2. Walk out of detection area → drone should stop moving
3. Walk back in → drone should resume chasing

- [ ] **Step 3: Test collision explosion → game over**

1. Let drone collide with player
2. Verify: player freezes immediately (cannot move or shoot)
3. Verify: drone plays explosion animation (8 frames, non-looping)
4. Verify: after animation finishes, game over UI appears
5. Click "重新开始" → scene reloads

- [ ] **Step 4: Test bullet kill still works**

1. Shoot and kill a drone with bullets
2. Verify: explosion plays, drone disappears, game continues normally (no game over)
