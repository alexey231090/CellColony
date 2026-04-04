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

# --- Dual Whisker Steering ---
const WHISKER_ANGLE: float = 0.52       # ~30° в радианах
const WALL_SLIDE_MEMORY: float = 0.4    # Время «памяти» направления скольжения
const WALL_STEER_BLEND: float = 0.7     # Вес скольжения vs. направления к цели

func _cast_ray(space: PhysicsDirectSpaceState2D, origin: Vector2, dir: Vector2, dist: float, parent: BaseCell) -> Dictionary:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		origin, origin + dir * dist
	)
	query.exclude = [parent]
	query.collision_mask = parent.collision_mask
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if not (collider is StaticBody2D):
			return {}
	return hit

func _get_wall_aware_direction(parent_cell: BaseCell, desired_dir: Vector2) -> Vector2:
	if desired_dir.length_squared() < 0.001:
		return desired_dir
	
	var probe_dist: float = maxf(160.0, parent_cell.radius * parent_cell.scale.x + 100.0)
	var space: PhysicsDirectSpaceState2D = parent_cell.get_world_2d().direct_space_state
	var origin: Vector2 = parent_cell.global_position
	
	# 1. Центральный луч (прямо к цели)
	var center_hit: Dictionary = _cast_ray(space, origin, desired_dir, probe_dist, parent_cell)
	
	# Если центральный луч чист И память скольжения истекла — идём прямо
	if center_hit.is_empty() and _wall_slide_timer <= 0.0:
		return desired_dir
	
	# Если центр чист, но ещё есть память — проверяем, правда ли путь свободен
	if center_hit.is_empty() and _wall_slide_timer > 0.0:
		_wall_slide_timer = 0.0
		_wall_slide_dir = Vector2.ZERO
		return desired_dir
	
	# 2. Два «уса» под углами ±30°
	var left_dir: Vector2 = desired_dir.rotated(WHISKER_ANGLE)
	var right_dir: Vector2 = desired_dir.rotated(-WHISKER_ANGLE)
	var left_hit: Dictionary = _cast_ray(space, origin, left_dir, probe_dist * 0.8, parent_cell)
	var right_hit: Dictionary = _cast_ray(space, origin, right_dir, probe_dist * 0.8, parent_cell)
	
	var steer_dir: Vector2 = Vector2.ZERO
	
	if left_hit.is_empty() and right_hit.is_empty():
		# Оба уса свободны, центр заблокирован — выбираем сторону
		if _wall_slide_timer > 0.0 and _wall_slide_dir.length_squared() > 0.001:
			# Берём ус, ближайший к запомненному направлению
			if left_dir.dot(_wall_slide_dir) >= right_dir.dot(_wall_slide_dir):
				steer_dir = left_dir
			else:
				steer_dir = right_dir
		else:
			# Первое касание — скользим по нормали
			var normal: Vector2 = center_hit.get("normal", Vector2.ZERO)
			steer_dir = desired_dir.slide(normal).normalized()
			if steer_dir.length_squared() < 0.001:
				steer_dir = Vector2(-normal.y, normal.x) # тангент
	elif left_hit.is_empty():
		steer_dir = left_dir    # Правый ус попал → уходим влево
	elif right_hit.is_empty():
		steer_dir = right_dir   # Левый ус попал → уходим вправо
	else:
		# Оба уса заблокированы — скользим вдоль нормали ближайшего
		var normal: Vector2 = center_hit.get("normal", left_hit.get("normal", Vector2.ZERO))
		steer_dir = desired_dir.slide(normal).normalized()
		if steer_dir.length_squared() < 0.001:
			steer_dir = Vector2(-normal.y, normal.x)
		# Сохраняем консистентность с памятью
		if _wall_slide_dir.length_squared() > 0.001 and steer_dir.dot(_wall_slide_dir) < 0.0:
			steer_dir = -steer_dir
	
	# 3. Обновляем память
	if steer_dir.length_squared() > 0.001:
		_wall_slide_dir = steer_dir.normalized()
		_wall_slide_timer = WALL_SLIDE_MEMORY
	
	# 4. Смешиваем: скольжение + тяга к цели
	return (_wall_slide_dir * WALL_STEER_BLEND + desired_dir * (1.0 - WALL_STEER_BLEND)).normalized()

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
