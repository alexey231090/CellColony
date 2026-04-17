extends Control
class_name OrganicLoadingSpinner

var _time: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(180.0, 180.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var pulse := 1.0 + sin(_time * 2.2) * 0.05
	var nucleus_radius := minf(size.x, size.y) * 0.17 * pulse

	var glow_color := Color(0.24, 0.76, 1.0, 0.18 + sin(_time * 2.6) * 0.04)
	draw_circle(center, nucleus_radius * 2.25, glow_color)
	draw_circle(center, nucleus_radius * 1.55, Color(0.15, 0.58, 1.0, 0.12))

	var nucleus_color := Color(0.48, 0.72, 1.0, 0.95)
	var core_color := Color(0.72, 0.86, 1.0, 0.95)
	draw_circle(center, nucleus_radius, nucleus_color)
	draw_circle(center, nucleus_radius * 0.52, core_color)

	var highlight_pos := center + Vector2(-nucleus_radius * 0.32, -nucleus_radius * 0.34)
	draw_circle(highlight_pos, nucleus_radius * 0.2, Color(1.0, 1.0, 1.0, 0.95))

	for i in range(3):
		var orbit_angle := _time * (1.25 + i * 0.22) + (TAU / 3.0) * i
		var orbit_radius := nucleus_radius * (1.7 + sin(_time * 1.6 + i * 0.7) * 0.08)
		var organelle_pos := center + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
		var organelle_radius := nucleus_radius * (0.18 + i * 0.015)
		var organelle_color := Color(0.52, 0.9, 1.0, 0.78 - i * 0.08)
		draw_circle(organelle_pos, organelle_radius * 1.8, Color(organelle_color.r, organelle_color.g, organelle_color.b, 0.12))
		draw_circle(organelle_pos, organelle_radius, organelle_color)
