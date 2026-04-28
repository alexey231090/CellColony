extends Control

const MODE_NONE: int = 0
const MODE_WORLD_NODE: int = 1
const MODE_WORLD_POS: int = 2
const MODE_UI_CONTROL: int = 3

var mode: int = MODE_NONE
var world_target: Node2D = null
var world_position: Vector2 = Vector2.ZERO
var ui_target: Control = null
var camera_ref: Camera2D = null
var visual_offset: Vector2 = Vector2(-18.0, -34.0)
var pulse_time: float = 0.0
var tap_anim_time: float = 0.0
var _has_target: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	custom_minimum_size = Vector2(96.0, 96.0)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	visible = false

func show_pointer() -> void:
	visible = true

func hide_pointer() -> void:
	visible = false

func clear_target() -> void:
	mode = MODE_NONE
	world_target = null
	ui_target = null
	camera_ref = null
	_has_target = false
	hide_pointer()

func set_world_target(target: Node2D, camera: Camera2D) -> void:
	world_target = target
	ui_target = null
	camera_ref = camera
	mode = MODE_WORLD_NODE
	_has_target = is_instance_valid(target) and is_instance_valid(camera)
	if _has_target:
		show_pointer()

func set_world_position(pos: Vector2, camera: Camera2D) -> void:
	world_position = pos
	world_target = null
	ui_target = null
	camera_ref = camera
	mode = MODE_WORLD_POS
	_has_target = is_instance_valid(camera)
	if _has_target:
		show_pointer()

func set_ui_target(control: Control) -> void:
	ui_target = control
	world_target = null
	camera_ref = null
	mode = MODE_UI_CONTROL
	_has_target = is_instance_valid(control)
	if _has_target:
		show_pointer()

func play_tap_hint() -> void:
	tap_anim_time = 0.22

func _process(delta: float) -> void:
	pulse_time += delta
	if tap_anim_time > 0.0:
		tap_anim_time = maxf(0.0, tap_anim_time - delta)

	if not visible:
		return

	var target_pos := _get_target_screen_position()
	if target_pos == Vector2.INF:
		return

	var desired_pos := target_pos + visual_offset - size * 0.5
	position = position.lerp(desired_pos, clampf(delta * 10.0, 0.0, 1.0))
	queue_redraw()

func _get_target_screen_position() -> Vector2:
	match mode:
		MODE_WORLD_NODE:
			if not is_instance_valid(world_target) or not is_instance_valid(camera_ref):
				visible = false
				return Vector2.INF
			visible = true
			return get_viewport().get_canvas_transform() * world_target.global_position
		MODE_WORLD_POS:
			if not is_instance_valid(camera_ref):
				visible = false
				return Vector2.INF
			visible = true
			return get_viewport().get_canvas_transform() * world_position
		MODE_UI_CONTROL:
			if not is_instance_valid(ui_target) or not ui_target.is_inside_tree():
				visible = false
				return Vector2.INF
			visible = true
			return ui_target.get_global_rect().get_center()
	return Vector2.INF

func _draw() -> void:
	var center := size * 0.5
	var pulse := 0.5 + 0.5 * sin(pulse_time * 5.2)
	var tap_ratio := tap_anim_time / 0.22 if tap_anim_time > 0.0 else 0.0
	var tap_offset := lerpf(0.0, 7.0, sin(tap_ratio * PI))
	var pointer_center := center + Vector2(0.0, tap_offset)
	var glow_color := Color(0.65, 0.92, 1.0, 0.14 + pulse * 0.1)
	var fill_color := Color(0.95, 0.98, 1.0, 0.96)
	var shadow_color := Color(0.02, 0.05, 0.09, 0.35)
	var outline_color := Color(0.48, 0.88, 1.0, 0.75)

	draw_circle(pointer_center + Vector2(8.0, 12.0), 18.0, shadow_color)
	draw_circle(pointer_center, 16.0, fill_color)
	draw_circle(pointer_center, 22.0 + pulse * 5.0, glow_color)
	draw_arc(pointer_center, 20.0 + pulse * 7.0, 0.0, TAU, 48, outline_color, 2.0)

	var tip := pointer_center + Vector2(16.0, 18.0)
	var left := pointer_center + Vector2(4.0, 28.0)
	var right := pointer_center + Vector2(24.0, 14.0)
	draw_colored_polygon(PackedVector2Array([tip, left, right]), fill_color)
	draw_polyline(PackedVector2Array([tip, left, right, tip]), outline_color, 2.0)
