# Drone Enemy Design

## Overview

实现无人机敌人行为：待机 → 检测到玩家后激活追逐 → 碰到玩家则游戏结束 → 被子弹击中则播放死亡动画后消失。

## Architecture

### Files

| 操作 | 文件 | 说明 |
|------|------|------|
| **新建** | `scenes/drone.gd` | 无人机行为脚本 |
| **修改** | `scenes/drone.tscn` | 挂载脚本、连接信号 |
| **修改** | `scenes/bullet.gd` | 击中时通知目标调用 `on_hit_by_bullet()` |
| **修改** | `scenes/player.gd` | 添加 `die()` 方法、加入 "player" group |
| **新建** | `scenes/game_over_ui.tscn` | 游戏结束 UI |

### State Machine

```
IDLE ──(玩家进入检测区)──▶ CHASE ──(子弹击中)──▶ DYING
                              │
                              └──(碰到玩家)──▶ 玩家死亡，触发 Game Over
```

- **IDLE**: 静止，`DetctionArea.body_entered` 监听玩家进入
- **CHASE**: 每帧计算朝向玩家的方向，`move_and_slide()` 移动；通过 `get_slide_collision_count()` 检测碰撞
- **DYING**: 播放 AnimatedSprite2D 的 "die" 动画，禁用 CollisionShape2D，动画播完后 `queue_free()`

### Collision Layers (已验证无需修改)

| 节点 | Layer | Mask | 说明 |
|------|-------|------|------|
| Player | 2 (Player) | 5 (Terrain+Drones) | ✅ |
| Bullet | 8 (Bullets) | 5 (Terrain+Drones) | ✅ |
| Drone | 4 (Drones) | 11 (Terrain+Player+Bullets) | ✅ |
| DetctionArea | 0 | 2 (Player) | ✅ |

### Data Flow

1. **激活**: DetctionArea (mask=Player) → `body_entered(player)` → drone 切换到 CHASE
2. **追逐**: `_physics_process` 中 `direction = (player.global_position - global_position).normalized()` → `velocity = direction * speed` → `move_and_slide()`
3. **撞玩家**: `get_slide_collision()` 检测到 player → 调用 `player.die()` → 实例化 GameOverUI
4. **被子弹打**: `bullet._on_body_entered(drone)` → 检查 `drone.has_method("on_hit_by_bullet")` → `drone.on_hit_by_bullet()` → 切换到 DYING

### Game Over UI

`game_over_ui.tscn`: CanvasLayer + ColorRect(半透明黑底) + VBoxContainer(居中) → Label("Game Over") + Button("重新开始")
- Button 点击 → `get_tree().reload_current_scene()`

### Exports

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `speed` | 150.0 | 追逐飞行速度 |
| `die_anim_name` | "die" | 死亡动画名称 |

### Groups

- Player 加入 `"player"` group
- Bullet 加入 `"bullet"` group
- Drone 加入 `"drone"` group
