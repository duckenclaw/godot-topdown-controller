extends Node3D

## Placeholder 3D character for the top-down controller: a capsule body, head,
## visor (shows which way it faces) and a sword on a pivot, plus a procedurally
## built AnimationPlayer with the same animation names the sprite flavour uses
## (idle, run, walk, attack1-3, roll, hurt, death). Replace this whole node with
## your own model (an imported glTF with its AnimationPlayer works as-is).

@onready var body: Node3D = $Body
@onready var sword_pivot: Node3D = $Body/SwordPivot

func _ready() -> void:
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	add_child(ap)
	var lib := AnimationLibrary.new()
	var rest_y := body.position.y
	var sword_rest := sword_pivot.rotation

	lib.add_animation(&"idle", _anim(1.2, true, [
		["Body:position", [0.0, 0.6, 1.2], [Vector3(0, rest_y, 0), Vector3(0, rest_y + 0.03, 0), Vector3(0, rest_y, 0)]],
	]))
	lib.add_animation(&"run", _anim(0.4, true, [
		["Body:position", [0.0, 0.1, 0.2, 0.3, 0.4], [Vector3(0, rest_y, 0), Vector3(0, rest_y + 0.08, 0), Vector3(0, rest_y, 0), Vector3(0, rest_y + 0.08, 0), Vector3(0, rest_y, 0)]],
		["Body:rotation", [0.0, 0.4], [Vector3(-0.15, 0, 0), Vector3(-0.15, 0, 0)]],
	]))
	lib.add_animation(&"walk", _anim(0.7, true, [
		["Body:position", [0.0, 0.175, 0.35, 0.525, 0.7], [Vector3(0, rest_y, 0), Vector3(0, rest_y + 0.04, 0), Vector3(0, rest_y, 0), Vector3(0, rest_y + 0.04, 0), Vector3(0, rest_y, 0)]],
	]))
	# Three swings: right-to-left, left-to-right, overhead.
	lib.add_animation(&"attack1", _anim(0.35, false, [
		["Body/SwordPivot:rotation", [0.0, 0.12, 0.35], [Vector3(0, 1.4, 0), Vector3(0, -1.4, 0), sword_rest]],
	]))
	lib.add_animation(&"attack2", _anim(0.35, false, [
		["Body/SwordPivot:rotation", [0.0, 0.12, 0.35], [Vector3(0, -1.4, 0), Vector3(0, 1.4, 0), sword_rest]],
	]))
	lib.add_animation(&"attack3", _anim(0.5, false, [
		["Body/SwordPivot:rotation", [0.0, 0.2, 0.32, 0.5], [sword_rest, Vector3(1.6, 0, 0), Vector3(-1.2, 0, 0), sword_rest]],
	]))
	lib.add_animation(&"roll", _anim(0.28, false, [
		["Body:rotation", [0.0, 0.28], [Vector3.ZERO, Vector3(-TAU, 0, 0)]],
		["Body:position", [0.0, 0.14, 0.28], [Vector3(0, rest_y, 0), Vector3(0, rest_y - 0.35, 0), Vector3(0, rest_y, 0)]],
	]))
	lib.add_animation(&"hurt", _anim(0.3, false, [
		["Body:rotation", [0.0, 0.08, 0.3], [Vector3.ZERO, Vector3(0.4, 0, 0), Vector3.ZERO]],
	]))
	lib.add_animation(&"death", _anim(0.6, false, [
		["Body:rotation", [0.0, 0.6], [Vector3.ZERO, Vector3(PI / 2.0, 0, 0)]],
		["Body:position", [0.0, 0.6], [Vector3(0, rest_y, 0), Vector3(0, 0.3, 0)]],
	]))
	ap.add_animation_library(&"", lib)

## tracks: [[path, times[], values[]], ...]
func _anim(length: float, loop: bool, tracks: Array) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for t in tracks:
		var i := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(i, NodePath(t[0]))
		for k in t[1].size():
			a.track_insert_key(i, t[1][k], t[2][k])
	return a
