extends State

## Idle - no move input; friction brings the character to a stop.

func enter() -> void:
	player.play_anim("idle")

func update(delta: float) -> String:
	if player.attack_pressed and player.can_attack():
		return "AttackState"
	if player.dash_pressed and player.can_dash():
		return "DashingState"
	if player.is_moving_input():
		return "MovingState"

	player.accelerate(Vector3.ZERO, 0.0, delta)
	player.apply_gravity(delta)
	player.move_and_slide()
	return ""
