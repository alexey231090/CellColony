extends Node
class_name AIFactionManager

## Менеджер целой фракции ИИ. 
## Управляет всеми клетками цвета как единой колонией.

@export var faction: BaseCell.OwnerType = BaseCell.OwnerType.NEUTRAL
@export var decision_interval: float = 2.5
@export var attack_range: float = 2000.0  # Когда ИИ вступает в бой
@export var expand_range: float = 10000.0 # Как далеко ищет нейтралов

var decision_timer: float = 0.0
var base_pos: Vector2 = Vector2.ZERO
var current_target_node: Node2D = null

func _ready() -> void:
	# Небольшой разброс, чтобы фракции не думали одновременно
	decision_timer = randf_range(0.0, decision_interval)
	call_deferred("_init_base")

func _init_base() -> void:
	var my_cells = _get_my_cells()
	if not my_cells.is_empty():
		base_pos = my_cells[0].global_position

func _process(delta: float) -> void:
	if faction == BaseCell.OwnerType.NEUTRAL or faction == BaseCell.OwnerType.PLAYER:
		return
		
	decision_timer -= delta
	if decision_timer <= 0:
		decision_timer = decision_interval
		_tick_ai()

func _tick_ai() -> void:
	var my_cells = _get_my_cells()
	if my_cells.is_empty(): return
	
	# Считаем центр группы
	var center = Vector2.ZERO
	for c in my_cells: center += c.global_position
	center /= my_cells.size()
	
	# ПРИОРИТЕТ 1: Атака врага, если он в тактическом радиусе (attack_range)
	var enemy = _find_nearest(center, attack_range, false)
	if enemy:
		_order_all(my_cells, enemy.global_position, enemy)
		return
		
	# ПРИОРИТЕТ 2: Глобальная экспансия (ближайший нейтрал на всей карте)
	var neutral = _find_nearest(center, expand_range, true)
	if neutral:
		_order_all(my_cells, neutral.global_position, neutral)
		return
		
	# ПРИОРИТЕТ 3: Вернуться к базе, если делать нечего
	if center.distance_to(base_pos) > 500:
		_order_all(my_cells, base_pos, null)

func _order_all(cells: Array, pos: Vector2, target: Node2D) -> void:
	current_target_node = target
	for c in cells:
		if c.has_method("command_attack"):
			c.command_attack(pos, target)

func _find_nearest(from: Vector2, max_dist: float, find_neutral: bool) -> BaseCell:
	var all_cells = get_tree().get_nodes_in_group("cells")
	var best = null
	var min_d = max_dist
	
	for c in all_cells:
		if not is_instance_valid(c): continue
		if c.owner_type == faction: continue # Своих пропускаем
		
		# Если ищем нейтралов - пропускаем врагов, и наоборот
		if find_neutral:
			if c.owner_type != BaseCell.OwnerType.NEUTRAL: continue
		else:
			if c.owner_type == BaseCell.OwnerType.NEUTRAL: continue
			
		var d = from.distance_to(c.global_position)
		if d < min_d:
			min_d = d
			best = c
	return best

func _get_my_cells() -> Array:
	var group = ""
	match faction:
		BaseCell.OwnerType.ENEMY_RED:    group = "enemy_red_cells"
		BaseCell.OwnerType.ENEMY_GREEN:  group = "enemy_green_cells"
		BaseCell.OwnerType.ENEMY_YELLOW: group = "enemy_yellow_cells"
	if group == "": return []
	return get_tree().get_nodes_in_group(group)
