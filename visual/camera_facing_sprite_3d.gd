@tool
class_name CameraFacingSprite3D
extends AnimatedSprite3D

## A 2D animated sprite living in the 3D world (2.5D / "HD-2D" look). Instead of a
## billboard it turns its real quad to the camera's yaw every frame, so it casts and
## receives proper 3D shadows and is lit by every light in the scene.
##
## Directional animations: set `direction` (a world XZ vector — the player does this
## from `facing`) and play_directional(["run"]) picks, in order:
##   run_down / run_up        when facing toward / away from the camera
##   run_left / run_right     when facing sideways (no flip)
##   run_side                 sideways, flipped to match (art faces right unless
##                            faces_right is off)
##   run                      plain fallback (side-view art like a platformer sheet)
## so a 4-direction top-down sheet and a single side-view sheet both just work.

## Side-view art faces right (flip_h when moving left). Turn off for left-facing art.
@export var faces_right: bool = true
## 0 = stay upright (best shadows). 1 = lean back to fully face a pitched camera
## (no vertical squash from steep cameras). Somewhere around 0.3-0.5 is a good mix.
@export_range(0.0, 1.0) var tilt: float = 0.0
## Optional: build sprite_frames from a grid sprite sheet description.
@export var sheet_layout: SpriteSheetLayout:
	set(v):
		sheet_layout = v
		if sheet_layout:
			sprite_frames = sheet_layout.build()

## World-space XZ facing used to choose directional variants.
var direction: Vector3 = Vector3.FORWARD

var _names: Array[String] = []
var _base: String = ""

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_DISABLED
	if sheet_layout and sprite_frames == null:
		sprite_frames = sheet_layout.build()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_face_camera()
	_refresh(false)

func _face_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var r := cam.global_rotation
	global_rotation = Vector3(r.x * tilt, r.y, 0.0)

## Play the first animation in `names` that exists (with a directional suffix if
## available). Re-evaluated every frame, so turning re-picks the direction while
## keeping the current frame.
func play_directional(names: Array[String], restart: bool = false) -> void:
	_names = names
	_refresh(restart)

## Seconds the first matching animation lasts (frames / fps).
func duration_of(names: Array[String], fallback: float = 0.4) -> float:
	var anim := _resolve(names)[0] as String
	if anim != "" and sprite_frames:
		var s := sprite_frames.get_animation_speed(anim) * absf(speed_scale)
		if s > 0.0:
			return sprite_frames.get_frame_count(anim) / s
	return fallback

## Camera-relative facing: x > 0 right on screen, z > 0 toward the camera (down).
func screen_direction() -> Vector2:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var yaw := cam.global_rotation.y if cam else 0.0
	var d := direction.rotated(Vector3.UP, -yaw)
	return Vector2(d.x, d.z)

func _refresh(restart: bool) -> void:
	if sprite_frames == null or _names.is_empty():
		return
	var res := _resolve(_names)
	var anim: String = res[0]
	if anim == "":
		return
	if res[1] != null:
		flip_h = res[1]
	var base: String = res[2]
	if restart:
		play(anim)
		frame = 0
		frame_progress = 0.0
	elif String(animation) != anim:
		# Same logical animation in a new direction keeps its place in the cycle.
		var keep := base == _base
		var f := frame
		var p := frame_progress
		play(anim)
		if keep and f < sprite_frames.get_frame_count(anim):
			set_frame_and_progress(f, p)
	elif not is_playing() and sprite_frames.get_animation_loop(anim):
		play(anim)
	_base = base

## -> [animation name or "", flip_h or null, logical base name]
func _resolve(names: Array[String]) -> Array:
	if sprite_frames == null:
		return ["", null, ""]
	var sd := screen_direction()
	var side := absf(sd.x) >= absf(sd.y)
	var right := sd.x >= 0.0
	var flip: Variant = (not right) if faces_right else right
	var options: Array = []
	if side:
		options = [["_right" if right else "_left", false], ["_side", flip], ["", flip]]
	elif sd.y > 0.0:
		options = [["_down", null], ["_side", null], ["", null]]
	else:
		options = [["_up", null], ["_side", null], ["", null]]
	for n in names:
		for o in options:
			if sprite_frames.has_animation(n + o[0]):
				return [n + o[0], o[1], n]
	return ["", null, ""]
