extends Control

const HAND_TEXTURE = preload("res://assets/sprites/tutorHend.png")
const MODE_NONE: int = 0
const MODE_WORLD_NODE: int = 1
const MODE_WORLD_POS: int = 2
const MODE_UI_CONTROL: int = 3
const HAND_DRAW_SIZE: Vector2 = Vector2(78.0, 78.0)
const FINGER_TIP_LOCAL_OFFSET: Vector2 = Vector2(18.0, 18.0)

var mode: int = MODE_NONE
var world_target: Node2D = null
var world_position: Vector2 = Vector2.ZERO
var ui_target: Control = null
var camera_ref: Camera2D = null
var visual_offset: Vector2 = Vector2(-22.0, -38.0)
var pulse_time: float = 0.0
var tap_anim_time: float = 0.0
var show_pulse_rings: bool = true
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
	show_pulse_rings = true
	_has_target = false
	hide_pointer()

func set_pulse_rings_enabled(enabled: bool) -> void:
	show_pulse_rings = enabled
	queue_redraw()

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
	var hand_center := center + Vector2(0.0, tap_offset)
	var finger_tip_point := hand_center + FINGER_TIP_LOCAL_OFFSET
	var glow_color := Color(0.65, 0.92, 1.0, 0.14 + pulse * 0.1)
	var outline_color := Color(0.48, 0.88, 1.0, 0.75)
	var hand_shadow_color := Color(0.02, 0.05, 0.09, 0.22)

	if show_pulse_rings:
		draw_circle(finger_tip_point, 22.0 + pulse * 5.0, glow_color)
		draw_arc(finger_tip_point, 20.0 + pulse * 7.0, 0.0, TAU, 48, outline_color, 2.0)

	if HAND_TEXTURE != null:
		var texture_size := HAND_TEXTURE.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			var draw_pos := finger_tip_point - FINGER_TIP_LOCAL_OFFSET - HAND_DRAW_SIZE * 0.5
			var shadow_rect := Rect2(draw_pos + Vector2(4.0, 6.0), HAND_DRAW_SIZE)
			var hand_rect := Rect2(draw_pos, HAND_DRAW_SIZE)
			draw_texture_rect(HAND_TEXTURE, shadow_rect, false, hand_shadow_color)
			draw_texture_rect(HAND_TEXTURE, hand_rect, false, Color.WHITE)
