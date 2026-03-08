extends Node2D
## Визуальный эффект выделения цели.

var target_node: Node2D = null
var pulse_speed: float = 4.0
var base_radius: float = 45.0

func _process(delta: float) -> void:
	if is_instance_valid(target_node):
		global_position = target_node.global_position
		# Масштабируем кольцо под размер клетки
		var target_scale = target_node.scale.x
		scale = Vector2(target_scale, target_scale)
		show()
	else:
		hide()
	queue_redraw()

func _draw() -> void:
	# Пульсирующая прозрачность
	var alpha = 0.5 + sin(Time.get_ticks_msec() * 0.005 * pulse_speed) * 0.2
	draw_arc(Vector2.ZERO, base_radius, 0, TAU, 64, Color(1, 1, 1, alpha), 2.0, true)
