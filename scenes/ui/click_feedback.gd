extends Node2D

var _cells: Array[Node] = []
var _target: Vector2
var _alpha_mult: float = 1.0
var _particles: Array = []
var _is_attack: bool = false

func setup(cells: Array, target_pos: Vector2, is_attack: bool = false) -> void:
	_cells = cells.duplicate()
	_target = target_pos
	_is_attack = is_attack
	
	global_position = target_pos
	z_index = 10 # Поверх клеток!
	
	for i in range(12):
		var angle = randf() * TAU
		var speed = randf_range(60.0, 180.0)
		_particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"radius": randf_range(3.0, 7.0)
		})
	
	var tween = create_tween()
	tween.tween_property(self, "_alpha_mult", 0.0, 0.5)
	
	tween.tween_callback(queue_free)

func _process(delta: float) -> void:
	for p in _particles:
		p.pos += p.vel * delta
		p.vel *= 0.9 # Трение (замедление частиц)
	queue_redraw()

func _draw() -> void:
	var base_color = Color(0.9, 0.3, 0.3, 0.7 * _alpha_mult) if _is_attack else Color(0.3, 0.9, 0.5, 0.7 * _alpha_mult)
	var inv_transform = get_global_transform().affine_inverse()
	
	for cell in _cells:
		if is_instance_valid(cell) and cell.is_inside_tree():
			var local_cell_pos = inv_transform * cell.global_position
			draw_line(local_cell_pos, Vector2.ZERO, base_color, 2.0, true)
			draw_circle(local_cell_pos, 3.0, base_color)
			
	# Рисуем брызги (партиклы)
	for p in _particles:
		var p_color = base_color
		# Партиклы становятся прозрачнее и меньше вместе со всем эффектом
		draw_circle(p.pos, p.radius * _alpha_mult, p_color)
