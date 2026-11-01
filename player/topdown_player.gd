class_name TopDownPlayer
extends CharacterBody3D

## Top-down character controller for 3D worlds. Moves on the XZ plane relative to
## the camera, so it works with any camera angle or rotation. State-machine driven
## (reuses the shared StateMachine/State from the Components Kit) with the same
## modular-mechanics pattern as the FPS and 2D controllers: abilities toggle via
## TopDownConfig flags, and optional state nodes can be deleted to remove a mechanic.
##
## The look lives under the `Visual` node and comes in two flavours:
##   * 3D model   — any Node3D/imported glTF; it is turned to face `facing`, and an
##                  AnimationPlayer found under Visual is driven by play_anim().
##   * 2.5D sprite — a CameraFacingSprite3D under Visual; it stays upright facing the
##                  camera (so it casts real shadows) and picks directional animations
##                  (idle_down / idle_up / idle_side ...) from `facing`.
## States only ever call play_anim("run") etc., so both flavours share all logic.

enum AimSource { NONE, MOUSE, STICK }

@export var config: TopDownConfig

@onready var visual: Node3D = get_node_or_null("Visual")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var camera_rig: TopDownCamera = get_node_or_null("CameraRig")
@onready var state_machine: StateMachine = $StateMachine
@onready var health: Health = get_node_or_null("Health")
@onready var hitbox: Area3D = get_node_or_null("Hitbox")

# Input flags (set each physics frame, read by states)
var dash_pressed: bool = false
var attack_pressed: bool = false

# Movement state
var is_running: bool = true            # walk/run toggle (Capslock); true = run
var move_dir: Vector3 = Vector3.ZERO   # camera-relative desired direction on XZ, length 0..1
var facing: Vector3 = Vector3.FORWARD  # unit XZ direction the character looks/attacks in
var lock_facing: bool = false          # states (attack, dash) freeze facing while active
var aim_source: AimSource = AimSource.NONE
var is_dead: bool = false

# Game state
var is_paused: bool = false

var sprite: CameraFacingSprite3D
var anim_player: AnimationPlayer

var _dash_cooldown: float = 0.0

func _ready() -> void:
	if not config:
		config = TopDownConfig.new()
	_ensure_default_actions()
	_find_visuals()
	if camera_rig and camera_rig.target == null:
		camera_rig.target = self
	# Route health events into the reaction states.
	if health:
		if not health.damaged.is_connected(_on_damaged):
			health.damaged.connect(_on_damaged)
		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	if is_paused or is_dead:
		return

	dash_pressed = Input.is_action_just_pressed("dash")
	attack_pressed = Input.is_action_just_pressed("attack")
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)

	move_dir = get_move_direction()
	if not lock_facing:
		_update_facing()
	_update_visual(delta)

func _input(event: InputEvent) -> void:
	if is_paused or is_dead:
		return
	if event is InputEventMouseMotion:
		aim_source = AimSource.MOUSE
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		if aim_source == AimSource.MOUSE:
			aim_source = AimSource.NONE
	if config.enable_walk_run_toggle and event.is_action_pressed("walk_run_toggle"):
		is_running = not is_running
	if event.is_action_pressed("interact"):
		_try_interact()

# ---- Movement helpers -------------------------------------------------------

## Raw 2D move input (x = right, y = down on screen).
func get_move_input() -> Vector2:
	if is_paused or is_dead:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

## Move input converted to a world XZ direction relative to the camera's yaw.
func get_move_direction() -> Vector3:
	var v := get_move_input()
	return Vector3(v.x, 0.0, v.y).rotated(Vector3.UP, camera_yaw())

func is_moving_input() -> bool:
	return move_dir.length() > 0.05

func base_move_speed() -> float:
	if config.enable_walk_run_toggle and not is_running:
		return config.walk_speed
	return config.run_speed

func target_move_speed() -> float:
	if config.enable_sprint and Input.is_action_pressed("sprint"):
		return config.sprint_speed
	return base_move_speed()

## Accelerate the horizontal velocity toward `dir * speed` (dir length 0..1).
func accelerate(dir: Vector3, speed: float, delta: float) -> void:
	var target := dir * speed
	var rate := config.acceleration if dir.length() > 0.05 else config.friction
	var h := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = h.x
	velocity.z = h.z

func apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y = maxf(velocity.y - config.gravity * delta, -config.max_fall_speed)

## Yaw of the active camera (0 = looking down -Z). Movement and aim are relative to it.
func camera_yaw() -> float:
	if camera_rig:
		return camera_rig.get_yaw()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_rotation.y if cam else 0.0

# ---- Aim / facing -------------------------------------------------------------

func _update_facing() -> void:
	var aim := get_aim_direction()
	if aim != Vector3.ZERO:
		facing = aim
	elif is_moving_input():
		facing = move_dir.normalized()

