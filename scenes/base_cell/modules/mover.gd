extends Node
class_name MoverModule

var target_position: Vector2 = Vector2.ZERO
var is_active: bool = false
var stop_distance: float = 120.0
var acceleration: float = 5.0
var friction: float = 2.0
var push_force: float = 120.0 # Сила отталкивания
var _wall_slide_dir: Vector2 = Vector2.ZERO
var _wall_slide_timer: float = 0.0
const WALL_SLIDE_MEMORY: float = 0.35

func _get_wall_aware_direction(parent_cell: BaseCell, desired_dir: Vector2) -> Vector2:
	if desired_dir.length_squared() <= 0.001:
		return desired_dir
	if _wall_slide_timer > 0.0 and _wall_slide_dir.length_squared() > 0.001:
		var memory_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			parent_cell.global_position,
			parent_cell.global_position + desired_dir * maxf(140.0, parent_cell.radius * parent_cell.scale.x + 80.0)
		)
		memory_query.exclude = [parent_cell]
		memory_query.collision_mask = parent_cell.collision_mask
		var memory_hit: Dictionary = parent_cell.get_world_2d().direct_space_state.intersect_ray(memory_query)
		if memory_hit.is_empty():
			_wall_slide_timer = 0.0
			_wall_slide_dir = Vector2.ZERO
		else:
			var remembered_dir: Vector2 = (_wall_slide_dir * 0.75 + desired_dir * 0.25).normalized()
			if remembered_dir.length_squared() > 0.001:
				return remembered_dir
	
	var probe_distance: float = maxf(140.0, parent_cell.radius * parent_cell.scale.x + 80.0)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		parent_cell.global_position,
		parent_cell.global_position + desired_dir * probe_distance
	)
	query.exclude = [parent_cell]
	query.collision_mask = parent_cell.collision_mask
	
	var hit: Dictionary = parent_cell.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired_dir
	
	var collider: Object = hit.get("collider")
	if not (collider is StaticBody2D):
		return desired_dir
	
	var normal: Vector2 = hit.get("normal", Vector2.ZERO)
	if normal.length_squared() <= 0.001:
		return desired_dir
	
	var tangent_a: Vector2 = Vector2(-normal.y, normal.x).normalized()
	var tangent_b: Vector2 = -tangent_a
	var slide_dir: Vector2 = desired_dir.slide(normal).normalized()
	if slide_dir.length_squared() > 0.001:
		if _wall_slide_dir.length_squared() > 0.001:
			if tangent_a.dot(_wall_slide_dir) < tangent_b.dot(_wall_slide_dir):
				tangent_a = -tangent_a
				tangent_b = -tangent_b
			if slide_dir.dot(_wall_slide_dir) < 0.0:
				slide_dir = -slide_dir
		_wall_slide_dir = slide_dir
		_wall_slide_timer = WALL_SLIDE_MEMORY
		return (_wall_slide_dir * 0.8 + desired_dir * 0.2).normalized()
	
	var chosen_tangent: Vector2 = tangent_a
	if _wall_slide_dir.length_squared() > 0.001:
		if tangent_b.dot(_wall_slide_dir) > tangent_a.dot(_wall_slide_dir):
			chosen_tangent = tangent_b
	elif tangent_b.dot(desired_dir) > tangent_a.dot(desired_dir):
		chosen_tangent = tangent_b
	_wall_slide_dir = chosen_tangent
	_wall_slide_timer = WALL_SLIDE_MEMORY
	return (_wall_slide_dir * 0.85 + desired_dir * 0.15).normalized()

func set_target(pos: Vector2) -> void:
	target_position = pos
	is_active = true

func _physics_process(delta: float) -> void:
	var parent_cell = get_parent() as BaseCell
	if not parent_cell: return
	_wall_slide_timer = maxf(0.0, _wall_slide_timer - delta)
	if _wall_slide_timer <= 0.0:
		_wall_slide_dir = Vector2.ZERO
	
	if parent_cell.is_infected:
		# Если заражена — только трение и отталкивание от других, сама не плывет
		parent_cell.velocity = parent_cell.velocity.lerp(Vector2.ZERO, friction * delta)
		# Но отталкивание от соседей оставим ниже (чтобы клетки не слипались в одну точку)
	
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
			var dir: Vector2 = (target_position - current_pos).normalized()
			dir = _get_wall_aware_direction(parent_cell, dir)
			# Рассчитываем скорость с учетом баффа ускорения И меню отладки
			var base_speed = parent_cell.stats.move_speed
			
			var root_main = get_tree().get_first_node_in_group("main")
			if root_main and "cell_speed_mult" in root_main:
				base_speed *= root_main.cell_speed_mult
				
			if parent_cell.speed_boost_timer > 0:
				base_speed *= parent_cell.current_speed_multiplier
				
			var target_vel = dir * base_speed
			parent_cell.velocity = parent_cell.velocity.lerp(target_vel, acceleration * delta)
		else:
			_wall_slide_timer = 0.0
			_wall_slide_dir = Vector2.ZERO
			parent_cell.velocity = parent_cell.velocity.lerp(Vector2.ZERO, friction * delta)
	else:
		# Трение покоя
		_wall_slide_timer = 0.0
		_wall_slide_dir = Vector2.ZERO
		parent_cell.velocity = parent_cell.velocity.lerp(Vector2.ZERO, friction * delta)
