extends Node
class_name MoverModule

var target_position: Vector2 = Vector2.ZERO
var is_active: bool = false
var stop_distance: float = 120.0
var acceleration: float = 5.0
var friction: float = 2.0
var push_force: float = 120.0 # Сила отталкивания

func set_target(pos: Vector2) -> void:
	target_position = pos
	is_active = true

func _physics_process(delta: float) -> void:
	var parent_cell = get_parent() as BaseCell
	if not parent_cell: return
	
	# Кешируем позицию и радиус родителя
	var my_pos = parent_cell.global_position
	var my_scaled_radius = parent_cell.radius * parent_cell.scale.x
	
	# 1. Отталкивание от соседей
	var push_vector = Vector2.ZERO
	var all_cells = get_tree().get_nodes_in_group("cells")
	
	for other in all_cells:
		if other == parent_cell: continue
		
		# Оптимизация: сначала проверяем квадрат расстояния (без sqrt)
		var min_dist = my_scaled_radius + (other.radius * other.scale.x) + 5.0
		var min_dist_sq = min_dist * min_dist
		var diff = my_pos - other.global_position
		var dist_sq = diff.length_squared()
		
		if dist_sq < min_dist_sq and dist_sq > 0.01:
			var dist = sqrt(dist_sq)
			var dir = diff / dist  # normalized без повторного sqrt
			var force = (1.0 - (dist / min_dist)) * push_force
			push_vector += dir * force
		
	# Применяем силу отталкивания
	parent_cell.velocity += push_vector * delta * 50.0

	# 2. Движение к цели (если активно)
	if is_active:
		var current_pos = parent_cell.global_position
		var d_to_target = current_pos.distance_to(target_position)
		
		if d_to_target > stop_distance * parent_cell.scale.x:
			var dir = (target_position - current_pos).normalized()
			var target_vel = dir * parent_cell.stats.move_speed
			parent_cell.velocity = parent_cell.velocity.lerp(target_vel, acceleration * delta)
		else:
			parent_cell.velocity = parent_cell.velocity.lerp(Vector2.ZERO, friction * delta)
	else:
		# Трение покоя
		parent_cell.velocity = parent_cell.velocity.lerp(Vector2.ZERO, friction * delta)