## The direction the player is aiming (right stick, then mouse), or ZERO when not
## aiming (aim disabled, or no aim input) — callers then fall back to move_dir.
func get_aim_direction() -> Vector3:
	if not config.enable_aim:
		return Vector3.ZERO
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", config.stick_deadzone)
	if stick != Vector2.ZERO:
		aim_source = AimSource.STICK
		return Vector3(stick.x, 0.0, stick.y).rotated(Vector3.UP, camera_yaw()).normalized()
	if aim_source == AimSource.STICK:
		aim_source = AimSource.NONE
	if aim_source == AimSource.MOUSE:
		var p: Variant = mouse_ground_point()
		if p != null:
			var d: Vector3 = (p as Vector3) - global_position
			d.y = 0.0
			if d.length() > 0.2:
				return d.normalized()
	return Vector3.ZERO

## Where the mouse cursor hits the horizontal plane at the player's feet (or null).
func mouse_ground_point() -> Variant:
	if not is_inside_tree():
		return null
	var cam: Camera3D = camera_rig.camera if camera_rig else get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	var plane := Plane(Vector3.UP, global_position.y)
	return plane.intersects_ray(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))

## Snap facing to the current aim (used at the start of an attack swing).
func face_aim_now() -> void:
	var aim := get_aim_direction()
	if aim != Vector3.ZERO:
		facing = aim
	elif is_moving_input():
		facing = move_dir.normalized()

## Yaw that makes a node's -Z axis point along `dir`.
static func yaw_for(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)

# ---- Visual / animation ------------------------------------------------------

func _find_visuals() -> void:
	if visual == null:
		return
	for n in visual.find_children("*", "CameraFacingSprite3D", true, false):
		sprite = n
		break
	if sprite == null and visual is CameraFacingSprite3D:
		sprite = visual
	for n in visual.find_children("*", "AnimationPlayer", true, false):
		anim_player = n
		break

func _update_visual(delta: float) -> void:
	if hitbox:
		hitbox.rotation.y = yaw_for(facing)
	if sprite:
		sprite.direction = facing
	elif visual:
		visual.rotation.y = lerp_angle(visual.rotation.y, yaw_for(facing), clampf(config.turn_speed * delta, 0.0, 1.0))

## Play an animation by logical name ("idle", "run", "attack1", "roll", "hurt",
## "death"...). Falls back to common aliases so art packs with slightly different
## names still work (see anim_candidates). `restart` replays it from frame 0.
func play_anim(anim: String, restart: bool = false) -> void:
	var names := anim_candidates(anim)
	if sprite:
		sprite.play_directional(names, restart)
		return
	if anim_player:
		for n in names:
			if anim_player.has_animation(n):
				if restart or anim_player.current_animation != n or not anim_player.is_playing():
					anim_player.stop()
					anim_player.play(n)
				return

## Length in seconds of an animation — used by one-shot states (attack, roll, hurt).
func anim_duration(anim: String, fallback: float = 0.4) -> float:
	var names := anim_candidates(anim)
	if sprite:
		return sprite.duration_of(names, fallback)
	if anim_player:
		for n in names:
			if anim_player.has_animation(n):
				return anim_player.get_animation(n).length / maxf(anim_player.speed_scale, 0.001)
	return fallback

## Logical name -> ordered list of animation names to try.
static func anim_candidates(anim: String) -> Array[String]:
	var out: Array[String] = [anim]
	match anim:
		"walk": out.append("run")
		"run": out.append("walk")
		"roll": out.append_array(["dash", "dodge"])
		"hurt": out.append_array(["hit", "damage"])
		"death": out.append_array(["die", "dead"])
	if anim.begins_with("attack") and anim != "attack":
		out.append_array(["attack1", "attack"])
	return out

# ---- Optional-mechanic gates (flag AND state node present) -------------------

func _has_state(state_name: String) -> bool:
	return state_machine != null and state_machine.has_state(state_name)

func can_dash() -> bool:
	return config.enable_dash and _dash_cooldown <= 0.0 and _has_state("DashingState")

func can_attack() -> bool:
	return config.enable_attack and _has_state("AttackState")

func start_dash_cooldown() -> void:
	_dash_cooldown = config.dash_cooldown

# ---- Combat -----------------------------------------------------------------

## Damage everything overlapping the Hitbox that is not in `already_hit` (and not
## us). Returns the newly hit targets. Targets either expose take_damage(amount,
## source) themselves or carry a Health child.
func hit_overlapping(amount: float, already_hit: Array) -> Array:
	var hits: Array = []
	if hitbox == null:
		return hits
	var candidates: Array = hitbox.get_overlapping_bodies() + hitbox.get_overlapping_areas()
	for c in candidates:
		if c == self or already_hit.has(c):
			continue
		var target: Object = null
		if c.has_method("take_damage"):
			target = c
		else:
			target = c.get_node_or_null("Health")
		if target and target.has_method("take_damage"):
			target.take_damage(amount, self)
			hits.append(c)
	return hits

