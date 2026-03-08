extends Node
class_name AIModule

## Универсальный ИИ для любой AI-фракции.
## Работает для ENEMY_RED, ENEMY_GREEN, ENEMY_YELLOW.
## Атакует врагов всех других фракций, захватывает нейтралов,
## стремится накопить энергию перед атакой.

@export var scan_interval: float = 1.8
@export var capture_priority: float = 0.4 # 0..1 — склонность захватывать нейтралов вместо атаки

var scan_timer: float = 0.0

func _ready() -> void:
	# Случайный разброс таймеров, чтобы не все AI думали одновременно
	scan_timer = randf_range(0.0, scan_interval)

func _process(delta: float) -> void:
	var parent_cell = get_parent() as BaseCell
	if not parent_cell: return
	
	# AI работает только для AI-фракций
	if parent_cell.owner_type == BaseCell.OwnerType.NEUTRAL or \
	   parent_cell.owner_type == BaseCell.OwnerType.PLAYER:
		return
	
	scan_timer -= delta
	if scan_timer <= 0.0:
		_perform_ai_action(parent_cell)
		scan_timer = scan_interval

func _perform_ai_action(cell: BaseCell) -> void:
	# Если энергии мало — ждём
	if cell.stats.current_energy < cell.stats.max_energy * 0.35:
		return
	
	# Выбираем стратегию: захватить нейтрала или атаковать врага
	var should_capture = randf() < capture_priority
	
	if should_capture:
		var neutral = _find_nearest_neutral(cell)
		if neutral:
			cell.command_attack(neutral.global_position, neutral)
			return
	
	# Ищем ближайшего врага (любой чужой фракции)
	var enemy_target = _find_best_enemy(cell)
	if enemy_target:
		cell.command_attack(enemy_target.global_position, enemy_target)
		return
	
	# Нет врагов — захватываем нейтрала
	var neutral_fallback = _find_nearest_neutral(cell)
	if neutral_fallback:
		cell.command_attack(neutral_fallback.global_position, neutral_fallback)

## Находит ближайшую нейтральную клетку
func _find_nearest_neutral(cell: BaseCell) -> BaseCell:
	var all_cells = get_tree().get_nodes_in_group("cells")
	var best: BaseCell = null
	var min_dist: float = INF
	
	for other in all_cells:
		if other is BaseCell and other.owner_type == BaseCell.OwnerType.NEUTRAL:
			var dist = cell.global_position.distance_squared_to(other.global_position)
			if dist < min_dist:
				min_dist = dist
				best = other
	return best

## Находит лучшую цель среди врагов (другие AI-фракции, игрок)
## Приоритизирует слабых и близких
func _find_best_enemy(cell: BaseCell) -> BaseCell:
	var all_cells = get_tree().get_nodes_in_group("cells")
	var best: BaseCell = null
	var best_score: float = -INF
	
	for other in all_cells:
		if not (other is BaseCell): continue
		if other.owner_type == BaseCell.OwnerType.NEUTRAL: continue
		if other.owner_type == cell.owner_type: continue # Свои
		
		var dist = cell.global_position.distance_to(other.global_position)
		if dist > 1800.0: continue # Не видим слишком далёких
		
		# Очки = слабость цели / расстояние
		# Предпочитаем бить слабых и близких
		var weakness = 1.0 - (other.stats.current_energy / other.stats.max_energy)
		var score = weakness * 2.0 - (dist / 1000.0)
		
		if score > best_score:
			best_score = score
			best = other
	
	return best
