# Drone Enemy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement drone enemy that idles until player enters detection zone, then chases player; kills player on contact; explodes on bullet hit.

**Architecture:** Finite state machine (IDLE → CHASE → DYING) on CharacterBody2D. Detection via Area2D body_entered, chase via move_and_slide with normalized direction to player, bullet collision via method call from bullet script, death via AnimatedSprite2D "die" animation.

**Tech Stack:** Godot 4.7, GDScript

## Global Constraints

- Collision layers must not change (already correctly configured)
- Drone "die" animation name: `"die"` (already exists in SpriteFrames)
- Drone "default" animation: idle/flying loop (already exists)
- Game Over: UI overlay with "重新开始" button reloading scene

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `scenes/drone.gd` | Create | Drone state machine, chase logic, death handling |
| `scenes/drone.tscn` | Modify | Attach script, connect animation_finished signal |
| `scenes/bullet.gd` | Modify | Notify hit target via `on_hit_by_bullet()` |
| `scenes/player.gd` | Modify | Add `die()`, add to "player" group |
| `scenes/game_over_ui.tscn` | Create | Game Over overlay UI |
| `scenes/game_over_ui.gd` | Create | Game Over UI script (restart button) |

---

### Task 1: Create drone.gd script

**Files:**
- Create: `scenes/drone.gd`

**Interfaces:**
- Produces: `on_hit_by_bullet()` (called by bullet), `_on_detection_body_entered(body)` (signal handler), `_on_animation_finished()` (signal handler)
- Consumes: player must be in "player" group and have `die()` method

- [ ] **Step 1: Write drone.gd**

```gdscript
extends CharacterBody2D

@export var speed: float = 150.0

enum State { IDLE, CHASE, DYING }
var state: State = State.IDLE
var _player: CharacterBody2D = null

@onready var _detection_area: Area2D = $DetctionArea
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("drone")
	_detection_area.body_entered.connect(_on_detection_body_entered)
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
	if state == State.IDLE and body.is_in_group("player"):
		_player = body
		state = State.CHASE


func on_hit_by_bullet() -> void:
	if state == State.DYING:
		return
	state = State.DYING
	_collision_shape.set_deferred("disabled", true)
	_detection_area.set_deferred("monitoring", false)
	_animated_sprite.play("die")


func _on_animation_finished() -> void:
	if _animated_sprite.animation == "die":
		queue_free()


func _on_hit_player(p: Node2D) -> void:
	if p.has_method("die"):
		p.die()
```

- [ ] **Step 2: Commit**

```bash
git add scenes/drone.gd
git commit -m "feat: add drone enemy behavior script"
```

---

### Task 2: Attach script to drone.tscn

**Files:**
- Modify: `scenes/drone.tscn`

**Interfaces:**
- Consumes: drone.gd script (from Task 1)
- Produces: Ready-to-use drone scene with script attached

- [ ] **Step 1: Edit drone.tscn to add script reference**

Add after line 4 (after `[ext_resource type="Texture2D" uid="uid://bav7n447bnsa5" ...]`):
```
[ext_resource type="Script" path="res://scenes/drone.gd" id="3_drone_script"]
```

On the Drone root node (line 109, `[node name="Drone" type="CharacterBody2D" unique_id=369366133]`), add `script`:
```
[node name="Drone" type="CharacterBody2D" unique_id=369366133]
script = ExtResource("3_drone_script")
```

- [ ] **Step 2: Update UIDs via Godot**

Run Godot to generate the script UID:
```
mcp__godot__update_project_uids(projectPath="/Users/yuege969/Desktop/workspace/game-dev-journey/projects/crossfire")
```

Or open the project in Godot editor to auto-assign.

- [ ] **Step 3: Commit**

```bash
git add scenes/drone.tscn
git commit -m "feat: attach drone.gd script to drone scene"
```

---

### Task 3: Modify bullet.gd to notify hit targets

**Files:**
- Modify: `scenes/bullet.gd:20-23`