func take_damage(amount: float, source: Node = null) -> void:
	if health:
		health.take_damage(amount, source)

# ---- Health reactions -------------------------------------------------------

func _on_damaged(_amount: float, source: Node) -> void:
	if is_dead:
		return
	if _has_state("HurtState"):
		# Knock back away from the damage source.
		var away := -facing
		if source is Node3D:
			away = global_position - (source as Node3D).global_position
			away.y = 0.0
			away = away.normalized() if away.length() > 0.01 else -facing
		velocity.x = away.x * config.hurt_knockback
		velocity.z = away.z * config.hurt_knockback
		state_machine.transition_to("HurtState")

func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	if _has_state("DeathState"):
		state_machine.transition_to("DeathState")

## Bring the player back after death (optionally at `at`), at full health.
func respawn(at: Variant = null) -> void:
	if at is Vector3:
		global_position = at
	velocity = Vector3.ZERO
	is_dead = false
	if health:
		health.revive()
	if _has_state("IdleState"):
		state_machine.transition_to("IdleState")
	if camera_rig:
		camera_rig.snap()

# ---- Interaction ------------------------------------------------------------

func _try_interact() -> void:
	var area: Area3D = get_node_or_null("InteractArea")
	if area == null:
		return
	for body in area.get_overlapping_bodies():
		if body != self and body.has_method("interact"):
			body.interact()
			return
	for a in area.get_overlapping_areas():
		if a.has_method("interact"):
			a.interact()
			return

# ---- Input provisioning -----------------------------------------------------

## Default bindings: action -> keys, mouse buttons and joypad inputs. Registered only
## if the project hasn't defined the action, so InputMap / rebinds always win.
const DEFAULT_KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"attack": [KEY_J],
	"dash": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"interact": [KEY_F],
	"walk_run_toggle": [KEY_CAPSLOCK],
	"camera_rotate_left": [KEY_Q],
	"camera_rotate_right": [KEY_E],
	"pause": [KEY_ESCAPE],
}
const DEFAULT_MOUSE := {
	"attack": [MOUSE_BUTTON_LEFT],
	"dash": [MOUSE_BUTTON_RIGHT],
	"camera_zoom_in": [MOUSE_BUTTON_WHEEL_UP],
	"camera_zoom_out": [MOUSE_BUTTON_WHEEL_DOWN],
}
const DEFAULT_JOY_BUTTONS := {
	"attack": [JOY_BUTTON_X],
	"dash": [JOY_BUTTON_B],
	"sprint": [JOY_BUTTON_LEFT_STICK],
	"interact": [JOY_BUTTON_Y],
	"camera_rotate_left": [JOY_BUTTON_LEFT_SHOULDER],
	"camera_rotate_right": [JOY_BUTTON_RIGHT_SHOULDER],
	"pause": [JOY_BUTTON_START],
}
## action -> [axis, direction]
const DEFAULT_JOY_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	"aim_left": [JOY_AXIS_RIGHT_X, -1.0],
	"aim_right": [JOY_AXIS_RIGHT_X, 1.0],
	"aim_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"aim_down": [JOY_AXIS_RIGHT_Y, 1.0],
}

## Register every default action that the project hasn't defined yet. Static so a
## settings autoload can call it before loading saved rebinds.
static func ensure_default_actions() -> void:
	var actions := {}
	for d in [DEFAULT_KEYS, DEFAULT_MOUSE, DEFAULT_JOY_BUTTONS, DEFAULT_JOY_AXES]:
		for a in d:
			actions[a] = true
	for action in actions:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for kc in DEFAULT_KEYS.get(action, []):
			var ev := InputEventKey.new()
			ev.physical_keycode = kc
			InputMap.action_add_event(action, ev)
		for mb in DEFAULT_MOUSE.get(action, []):
			var ev := InputEventMouseButton.new()
			ev.button_index = mb
			InputMap.action_add_event(action, ev)
		for jb in DEFAULT_JOY_BUTTONS.get(action, []):
			var ev := InputEventJoypadButton.new()
			ev.button_index = jb
			InputMap.action_add_event(action, ev)
		if DEFAULT_JOY_AXES.has(action):
			var ev := InputEventJoypadMotion.new()
			ev.axis = DEFAULT_JOY_AXES[action][0]
			ev.axis_value = DEFAULT_JOY_AXES[action][1]
			InputMap.action_add_event(action, ev)

func _ensure_default_actions() -> void:
	ensure_default_actions()
