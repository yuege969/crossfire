# Drone Collision Explosion & Follow Logic Update

**Date:** 2026-07-29
**Status:** approved
**Scope:** `scenes/drone.gd`, `scenes/player.gd`

## Overview

Two changes to the drone enemy behavior:

1. When a drone collides with the player, the drone plays its explosion animation first, then the game over screen appears after the animation finishes. The player is frozen immediately on contact.
2. When the player leaves the drone's detection area, the drone stops at its current position instead of continuing to chase.

## Current State

### drone.gd
- 3 states: `IDLE`, `CHASE`, `DYING`
- `IDLE` → `CHASE` transition: `body_entered` signal from `DetctionArea`
- `CHASE`: moves toward `_player` with `move_and_slide()`, checks slide collisions for player contact
- `DYING`: triggered by `on_hit_by_bullet()`, plays "die" animation, frees on finish
- `_on_hit_player()`: immediately calls `player.die()` → player hides + game over UI appears
- No `body_exited` handling — drone chases forever once triggered

### player.gd
- `die()`: disables physics/input, hides sprite, instantiates `game_over_ui.tscn`

## Design

### Feature 1: Drone hits player → explosion → game over

**New flow:**
```
Collision → _on_hit_player()
  → drone enters DYING, plays "die" animation
  → player.freeze() — freeze input, keep sprite visible
  → "die" animation finishes → _on_animation_finished()
    → player.die() — hide player, show game over UI
    → drone queue_free()
```

**drone.gd changes:**
- Add `var _hit_player: bool = false` flag and `var _stored_player: CharacterBody2D = null` ref
- `_on_hit_player(p)`: store player ref, set `_hit_player = true`, call `p.freeze()`, enter DYING state, disable collision/detection, play "die" animation
- `_on_animation_finished()`: after "die" finishes, if `_hit_player`, call `_stored_player.die()`, then `queue_free()`

**player.gd changes:**
- Add `freeze()` method: `set_physics_process(false)`, `set_process(false)` — stops movement and shooting, but does NOT hide the sprite or show game over UI
- `die()` remains unchanged

### Feature 2: Stop chasing when player leaves detection area

**drone.gd changes:**
- Connect `DetctionArea.body_exited` signal
- `_on_detection_body_exited(body)`: if body is the current `_player`, set `_player = null`
- CHASE state already handles `_player == null` via `if _player:` guard — drone stops moving

**Re-entry behavior:**
- If player re-enters detection area, `body_entered` sets `_player` again and drone resumes chasing
- Existing `body_entered` handler only transitions from IDLE — update to also allow re-entry from CHASE when `_player` is null

## Edge Cases

1. **Multiple collisions in one frame**: guarded by `state == State.DYING` check at top of `_on_hit_player()`
2. **Bullet and player hit same frame**: first one wins (DYING check prevents double-trigger). If player hits first, `_hit_player = true` ensures correct post-animation behavior
3. **Player re-enters after exiting**: `body_entered` handler updated to also set `_player` when `state == CHASE` and `_player == null`

## Implementation Checklist

- [ ] `drone.gd`: Add `_hit_player` flag and `_stored_player` variable
- [ ] `drone.gd`: Connect `body_exited` signal in `_ready()`
- [ ] `drone.gd`: Add `_on_detection_body_exited()` handler
- [ ] `drone.gd`: Modify `_on_hit_player()` — enter DYING instead of calling `player.die()` directly
- [ ] `drone.gd`: Update `_on_detection_body_entered()` — allow re-entry when `_player` is null
- [ ] `drone.gd`: Modify `_on_animation_finished()` — handle `_hit_player` case
- [ ] `player.gd`: Add `freeze()` method
- [ ] Manual test: drone stops when player leaves detection area
- [ ] Manual test: drone resumes when player re-enters
- [ ] Manual test: collision triggers explosion → game over after animation
