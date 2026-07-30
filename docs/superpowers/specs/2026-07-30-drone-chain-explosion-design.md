# Drone Chain Explosion

**Date:** 2026-07-30
**Status:** approved
**Scope:** `scenes/drone.gd`

## Overview

When a drone explodes, it triggers a chain reaction — nearby drones explode after a short delay, which in turn trigger more drones, up to a configurable maximum depth. This creates a cascading explosion visual effect.

## Current State

### drone.gd

- `on_hit_by_bullet()` → enters DYING, plays "die" animation, `queue_free()` on finish
- `_on_hit_player()` → enters DYING, freezes player, plays "die" animation, calls `player.die()` on finish
- No chain reaction logic — each drone explodes in isolation
- Drones belong to group `"Drones"` (scene file) and group `"drone"` (`_ready()`)

### Key Constants

| Value | Source |
|-------|--------|
| Detection radius | 99px (hardcoded in `drone.tscn` `DetctionArea/CollisionShape2D`) |
| Die animation duration | 1.6s (8 frames × 1.0s/frame ÷ 5.0 speed) |
| Current drone speed | 100 (scene override from code default 150) |

## Design

### New Exported Parameters

```gdscript
@export var chain_radius: float = 50.0       # explosion propagation radius (px)
@export var chain_delay: float = 0.15         # delay before nearby drones explode (seconds)
@export var max_chain_depth: int = 3          # maximum chain propagation depth
```

Default `chain_radius = 50.0` (~half the detection radius of 99px). All three are `@export` so they can be tuned per-drone in the editor.

### New Method: `trigger_chain_explosion(chain_depth: int)`

```
trigger_chain_explosion(chain_depth):
    1. Guard: if state == DYING → return (prevent double trigger)
    2. Set state = DYING
    3. Disable CollisionShape2D (deferred)
    4. Disable DetctionArea monitoring (deferred)
    5. Play "die" animation
    6. If chain_depth < max_chain_depth:
       a. Wait chain_delay seconds (SceneTreeTimer)
       b. Scan all nodes in "Drones" group
       c. For each drone within chain_radius distance AND not in DYING state:
          → drone.trigger_chain_explosion(chain_depth + 1)
```

### Integration with Existing Methods

**`on_hit_by_bullet()`** → replace body with `trigger_chain_explosion(0)`

**`_on_hit_player(p)`** → replace the DYING state transition block with `trigger_chain_explosion(0)`, keep `_stored_player = p`, `_hit_player = true`, and `p.freeze()` BEFORE the call

**`_on_animation_finished()`** → unchanged. Chain-exploded drones have `_hit_player == false`, so they just `queue_free()` without triggering game over.

### State Machine Update

```
IDLE ──(player enters DetctionArea)──→ CHASE

CHASE ──(slide collision with player)──→ _on_hit_player()
                                           ├─ _hit_player = true, freeze player
                                           └─ trigger_chain_explosion(0)

CHASE ──(bullet hits)──→ on_hit_by_bullet()
                           └─ trigger_chain_explosion(0)

DYING ──(animation_finished, _hit_player==true)──→ player.die() → queue_free()
DYING ──(animation_finished, _hit_player==false)──→ queue_free()
DYING ──(chain_delay elapsed, chain_depth < max)──→ scan group → trigger nearby
```

## Edge Cases

### 1. Double-trigger prevention
`trigger_chain_explosion()` checks `state == DYING` at entry and returns immediately. A drone hit by both bullet and chain explosion in the same frame only processes the first.

### 2. Chain explosion during delay window
If drone A begins chain explosion (state = DYING) and during its `chain_delay` wait, a bullet hits it → `on_hit_by_bullet()` calls `trigger_chain_explosion(0)` again → guard catches `state == DYING` → return. Safe.

### 3. Overlapping chain propagation
A explodes → triggers B and C (depth=1). B's delay elapses → B tries to trigger C → C is already DYING → guard skips. No infinite loop.

### 4. queue_free and group traversal
Drones stay in the scene tree during their die animation (~1.6s). Chain delays (0.15s × 3 max = 0.45s from root) all complete well before any drone is `queue_free()`d. All exploded drones are in DYING state and skipped by the guard.

### 5. Max chain depth terminates propagation
With `max_chain_depth = 3`: initial explosion is depth 0, can propagate to depth 1, 2, 3. At depth 3, step 6 in `trigger_chain_explosion()` is skipped — no further scanning.

### 6. Chain-exploded drone animation timing
The first drone plays the die animation ~1.6s. Chain delays create a cascading visual:
- t=0: drone A explodes (depth 0)
- t=0.15s: nearby drones explode (depth 1)
- t=0.30s: their neighbors explode (depth 2)
- t=0.45s: final wave (depth 3)

All animations overlap naturally, creating a ripple-out effect.

### 7. Player collision + chain interaction
If the player collides with drone A, `_on_hit_player()` sets `_hit_player = true` on drone A only. Chain-exploded drones have `_hit_player = false`, so only drone A triggers `player.die()` on animation finish. No duplicate game-over screens.

## Implementation Checklist

- [ ] `drone.gd`: Add `chain_radius`, `chain_delay`, `max_chain_depth` export vars
- [ ] `drone.gd`: Implement `trigger_chain_explosion(chain_depth: int)` method
- [ ] `drone.gd`: Refactor `on_hit_by_bullet()` to call `trigger_chain_explosion(0)`
- [ ] `drone.gd`: Refactor `_on_hit_player()` to call `trigger_chain_explosion(0)`
- [ ] Manual test: bullet hit triggers chain to nearby drones
- [ ] Manual test: player collision triggers chain to nearby drones
- [ ] Manual test: chain depth limit prevents full-screen wipe
- [ ] Manual test: chain-exploded drones do NOT trigger game over
- [ ] Manual test: cascading visual timing looks correct
