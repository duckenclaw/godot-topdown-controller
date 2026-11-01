extends State

## Death - plays "death" once and stops all movement. Terminal state; respawn logic
## (e.g. Health.revive + transition_to("IdleState")) belongs to the game.

func enter() -> void:
	player.velocity = Vector3.ZERO
	player.play_anim("death", true)

func update(_delta: float) -> String:
	return ""
