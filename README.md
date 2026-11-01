# Top-Down Controller (`topdown_controller`)

A state-machine top-down character controller for Godot 4, built on **3D nodes**
so 3D models drop straight in, with a **2.5D sprite** option for 2D art that is lit
by 3D lights and casts real shadows. Mechanics are modular (config flags + removable
state nodes), mirroring the FPS and 2D platformer controllers.

Part of the **[godot-game-kit](https://github.com/duckenclaw/godot-game-kit)**
ecosystem. Ready-made starter: **[topdown-godot-template](https://github.com/duckenclaw/topdown-godot-template)**.

## Features

- **Camera-relative movement** on the XZ plane: walk/run toggle, hold-to-sprint,
  keyboard, mouse and gamepad defaults out of the box.
- **Dodge roll** with i-frames and cooldown.
- **Melee combo** (`attack1` → `attack2` → `attack3`, any length) with lunge, a
  `Hitbox` Area3D that damages anything with `take_damage()` or a `Health` child,
  and dash-cancel.
- **Aim** at the mouse cursor (ground-plane raycast) or with the right stick
  (twin-stick); falls back to facing the move direction.
- **Health reactions**: hurt (knockback + stun) and death states, plus `respawn()`.
- **`TopDownCamera` rig**: smooth follow, perspective or orthographic, pitch/
  distance, mouse-wheel zoom, 45° snap rotation (Q/E, shoulder buttons), shake.
- **Two looks, one controller** — states only call `play_anim("run")`:
  - **3D model** (`player/player_3d.tscn`): any Node3D under `Visual`; it turns to
    face the aim, and an `AnimationPlayer` under it is driven by name. Ships a
    placeholder mannequin with idle/run/walk/attack1-3/roll/hurt/death.
  - **2.5D sprite** (`player/player_sprite.tscn`): a `CameraFacingSprite3D` — an
    `AnimatedSprite3D` that turns its quad to the camera's yaw (no billboard), so it
    is lit, receives shadows and casts a proper silhouette shadow.
- **Directional animations**: name them `run_down` / `run_up` / `run_side` (or
  `_left` / `_right`) and the sprite picks one from the facing and camera; plain
  `run` works for side-view art (flipped automatically).
- **`SpriteSheetLayout`**: describe a grid sheet (cell size + rows/columns/count/
  fps per animation) and it builds the `SpriteFrames` for you.

## Install

**Git submodule (recommended)** — root-layout, drops into `addons/`:

```bash
git submodule add https://github.com/duckenclaw/godot-topdown-controller addons/topdown_controller
git submodule add https://github.com/duckenclaw/godot-components-kit addons/components_kit
git submodule update --init
```

Enable **Top-Down Controller** and **Components Kit** in *Project Settings → Plugins*,
then instance `player/player_3d.tscn` or `player/player_sprite.tscn` (assign your
`SpriteFrames`, or a `SpriteSheetLayout`, to `Visual/Sprite`).

## Dependencies

- **godot-components-kit** (`StateMachine`, `State`, `Health`).

## Modular mechanics

Turn abilities off via `TopDownConfig` flags (`enable_sprint`,
`enable_walk_run_toggle`, `enable_dash`, `enable_attack`, `enable_aim`) or delete the
matching state node (`DashingState`, `AttackState`) from the player's
`StateMachine`. Core movement is always on.

## Input actions

Registered at startup only if your project hasn't defined them (Input Map wins):
`move_left/right/up/down`, `aim_left/right/up/down` (right stick), `attack`, `dash`,
`sprint`, `interact`, `walk_run_toggle`, `camera_rotate_left/right`,
`camera_zoom_in/out`, `pause`. Defaults live in `TopDownPlayer.DEFAULT_KEYS` & co.

## Notes

- With **Jolt Physics**, keep `monitorable` on for areas that must see static
  bodies; the shipped `Hitbox` and `InteractArea` already do.
- For crisp sprite shadows keep `alpha_cut` = Discard and `shaded` on (the default
  in `player_sprite.tscn`), and light the scene with shadow-casting lights.

## License

MIT — see [LICENSE](LICENSE).
