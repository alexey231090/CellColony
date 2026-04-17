extends Control

const POINT_COUNT: int = 64
const SUPERELLIPSE_POWER: float = 4.6

var _time: float = 0.0
var _hover_target: float = 0.0
var _hover_strength: float = 0.0

var thickness_scale: float = 1.0
var outer_glow_color: Color = Color(0.08, 0.52, 0.44, 0.17)
var flesh_color: Color = Color(0.05, 0.28, 0.22, 0.92)
var edge_color: Color = Color(0.18, 0.72, 0.58, 0.82)
var highlight_color: Color = Color(0.78, 1.0, 0.9, 0.34)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_hovered(enabled: bool) -> void:
	_hover_target = 1.0 if enabled else 0.0

func _process(delta: float) -> void:
	_time += delta
	_hover_strength = lerpf(_hover_strength, _hover_target, minf(1.0, delta * 7.5))
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var half_size := Vector2(maxf(20.0, size.x * 0.5 - 18.0), maxf(16.0, size.y * 0.5 - 14.0))
	var membrane_points := PackedVector2Array()

	for i in range(POINT_COUNT):
		var t := TAU * float(i) / float(POINT_COUNT)
		var base_point := _get_superellipse_point(t, half_size)
		var wobble := sin(t * 4.0 + _time * 2.0) * 4.5
		wobble += sin(t * 7.0 - _time * 1.45) * 2.4
		wobble += sin(t * 11.0 + _time * 1.15) * 1.4
		wobble *= 1.0 + _hover_strength * 0.18
		var dir := base_point.normalized()
		membrane_points.append(center + base_point + dir * wobble)

	if membrane_points.is_empty():
		return

	var loop := membrane_points.duplicate()
		
	loop.append(loop[0])

	var outer_glow := outer_glow_color
	outer_glow.a += _hover_strength * 0.08
	var edge := edge_color
	edge.a += _hover_strength * 0.12
	var highlight := highlight_color
	highlight.a += _hover_strength * 0.18

	draw_polyline(loop, outer_glow, (34.0 + _hover_strength * 5.0) * thickness_scale, true)
	draw_polyline(loop, flesh_color, (24.0 + _hover_strength * 3.0) * thickness_scale, true)
	draw_polyline(loop, edge, (14.0 + _hover_strength * 2.0) * thickness_scale, true)
	draw_polyline(loop, highlight, (4.0 + _hover_strength) * thickness_scale, true)

func _get_superellipse_point(angle: float, radii: Vector2) -> Vector2:
	var cos_v := cos(angle)
	var sin_v := sin(angle)
	var x := signf(cos_v) * pow(absf(cos_v), 2.0 / SUPERELLIPSE_POWER) * radii.x
	var y := signf(sin_v) * pow(absf(sin_v), 2.0 / SUPERELLIPSE_POWER) * radii.y
	return Vector2(x, y)
