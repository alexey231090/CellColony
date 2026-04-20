extends Node2D

var pulse_time: float = 0.0

func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()

func _draw() -> void:
	var outer_pulse := (sin(pulse_time * 2.8) + 1.0) * 0.5
	var inner_pulse := (sin(pulse_time * 4.4 + 0.8) + 1.0) * 0.5

	var outer_color := Color(0.84, 0.86, 0.9, 0.2 + outer_pulse * 0.08)
	var ring_color := Color(0.9, 0.92, 0.96, 0.58 + outer_pulse * 0.12)
	var core_color := Color(0.95, 0.97, 1.0, 0.24 + inner_pulse * 0.1)

	var outer_radius := 28.0 + outer_pulse * 4.0
	var ring_radius := 20.0 + inner_pulse * 2.5

	draw_arc(Vector2.ZERO, outer_radius, 0.0, TAU, 48, outer_color, 2.0, true)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 40, ring_color, 3.0, true)
	draw_circle(Vector2.ZERO, 7.0 + inner_pulse * 1.6, core_color)

	for i in range(4):
		var angle := pulse_time * 0.55 + i * (TAU / 4.0)
		var dir := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-dir.y, dir.x)
		var marker_center := dir * (ring_radius + 3.0)
		var droplet := PackedVector2Array([
			marker_center + dir * 5.0,
			marker_center - dir * 2.0 + tangent * 2.5,
			marker_center - dir * 3.8,
			marker_center - dir * 2.0 - tangent * 2.5,
		])
		var droplet_color := ring_color
		droplet_color.a *= 0.7
		draw_colored_polygon(droplet, droplet_color)
