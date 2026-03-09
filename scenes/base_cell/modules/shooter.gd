extends Node2D
class_name ShooterModule

@export var projectile_scene: PackedScene = preload("res://scenes/projectile/projectile.tscn")

var target_position: Vector2 = Vector2.ZERO
var target_node: Node2D = null
var is_active: bool = false
var fire_timer: float = 0.0

# Параметры автоатаки
var auto_target: Node2D = null
var scan_timer: float = 0.0
const SCAN_INTERVAL: float = 0.4 # Сканируем 2.5 раза в секунду
const AUTO_SCAN_RANGE: float = 600.0

func set_target(pos: Vector2, node: Node2D = null) -> void:
	target_position = pos
	target_node = node
	is_active = (target_node != null)
	if is_active:
		auto_target = null # Сбрасываем авто-цель при получении приказа

func _process(delta: float) -> void:
	var parent_cell = get_parent() as BaseCell
	if not parent_cell or parent_cell.owner_type == BaseCell.OwnerType.NEUTRAL: 
		return
	
	var final_target = null
	
	# 1. Приоритет: Цель, заданная игроком/командой
	if is_instance_valid(target_node):
		if _is_target_valid_for_fire(target_node, parent_cell):
			final_target = target_node
		else:
			target_node = null
			is_active = false
	
	# 2. Если ручной цели нет — ищем авто-цель рядом
	if final_target == null:
		# Сначала проверяем старую авто-цель (чтобы не скакать между целями)
		if is_instance_valid(auto_target):
			if _is_target_valid_for_fire(auto_target, parent_cell) and \
			   global_position.distance_to(auto_target.global_position) <= AUTO_SCAN_RANGE:
				final_target = auto_target
			else:
				auto_target = null
		
		# Периодический поиск новой цели
		scan_timer -= delta
		if scan_timer <= 0:
			scan_timer = SCAN_INTERVAL
			if final_target == null:
				auto_target = _find_closest_target(parent_cell)
				final_target = auto_target

	# 3. Логика стрельбы
	if final_target != null:
		target_position = final_target.global_position
		
		fire_timer -= delta
		if fire_timer <= 0:
			if parent_cell.stats.current_energy > parent_cell.stats.attack_cost:
				shoot(final_target)
				fire_timer = 1.0 / parent_cell.stats.fire_rate

func _is_target_valid_for_fire(node: Node2D, parent: BaseCell) -> bool:
	if not is_instance_valid(node) or node == parent: return false
	
	# Проверяем наличие необходимых полей (для всех типов клеток)
	if "owner_type" in node and "stats" in node:
		if node.owner_type == parent.owner_type:
			# Союзник: лечим только если не фулл HP
			return node.stats.current_energy < node.stats.max_energy
		return true # Враг/Нейтрал — всегда цель
	return false

func _find_closest_target(parent: BaseCell) -> Node2D:
	var cells = get_tree().get_nodes_in_group("cells")
	var closest = null
	var min_dist = AUTO_SCAN_RANGE
	
	for cell in cells:
		if cell == parent: continue
		if "owner_type" in cell and cell.owner_type != parent.owner_type:
			var dist = global_position.distance_to(cell.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = cell
	return closest

func shoot(current_target: Node2D) -> void:
	var parent_cell = get_parent() as BaseCell
	if not parent_cell: return
	
	parent_cell.stats.current_energy -= parent_cell.stats.attack_cost
	
	var proj = projectile_scene.instantiate() as Projectile
	get_tree().root.add_child(proj)
	
	var shoot_dir = (current_target.global_position - global_position).normalized()
	var spread = deg_to_rad(randf_range(-5, 5))
	shoot_dir = shoot_dir.rotated(spread)
	
	var spawn_dist = parent_cell.radius * parent_cell.scale.x + 10.0
	
	proj.global_position = global_position + shoot_dir * spawn_dist
	proj.direction = shoot_dir
	proj.speed = parent_cell.stats.projectile_speed
	proj.damage = parent_cell.stats.attack_cost
	proj.owner_type = parent_cell.owner_type
	proj.target_node = current_target
	
	var p_color = parent_cell._get_cell_color()
	proj.projectile_color = p_color
