@tool
class_name SpriteSheetLayout
extends Resource

## Describes a grid sprite sheet (one texture, fixed cell size) and the animations
## in it, and builds a SpriteFrames from that. Lets you animate a downloaded sheet
## by typing row/column/count per animation instead of clicking frames one by one.
## Assign it to CameraFacingSprite3D.sheet_layout (or call build() yourself).
##
## For packs that ship one texture per animation, use several layouts and merge
## them with build_into(), or build the SpriteFrames by hand in the editor.

@export var texture: Texture2D
@export var cell_size: Vector2i = Vector2i(32, 32)
@export var margin: Vector2i = Vector2i.ZERO    ## pixels before the first cell
@export var separation: Vector2i = Vector2i.ZERO ## pixels between cells
@export var animations: Array[SpriteSheetAnim] = []

func build() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	build_into(frames)
	return frames

## Add (or replace) this layout's animations in an existing SpriteFrames.
func build_into(frames: SpriteFrames) -> void:
	if texture == null or cell_size.x <= 0 or cell_size.y <= 0:
		return
	var tex_size := texture.get_size()
	var columns := int((tex_size.x - margin.x + separation.x) / (cell_size.x + separation.x))
	if columns <= 0:
		return
	for a in animations:
		if a == null:
			continue
		if frames.has_animation(a.name):
			frames.remove_animation(a.name)
		frames.add_animation(a.name)
		frames.set_animation_speed(a.name, a.fps)
		frames.set_animation_loop(a.name, a.loop)
		for i in a.count:
			var idx := a.row * columns + a.column + i
			var cell := Vector2i(idx % columns, idx / columns)
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(
				Vector2(margin + cell * (cell_size + separation)),
				Vector2(cell_size))
			frames.add_frame(a.name, atlas)
