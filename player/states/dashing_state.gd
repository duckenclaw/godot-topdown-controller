extends State

## Dashing / dodge roll - a short burst along the move direction (or facing when
## standing still), with i-frames. Plays the "roll" animation (optional mechanic).

var dash_timer: float = 0.0
var dash_dir: Vector3 = Vector3.FORWARD

func enter() -> void:
	dash_timer = player.config.dash_duration
	dash_dir = player.move_dir.normalized() if player.is_moving_input() else player.facing
	player.facing = dash_dir
	player.lock_facing = true
	player.play_anim("roll", true)
	if player.config.dash_invulnerable and player.health:
		player.health.invulnerable = true

func update(delta: float) -> String:
	dash_timer -= delta
	if dash_timer <= 0.0:
		return "MovingState" if player.is_moving_input() else "IdleState"

	player.velocity.x = dash_dir.x * player.config.dash_speed
	player.velocity.z = dash_dir.z * player.config.dash_speed
	player.apply_gravity(delta)
	player.move_and_slide()
	return ""

func exit() -> void:
	player.lock_facing = false
	player.start_dash_cooldown()
	if player.config.dash_invulnerable and player.health:
		player.health.invulnerable = false
