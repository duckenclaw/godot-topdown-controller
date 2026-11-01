extends State

## Moving - camera-relative movement on the XZ plane with walk/run toggle and sprint.

func enter() -> void:
	_play()

func update(delta: float) -> String:
	if player.attack_pressed and player.can_attack():
		return "AttackState"
	if player.dash_pressed and player.can_dash():
		return "DashingState"
	if not player.is_moving_input():
		return "IdleState"

	_play()
	player.accelerate(player.move_dir, player.target_move_speed(), delta)
	player.apply_gravity(delta)
	player.move_and_slide()
	return ""

func _play() -> void:
	var walking: bool = player.config.enable_walk_run_toggle and not player.is_running \
		and not (player.config.enable_sprint and Input.is_action_pressed("sprint"))
	player.play_anim("walk" if walking else "run")
