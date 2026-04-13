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
var _main_root: Node = null
var _grid_key: Vector2i = Vector2i(2147483647, 2147483647)

# --- Dual Whisker Steering ---
const WHISKER_ANGLE: float = 0.52       # ~30° в радианах
const WALL_SLIDE_MEMORY: float = 0.4    # Время «памяти» направления скольжения
const WALL_STEER_BLEND: float = 0.7     # Вес скольжения vs. направления к цели
const SEPARATION_RANGE_PADDING: float = 24.0
const SPATIAL_GRID_CELL_SIZE: float = 220.0
static var _spatial_grid: Dictionary = {}

func _ready() -> void:
	_main_root = get_tree().get_first_node_in_group("main")
	var parent_cell := get_parent() as BaseCell
	if parent_cell:
		_update_spatial_grid(parent_cell)

func _exit_tree() -> void:
	var parent_cell := get_parent() as BaseCell
	if parent_cell:
		_remove_from_spatial_grid(parent_cell)

static func _get_grid_key(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(pos.x / SPATIAL_GRID_CELL_SIZE)),
		int(floor(pos.y / SPATIAL_GRID_CELL_SIZE))
	)

func _update_spatial_grid(parent_cell: BaseCell) -> void:
	var new_key := _get_grid_key(parent_cell.global_position)
	if new_key == _grid_key:
		return
	_remove_from_spatial_grid(parent_cell)
	var bucket: Array = _spatial_grid.get(new_key, [])
	bucket.append(parent_cell)
	_spatial_grid[new_key] = bucket
	_grid_key = new_key

func _remove_from_spatial_grid(parent_cell: BaseCell) -> void:
	if _grid_key == Vector2i(2147483647, 2147483647):
		return
	if not _spatial_grid.has(_grid_key):
		_grid_key = Vector2i(2147483647, 2147483647)
		return
	var bucket: Array = _spatial_grid[_grid_key]
	var idx := bucket.find(parent_cell)
	if idx != -1:
		bucket.remove_at(idx)
	if bucket.is_empty():
		_spatial_grid.erase(_grid_key)
	else:
		_spatial_grid[_grid_key] = bucket
	_grid_key = Vector2i(2147483647, 2147483647)

func _is_relevant_separation_target(parent_owner: int, other_owner: int) -> bool:
	if parent_owner == BaseCell.OwnerType.NEUTRAL:
		return true
	return other_owner != BaseCell.OwnerType.NEUTRAL

func _get_nearby_cells(parent_cell: BaseCell) -> Array:
	var result: Array = []
	var center_key := _get_grid_key(parent_cell.global_position)
	for y in range(center_key.y - 1, center_key.y + 2):
		for x in range(center_key.x - 1, center_key.x + 2):
			var key := Vector2i(x, y)
			if not _spatial_grid.has(key):
				continue
			var bucket: Array = _spatial_grid[key]
			for other in bucket:
				result.append(other)
	return result

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
	_update_spatial_grid(parent_cell)
	_wall_slide_timer = maxf(0.0, _wall_slide_timer - delta)
	if _wall_slide_timer <= 0.0:
		_wall_slide_dir = Vector2.ZERO
	
	if parent_cell.is_infected:
		# Если заражена — только трение и отталкивание от других, сама не плывет
		parent_cell.velocity = parent_cell.velocity.lerp(Vector2.ZERO, friction * delta)
		# Но отталкивание от соседей оставим ниже (чтобы клетки не слипались в одну точку)
	
	# Кешируем позицию и радиус родителя
	var my_pos: Vector2 = parent_cell.global_position
	var my_scaled_radius: float = parent_cell.radius * parent_cell.scale.x
	var separation_range: float = my_scaled_radius * 2.5 + SEPARATION_RANGE_PADDING
	var separation_range_sq: float = separation_range * separation_range
	
	# 1. Отталкивание от соседей
	var push_vector: Vector2 = Vector2.ZERO
	var nearby_cells := _get_nearby_cells(parent_cell)
	for other in nearby_cells:
		if other == parent_cell or not (other is BaseCell):
			continue
		if not _is_relevant_separation_target(parent_cell.owner_type, other.owner_type):
			continue
		var diff: Vector2 = my_pos - other.global_position
		var dist_sq: float = diff.length_squared()
		if dist_sq > separation_range_sq or dist_sq <= 0.01:
			continue
		var min_dist: float = my_scaled_radius + (other.radius * other.scale.x) + 5.0
		var min_dist_sq: float = min_dist * min_dist
		if dist_sq >= min_dist_sq:
			continue
		var dist: float = sqrt(dist_sq)
		var dir: Vector2 = diff / dist
		var force: float = (1.0 - (dist / min_dist)) * push_force
		push_vector += dir * force
		
	# Применяем силу отталкивания
	parent_cell.velocity += push_vector * delta * 50.0

	# 2. Движение к цели (если активно)
	var move_target: Vector2 = target_position
	var should_move: bool = is_active
	var move_speed_multiplier: float = 1.0

	if parent_cell.is_stranded and parent_cell.has_stranded_return_target:
		move_target = parent_cell.stranded_return_target
		should_move = true
		move_speed_multiplier = 2.0

	if should_move:
		var current_pos = parent_cell.global_position
		var d_to_target_sq: float = current_pos.distance_squared_to(move_target)
		var stop_distance_scaled: float = stop_distance * parent_cell.scale.x
		
		if d_to_target_sq > stop_distance_scaled * stop_distance_scaled:
			var dir: Vector2 = (move_target - current_pos).normalized()
			dir = _get_wall_aware_direction(parent_cell, dir)
			# Рассчитываем скорость с учетом баффа ускорения И меню отладки
			var base_speed: float = parent_cell.stats.move_speed
			
			var root_main = _main_root
			if root_main == null:
				root_main = get_tree().get_first_node_in_group("main")
				_main_root = root_main
			if root_main and "cell_speed_mult" in root_main:
				base_speed *= root_main.cell_speed_mult
				
			if parent_cell.speed_boost_timer > 0:
				base_speed *= parent_cell.current_speed_multiplier

			base_speed *= move_speed_multiplier
				
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
