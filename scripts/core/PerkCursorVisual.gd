extends Node2D

var radius: float = 80.0
var color: Color = Color(0.2, 1.0, 0.5, 0.15)
var outline_color: Color = Color(0.2, 1.0, 0.5, 0.4)

func _draw() -> void:
	# Рисуем заполненный круг
	draw_circle(Vector2.ZERO, radius, color)
	# Рисуем обводку
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, outline_color, 2.0, true)

func set_radius(new_radius: float) -> void:
	radius = new_radius
	queue_redraw()
