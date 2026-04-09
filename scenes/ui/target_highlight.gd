extends Node2D

var _target_node: Node2D = null
var _time_left: float = 3.0
var _color: Color = Color.RED
var _life_phase: float = 0.0

func setup(target: Node2D, color: Color) -> void:
	_target_node = target
	_color = color
	_time_left = 3.0
	_life_phase = randf_range(0.0, TAU)
	
	if is_instance_valid(_target_node):
		global_position = _target_node.global_position
		z_index = 10 # Поверх клеток!
		
func _process(delta: float) -> void:
	_time_left -= delta
	
	if _time_left <= 0.0 or not is_instance_valid(_target_node) or not _target_node.is_inside_tree():
		queue_free()
		return
		
	global_position = _target_node.global_position
	scale = Vector2(_target_node.scale.x, _target_node.scale.y)
	
	queue_redraw()

func _draw() -> void:
	var time = Time.get_ticks_msec() / 1000.0
	var alpha_pulse = 0.42 + sin(time * 3.4 + _life_phase) * 0.18
	
	if _time_left < 0.5:
		alpha_pulse *= (_time_left / 0.5)
		
	var display_color = _color
	display_color.a = alpha_pulse

	var base_radius: float = 38.0 + sin(time * 2.2 + _life_phase) * 2.0
	var ring_color: Color = display_color
	var soft_ring_color: Color = display_color
	soft_ring_color.a *= 0.45

	# Внешняя мягкая мембрана цели
	draw_arc(Vector2.ZERO, base_radius + 6.0, 0.0, TAU, 48, soft_ring_color, 2.0, true)

	# Три короткие органические дуги вместо агрессивного RTS-крестика
	for i in range(3):
		var arc_center: float = _life_phase * 0.35 + time * 0.7 + i * (TAU / 3.0)
		var arc_len: float = 0.62 + sin(time * 1.8 + i) * 0.08
		draw_arc(Vector2.ZERO, base_radius, arc_center - arc_len * 0.5, arc_center + arc_len * 0.5, 20, ring_color, 3.2, true)

	# Небольшие биометочные капли по касательной, чтобы подсветка ощущалась живой
	for i in range(3):
		var ang: float = _life_phase * 0.2 - time * 0.55 + i * (TAU / 3.0)
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		var droplet_center: Vector2 = dir * (base_radius + 1.5)
		var tangent: Vector2 = Vector2(-dir.y, dir.x)
		var droplet: PackedVector2Array = PackedVector2Array([
			droplet_center + dir * 6.0,
			droplet_center - dir * 2.5 + tangent * 3.5,
			droplet_center - dir * 4.0,
			droplet_center - dir * 2.5 - tangent * 3.5,
		])
		var droplet_color: Color = display_color
		droplet_color.a *= 0.8
		draw_colored_polygon(droplet, droplet_color)

	# Внутренний мягкий отклик по центру цели
	var core_color: Color = display_color
	core_color.a *= 0.18
	draw_circle(Vector2.ZERO, 10.0 + sin(time * 4.0 + _life_phase) * 1.5, core_color)
