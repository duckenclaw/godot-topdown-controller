extends State

## Attack - melee combo (attack1 -> attack2 -> attack3...). Each swing snaps facing
## to the aim, lunges forward, and damages whatever the Hitbox overlaps during the
## active window. Press attack again during a swing (or shortly after) to chain;
## dash cancels the swing (optional mechanic).

var combo_index: int = 0
var timer: float = 0.0
var duration: float = 0.4
var queued: bool = false
var hit_targets: Array = []

func enter() -> void:
	combo_index = 0
	_start_swing()

func update(delta: float) -> String:
	timer += delta
	if player.attack_pressed and timer > 0.05:
		queued = true
	if player.dash_pressed and player.can_dash():
		return "DashingState"

	var cfg: TopDownConfig = player.config
	var t: float = timer / duration
	if t >= cfg.attack_active_start and t <= cfg.attack_active_end:
		hit_targets.append_array(player.hit_overlapping(_damage(), hit_targets))

	var lunge: float = cfg.attack_lunge if t < cfg.attack_active_end else 0.0
	player.velocity.x = player.facing.x * lunge
	player.velocity.z = player.facing.z * lunge
	player.apply_gravity(delta)
	player.move_and_slide()

	if timer >= duration:
		var has_next: bool = combo_index + 1 < cfg.attack_damage.size()
		if queued and has_next:
			combo_index += 1
			_start_swing()
			return ""
		if not has_next or timer >= duration + cfg.attack_combo_window or player.is_moving_input():
			return "MovingState" if player.is_moving_input() else "IdleState"
	return ""

func exit() -> void:
	player.lock_facing = false

func _start_swing() -> void:
	player.lock_facing = false
	player.face_aim_now()
	player.lock_facing = true
	var anim := "attack%d" % (combo_index + 1)
	player.play_anim(anim, true)
	duration = player.anim_duration(anim)
	timer = 0.0
	queued = false
	hit_targets.clear()

func _damage() -> float:
	var dmg: Array[float] = player.config.attack_damage
	return dmg[mini(combo_index, dmg.size() - 1)] if not dmg.is_empty() else 0.0
