class_name SpriteSheetAnim
extends Resource

## One animation cut from a grid sprite sheet: `count` cells starting at
## (`column`, `row`), read left-to-right (wrapping to the next row if needed).
## Name directional variants with a suffix — idle_down / idle_up / idle_side (or
## idle_left / idle_right) — and CameraFacingSprite3D picks the right one.

@export var name: StringName = &"idle"
@export var row: int = 0
@export var column: int = 0
@export var count: int = 4
@export var fps: float = 10.0
@export var loop: bool = true