**Interfaces:**
- Consumes: target must have `on_hit_by_bullet()` method (drone.gd provides this in Task 1)
- Produces: bullet calls `on_hit_by_bullet()` before self-destructing

- [ ] **Step 1: Edit _on_body_entered**

Change `_on_body_entered` in `scenes/bullet.gd` from:
```gdscript
func _on_body_entered(_body: Node2D) -> void:
	if _grace_period > 0.0:
		return
	queue_free()
```

To:
```gdscript
func _on_body_entered(body: Node2D) -> void:
	if _grace_period > 0.0:
		return
	if body.has_method("on_hit_by_bullet"):
		body.on_hit_by_bullet()
	queue_free()
```

- [ ] **Step 2: Commit**

```bash
git add scenes/bullet.gd
git commit -m "feat: bullet notifies target via on_hit_by_bullet()"
```

---

### Task 4: Create Game Over UI scene

**Files:**
- Create: `scenes/game_over_ui.gd`
- Create: `scenes/game_over_ui.tscn`

**Interfaces:**
- Produces: Self-contained UI scene with `_on_restart_button_pressed()` method
- Consumes: Nothing (self-contained, button reloads scene via `get_tree().reload_current_scene()`)

- [ ] **Step 1: Create game_over_ui.gd script**

```gdscript
extends CanvasLayer


func _ready() -> void:
	$VBoxContainer/RestartButton.pressed.connect(_on_restart_button_pressed)


func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()
```

- [ ] **Step 2: Create game_over_ui.tscn scene**

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/game_over_ui.gd" id="1_script"]

[node name="GameOverUI" type="CanvasLayer"]
script = ExtResource("1_script")

[node name="ColorRect" type="ColorRect" parent="."]
anchors_preset = 15
color = Color(0, 0, 0, 0.6)

[node name="VBoxContainer" type="VBoxContainer" parent="."]
anchors_preset = 8
alignment = 1

[node name="Label" type="Label" parent="VBoxContainer"]
text = "Game Over"
horizontal_alignment = 1
vertical_alignment = 1
theme_override_font_sizes/font_size = 48

[node name="RestartButton" type="Button" parent="VBoxContainer"]
text = "重新开始"
```

- [ ] **Step 3: Commit**

```bash
git add scenes/game_over_ui.gd scenes/game_over_ui.tscn
git commit -m "feat: add Game Over UI scene"
```

---

### Task 5: Modify player.gd — add die() and group

**Files:**
- Modify: `scenes/player.gd`

**Interfaces:**
- Produces: `die()` method (called by drone), player in "player" group (detected by drone DetctionArea)
- Consumes: `res://scenes/game_over_ui.tscn` (created in Task 4), uses `load()` for runtime safety

- [ ] **Step 1: Add _ready() and die() to player.gd**

Add the following at the end of `scenes/player.gd` (after `_update_marker()`, after line 89):

```gdscript
func _ready() -> void:
	add_to_group("player")


func die() -> void:
	set_process(false)
	set_physics_process(false)
	hide()
	var ui := load("res://scenes/game_over_ui.tscn").instantiate()
	get_tree().current_scene.add_child(ui)
```

- [ ] **Step 2: Commit**

```bash
git add scenes/player.gd
git commit -m "feat: add player die() method and player group"
```

---

## Implementation Order

```
Task 1 (drone.gd) → Task 2 (drone.tscn)
Task 4 (game_over_ui) → Task 5 (player.gd)
Task 3 (bullet.gd) — independent, can run in parallel
```

Tasks 1, 3, 4 can start in parallel. Task 2 depends on Task 1. Task 5 depends on Task 4.

## Verification

After all tasks:

1. Open level_1.tscn in Godot editor, press Play
2. Walk toward drone → it activates and flies toward player
3. Drone touches player → Game Over UI appears, click "重新开始" restarts
4. Shoot at drone → plays "die" animation then disappears
5. Bullet passes through dead drone → no crash (DYING state guard)
