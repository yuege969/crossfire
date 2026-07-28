# Marker (准星) Crosshair Design

**Date:** 2026-07-28
**Status:** Approved

## Overview

Implement runtime logic for the Marker (crosshair) Sprite2D node in the Player scene. The marker shows where the player is aiming and provides visual feedback on shoot.

## Behavior

### 1. 8-Direction Positioning

- Marker position is locked to one of 8 directions relative to the player
- Direction is calculated from the mouse position angle, snapped to 45° increments
- Same angle calculation as `_update_torso_direction()`
- Marker sits at a fixed `marker_distance` (default 40px) from the player's `global_position`

### 2. Shoot Scale Feedback

- On each shot, the marker briefly compresses then springs back
- Uses `Tween` for smooth easing
- Scale: `0.5` → `0.3` → `0.5` with ease-out on the return

## Implementation

### File: `scenes/player.gd`

Changes:
- New `@onready` reference: `$Marker` as `_marker`
- New export: `marker_distance: float = 40.0`
- New method `_update_marker()` — calculates 8-dir position from mouse angle
- Call `_update_marker()` in `_physics_process()`
- In `_shoot()`: trigger Tween scale pop animation on `_marker`
