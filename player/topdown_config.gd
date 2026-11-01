class_name TopDownConfig
extends Resource

## Configuration for the top-down character controller. Mirrors the FPS and 2D
## platformer controllers' config resources so tuning and the modular-mechanics
## pattern feel the same across genres.

# Mechanics toggles — turn abilities on/off per game. Disabling one also makes it
# safe to delete that ability's state node from the player's StateMachine (see the
# can_* helpers in topdown_player.gd). Core walking/running has no flag; it always runs.
@export_group("Mechanics")
@export var enable_sprint: bool = true          ## Hold-to-sprint (faster while holding "sprint").
@export var enable_walk_run_toggle: bool = true ## Capslock toggles base speed walk<->run.
@export var enable_dash: bool = true            ## Dodge roll / dash (needs a DashingState node).
@export var enable_attack: bool = true          ## Melee attack combo (needs an AttackState node).
@export var enable_aim: bool = true             ## Face the mouse cursor / right stick instead of the move direction.
@export_group("")

# Ground movement (XZ plane, camera-relative)
@export_group("Movement")
@export var walk_speed: float = 2.5     ## Base speed in "walk" mode (m/s).
@export var run_speed: float = 5.0      ## Base speed in "run" mode (default).
@export var sprint_speed: float = 7.5   ## Speed while holding "sprint".
@export var acceleration: float = 40.0
@export var friction: float = 45.0
@export var turn_speed: float = 14.0    ## How fast the visual turns toward `facing` (rad/s-ish lerp weight).
@export var gravity: float = 25.0
@export var max_fall_speed: float = 30.0
@export_group("")

# Dodge roll / dash
@export_group("Dash")
@export var dash_speed: float = 12.0
@export var dash_duration: float = 0.28
@export var dash_cooldown: float = 0.35
@export var dash_invulnerable: bool = true      ## i-frames during the roll
@export_group("")

# Melee combo
@export_group("Combat")
@export var attack_damage: Array[float] = [10.0, 12.0, 20.0] ## damage per combo hit; length = combo size
@export var attack_combo_window: float = 0.35   ## seconds after a hit's animation to chain the next
@export var attack_lunge: float = 3.0           ## forward speed during a swing
@export var attack_active_start: float = 0.35   ## hitbox opens at this fraction of the swing
@export var attack_active_end: float = 0.75     ## ...and closes here
@export var hurt_stun_time: float = 0.3
@export var hurt_knockback: float = 6.0
@export_group("")

# Aim
@export_group("Aim")
@export var stick_deadzone: float = 0.25        ## right-stick deadzone for aiming
@export_group("")
