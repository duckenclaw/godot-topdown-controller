extends State

## Hurt - brief stun with knockback after taking damage (velocity set by the player).

var timer: float = 0.0

func enter() -> void:
	timer = player.config.hurt_stun_time
	player.lock_facing = true
	player.play_anim("hurt", true)

func update(delta: float) -> String:
	timer -= delta
	player.accelerate(Vector3.ZERO, 0.0, delta)
	player.apply_gravity(delta)
	player.move_and_slide()
	if timer <= 0.0:
		return "MovingState" if player.is_moving_input() else "IdleState"
	return ""

func exit() -> void:
	player.lock_facing = false
