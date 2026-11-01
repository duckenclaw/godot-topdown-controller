class_name TopDownCamera
extends Node3D

## Top-down / isometric camera rig. Follows `target` from a fixed pitch and distance,
## with optional smoothing, mouse-wheel zoom, 45° snap rotation (Q/E or shoulder
## buttons), perspective or orthographic projection, and a simple screen shake.
##
## Works as a child of the player (it sets itself top_level so it does not inherit
## the player's transform) or as a free node in the level with `target` assigned.
## Yaw 0 looks down -Z; the player reads get_yaw() to make movement camera-relative.

enum ProjectionMode { PERSPECTIVE, ORTHOGONAL }

@export var target: Node3D
@export var projection_mode: ProjectionMode = ProjectionMode.PERSPECTIVE:
	set(v):
		projection_mode = v
		_apply_lens()
@export_range(10.0, 90.0) var pitch_degrees: float = 55.0  ## 90 = straight down
@export var distance: float = 14.0                          ## from focus point (perspective)
@export_range(10.0, 90.0) var fov: float = 40.0
@export var ortho_size: float = 14.0                        ## visible height in metres (orthogonal)
@export var focus_offset: Vector3 = Vector3(0.0, 0.8, 0.0)  ## look at the target's chest, not its feet
@export var follow_smoothing: float = 8.0                   ## 0 = snap to target every frame
@export var yaw_degrees: float = 0.0                        ## initial yaw

@export_group("Zoom")
@export var enable_zoom: bool = true
@export var zoom_min: float = 0.5
@export var zoom_max: float = 1.8
@export var zoom_step: float = 0.1
@export var zoom_smoothing: float = 10.0
@export_group("")

@export_group("Rotation")
@export var enable_rotation: bool = true
@export var rotation_step_degrees: float = 45.0
@export var rotation_smoothing: float = 10.0
@export_group("")

var camera: Camera3D

var _yaw: float = 0.0
var _target_yaw: float = 0.0
var _zoom: float = 1.0
var _target_zoom: float = 1.0
var _shake_strength: float = 0.0
var _shake_time: float = 0.0

func _ready() -> void:
	top_level = true
	camera = get_node_or_null("Camera3D")
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	_yaw = deg_to_rad(yaw_degrees)
	_target_yaw = _yaw
	_apply_lens()
	snap()

func _process(delta: float) -> void:
	_yaw = lerp_angle(_yaw, _target_yaw, _weight(rotation_smoothing, delta))
	_zoom = lerpf(_zoom, _target_zoom, _weight(zoom_smoothing, delta))
	if target and is_instance_valid(target):
		global_position = global_position.lerp(target.global_position + focus_offset, _weight(follow_smoothing, delta))
	_apply_transform(delta)

func _unhandled_input(event: InputEvent) -> void:
	if enable_zoom:
		if event.is_action_pressed("camera_zoom_in"):
			_target_zoom = clampf(_target_zoom - zoom_step, zoom_min, zoom_max)
		elif event.is_action_pressed("camera_zoom_out"):
			_target_zoom = clampf(_target_zoom + zoom_step, zoom_min, zoom_max)
	if enable_rotation:
		if event.is_action_pressed("camera_rotate_left"):
			_target_yaw -= deg_to_rad(rotation_step_degrees)
		elif event.is_action_pressed("camera_rotate_right"):
			_target_yaw += deg_to_rad(rotation_step_degrees)

## Current (smoothed) yaw in radians. 0 = camera looks down -Z.
func get_yaw() -> float:
	return _yaw

## Jump straight to the target and the target yaw/zoom (e.g. after a teleport).
func snap() -> void:
	_yaw = _target_yaw
	_zoom = _target_zoom
	if target and is_instance_valid(target):
		global_position = target.global_position + focus_offset
	_apply_transform(0.0)

func set_yaw_degrees(deg: float, instant: bool = false) -> void:
	_target_yaw = deg_to_rad(deg)
	if instant:
		_yaw = _target_yaw

func shake(strength: float = 0.25, duration: float = 0.2) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_time = maxf(_shake_time, duration)

func _apply_transform(delta: float) -> void:
	if camera == null:
		return
	rotation = Vector3(0.0, _yaw, 0.0)
	var pitch := deg_to_rad(pitch_degrees)
	var d := distance * _zoom
	if projection_mode == ProjectionMode.ORTHOGONAL:
		camera.size = ortho_size * _zoom
		d = maxf(distance, 20.0)  # far enough back that nothing clips the near plane
	var offset := Vector3.ZERO
	if _shake_time > 0.0:
		_shake_time -= delta
		offset = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * _shake_strength
		if _shake_time <= 0.0:
			_shake_strength = 0.0
	camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * d + offset
	camera.rotation = Vector3(-pitch, 0.0, 0.0)

func _apply_lens() -> void:
	if camera == null:
		return
	if projection_mode == ProjectionMode.ORTHOGONAL:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = ortho_size * _zoom
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = fov

static func _weight(smoothing: float, delta: float) -> float:
	return 1.0 if smoothing <= 0.0 else clampf(smoothing * delta, 0.0, 1.0)
