extends Node2D

var _target_node: Node2D = null
var _time_left: float = 3.0
var _color: Color = Color.RED

func setup(target: Node2D, color: Color) -> void:
	_target_node = target
	_color = color
	_time_left = 3.0
	
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
	var alpha_pulse = 0.5 + sin(time * 5.0) * 0.3
	
	if _time_left < 0.5:
		alpha_pulse *= (_time_left / 0.5)
		
	var display_color = _color
	display_color.a = alpha_pulse
	
	var rot_speed = 2.0
	draw_set_transform(Vector2.ZERO, time * rot_speed, Vector2.ONE)
	
	var radius = 42.0 
	
	for i in range(4):
		var start_angle = i * (PI / 2) + 0.2
		var end_angle = start_angle + (PI / 2) - 0.4
		draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 16, display_color, 3.0, true)
		
	for i in range(4):
		var angle = i * (PI / 2)
		var p1 = Vector2(cos(angle), sin(angle)) * (radius - 5)
		var p2 = Vector2(cos(angle - 0.1), sin(angle - 0.1)) * (radius + 5)
		var p3 = Vector2(cos(angle + 0.1), sin(angle + 0.1)) * (radius + 5)
		draw_colored_polygon([p1, p2, p3], display_color)
