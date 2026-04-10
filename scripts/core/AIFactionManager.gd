extends Node
class_name AIFactionManager

## Менеджер целой фракции ИИ. 
## Управляет всеми клетками цвета как единой колонией.
## Поддерживает профили сложности (easy / medium / hard).

@export var faction: BaseCell.OwnerType = BaseCell.OwnerType.NEUTRAL
@export var decision_interval: float = 2.5
@export var attack_range: float = 2000.0
@export var enemy_notice_range: float = 2000.0
@export var expand_range: float = 10000.0
@export var min_energy_ratio_for_war: float = 0.55
@export var goal_lock_time: float = 4.0
@export var score_distance_scale: float = 2200.0
@export var patrol_min_distance: float = 900.0
@export var patrol_max_distance: float = 2600.0
@export var patrol_reached_distance: float = 350.0

var decision_timer: float = 0.0
var base_pos: Vector2 = Vector2.ZERO
var current_target_node: BaseCell = null
var current_goal_pos: Vector2 = Vector2.ZERO
var goal_lock_timer: float = 0.0

# === ПЕРКИ ИИ ===
@export var ai_perk_energy: float = 0.0

var _ai_shield_cd: float = 0.0
var _ai_speed_cd: float = 0.0
var _ai_rapid_fire_cd: float = 0.0
var _ai_virus_cd: float = 0.0

# === ПАРАМЕТРЫ СЛОЖНОСТИ ===
## Режим скоринга нейтралок: "max_value" (жирные первыми) или "fast_capture" (слабые первыми)
var neutral_score_mode: String = "max_value"
## Порог HP (доля от max_energy) для активации щита
var shield_hp_threshold: float = 0.45
## Минимальный max_energy клетки для активации щита (фильтрует молодые клетки)
var shield_min_max_energy: float = 20.0
## Минимальное количество врагов для активации вируса
var virus_min_enemy_count: int = 3
## Порог HP цели (доля от max_energy) для скорострельности
var rapid_fire_hp_target_threshold: float = 0.4
## Порог дистанции до цели для активации ускорения
var speed_boost_distance_threshold: float = 1200.0

func _ready() -> void:
	add_to_group("ai_faction_managers")
	# Небольшой разброс, чтобы фракции не думали одновременно
	decision_timer = randf_range(0.0, decision_interval)
	call_deferred("_init_base")

func _init_base() -> void:
	var my_cells: Array[BaseCell] = _get_my_cells()
	if not my_cells.is_empty():
		base_pos = _pick_base_pos(my_cells)
		current_goal_pos = base_pos

## Применяет профиль сложности к менеджеру ИИ.
## Вызывается из organic_level.gd при старте уровня.
func apply_difficulty_profile(profile: Dictionary) -> void:
	if profile.has("decision_interval"):
		decision_interval = float(profile.decision_interval)
	if profile.has("enemy_notice_range"):
		enemy_notice_range = float(profile.enemy_notice_range)
	if profile.has("min_energy_ratio_for_war"):
		min_energy_ratio_for_war = float(profile.min_energy_ratio_for_war)
	if profile.has("goal_lock_time"):
		goal_lock_time = float(profile.goal_lock_time)
	if profile.has("score_distance_scale"):
		score_distance_scale = float(profile.score_distance_scale)
	if profile.has("neutral_score_mode"):
		neutral_score_mode = String(profile.neutral_score_mode)
	if profile.has("shield_hp_threshold"):
		shield_hp_threshold = float(profile.shield_hp_threshold)
	if profile.has("shield_min_max_energy"):
		shield_min_max_energy = float(profile.shield_min_max_energy)
	if profile.has("virus_min_enemy_count"):
		virus_min_enemy_count = int(profile.virus_min_enemy_count)
	if profile.has("rapid_fire_hp_target_threshold"):
		rapid_fire_hp_target_threshold = float(profile.rapid_fire_hp_target_threshold)
	if profile.has("speed_boost_distance_threshold"):
		speed_boost_distance_threshold = float(profile.speed_boost_distance_threshold)
	
	# Стартовый кулдаун перков (perk_delay_mult): 
	# На Easy/Medium ИИ начинает с перками на откате, на Hard — сразу готов.
	var perk_delay_mult: float = float(profile.get("perk_delay_mult", 1.0))
	if perk_delay_mult > 1.0:
		var sm = get_tree().get_first_node_in_group("selection_manager")
		if sm:
			_ai_shield_cd = maxf(_ai_shield_cd, sm.SHIELD_COOLDOWN_MAX * perk_delay_mult)
			_ai_speed_cd = maxf(_ai_speed_cd, sm.SPEED_COOLDOWN_MAX * perk_delay_mult)
			_ai_rapid_fire_cd = maxf(_ai_rapid_fire_cd, sm.RAPID_FIRE_COOLDOWN_MAX * perk_delay_mult)
			_ai_virus_cd = maxf(_ai_virus_cd, sm.VIRUS_COOLDOWN_MAX * perk_delay_mult)
	
	print("[AI %s] Профиль сложности применён: interval=%.1f, notice_range=%.0f, war_ratio=%.2f, neutral_mode=%s" % [
		_get_group_for_owner(faction), decision_interval, enemy_notice_range, min_energy_ratio_for_war, neutral_score_mode
	])

func _process(delta: float) -> void:
	if faction == BaseCell.OwnerType.NEUTRAL or faction == BaseCell.OwnerType.PLAYER:
		return
		
	# Охлаждение перков
	if _ai_shield_cd > 0: _ai_shield_cd = max(0.0, _ai_shield_cd - delta)
	if _ai_speed_cd > 0: _ai_speed_cd = max(0.0, _ai_speed_cd - delta)
	if _ai_rapid_fire_cd > 0: _ai_rapid_fire_cd = max(0.0, _ai_rapid_fire_cd - delta)
	if _ai_virus_cd > 0: _ai_virus_cd = max(0.0, _ai_virus_cd - delta)
		
	decision_timer -= delta
	if decision_timer <= 0:
		decision_timer = decision_interval
		_tick_ai()
		_evaluate_and_use_perks(delta)

func add_perk_energy(amount: float) -> void:
	ai_perk_energy += amount
	var sm = get_tree().get_first_node_in_group("selection_manager")
	if sm:
		ai_perk_energy = min(ai_perk_energy, sm.MAX_PERK_ENERGY)

func _tick_ai() -> void:
	var my_cells: Array[BaseCell] = _get_my_cells()
	if my_cells.is_empty(): return
	
	var center := _get_center(my_cells)
	base_pos = _pick_base_pos(my_cells)
	
	goal_lock_timer = maxf(0.0, goal_lock_timer - decision_interval)
	
	if _is_target_still_valid(current_target_node) and goal_lock_timer > 0.0:
		_order_all_attack(my_cells, current_target_node)
		return
	
	var all_cells := _get_all_cells()
	
	var tactical_enemy := _find_best_enemy_in_range(center, attack_range, all_cells)
	if tactical_enemy != null:
		_set_goal_lock()
		_order_all_attack(my_cells, tactical_enemy)
		return
	
	var avg_energy_ratio := _get_avg_energy_ratio(my_cells)
	var best_neutral := _find_best_neutral_global(center, all_cells)
	var noticed_enemy := _find_best_enemy_in_range(center, enemy_notice_range, all_cells)
	var best_enemy: BaseCell = null
	if noticed_enemy != null or best_neutral == null:
		best_enemy = _find_best_enemy_global(center, all_cells)

	if best_enemy != null and avg_energy_ratio >= min_energy_ratio_for_war:
		_set_goal_lock()
		_order_all_attack(my_cells, best_enemy)
		return
	
	if best_neutral != null:
		_set_goal_lock()
		_order_all_attack(my_cells, best_neutral)
		return
	
	if center.distance_to(current_goal_pos) <= patrol_reached_distance:
		current_goal_pos = _pick_patrol_point(center)
	_order_all_move(my_cells, current_goal_pos)

func _set_goal_lock() -> void:
	goal_lock_timer = goal_lock_time

func _order_all_attack(cells: Array[BaseCell], target: BaseCell) -> void:
	current_target_node = target
	if is_instance_valid(target):
		current_goal_pos = target.global_position
	for c in cells:
		if c.has_method("command_attack"):
			c.command_attack(current_goal_pos, target)

func _order_all_move(cells: Array[BaseCell], pos: Vector2) -> void:
	current_target_node = null
	current_goal_pos = pos
	for c in cells:
		if c.has_method("command_move"):
			c.command_move(pos)

func _get_center(cells: Array[BaseCell]) -> Vector2:
	var center := Vector2.ZERO
	for c in cells:
		center += c.global_position
	return center / float(cells.size())

func _pick_base_pos(cells: Array[BaseCell]) -> Vector2:
	var best: BaseCell = cells[0]
	var best_energy := best.stats.current_energy
	for c in cells:
		if c.stats.current_energy > best_energy:
			best = c
			best_energy = c.stats.current_energy
	return best.global_position

func _is_target_still_valid(target: BaseCell) -> bool:
	if not is_instance_valid(target): return false
	if not target.is_inside_tree(): return false
	if target.owner_type == faction: return false
	return true

func _get_all_cells() -> Array[BaseCell]:
	var raw := get_tree().get_nodes_in_group("cells")
	var result: Array[BaseCell] = []
	for n in raw:
		if n is BaseCell:
			result.append(n)
	return result

func _get_avg_energy_ratio(cells: Array[BaseCell]) -> float:
	if cells.is_empty(): return 0.0
	var sum := 0.0
	for c in cells:
		if c.stats.max_energy > 0.0:
			sum += c.stats.current_energy / c.stats.max_energy
	return sum / float(cells.size())

func _find_best_enemy_in_range(from: Vector2, max_dist: float, all_cells: Array[BaseCell]) -> BaseCell:
	var max_dist_sq := max_dist * max_dist
	var best: BaseCell = null
	var best_score := -INF
	for c in all_cells:
		if c.owner_type == faction or c.owner_type == BaseCell.OwnerType.NEUTRAL: continue
		var dist_sq := from.distance_squared_to(c.global_position)
		if dist_sq > max_dist_sq: continue
		var score := _score_enemy(from, c, dist_sq)
		if score > best_score:
			best_score = score
			best = c
	return best

func _find_best_enemy_global(from: Vector2, all_cells: Array[BaseCell]) -> BaseCell:
	var best: BaseCell = null
	var best_score := -INF
	for c in all_cells:
		if c.owner_type == faction or c.owner_type == BaseCell.OwnerType.NEUTRAL: continue
		var dist_sq := from.distance_squared_to(c.global_position)
		if dist_sq > expand_range * expand_range: continue
		var score := _score_enemy(from, c, dist_sq)
		if score > best_score:
			best_score = score
			best = c
	return best

func _find_best_neutral_global(from: Vector2, all_cells: Array[BaseCell]) -> BaseCell:
	var best: BaseCell = null
	var min_dist_sq := INF
	for c in all_cells:
		if c.owner_type != BaseCell.OwnerType.NEUTRAL: continue
		var dist_sq := from.distance_squared_to(c.global_position)
		if dist_sq > expand_range * expand_range: continue
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			best = c
	return best

func _score_enemy(_from: Vector2, enemy: BaseCell, dist_sq: float) -> float:
	var weakness := 0.0
	if enemy.stats.max_energy > 0.0:
		weakness = 1.0 - (enemy.stats.current_energy / enemy.stats.max_energy)
	var denom := 1.0 + (dist_sq / (score_distance_scale * score_distance_scale))
	return (1.0 + weakness * 1.6) / denom

func _pick_patrol_point(from: Vector2) -> Vector2:
	var map_rect := _get_map_rect()
	var dir := Vector2.RIGHT.rotated(randf_range(-PI, PI))
	var dist := randf_range(patrol_min_distance, patrol_max_distance)
	var p := from + dir * dist
	p.x = clampf(p.x, map_rect.position.x, map_rect.position.x + map_rect.size.x)
	p.y = clampf(p.y, map_rect.position.y, map_rect.position.y + map_rect.size.y)
	return p

func _get_map_rect() -> Rect2:
	var scene := get_tree().current_scene
	if scene != null and ("map_size" in scene):
		var ms = scene.map_size
		if ms is Vector2:
			return Rect2(-ms / 2.0, ms)
	var fallback_half := Vector2.ONE * expand_range
	return Rect2(base_pos - fallback_half, fallback_half * 2.0)

func _get_my_cells() -> Array[BaseCell]:
	var group = _get_group_for_owner(faction)
	var nodes = get_tree().get_nodes_in_group(group)
	var cells: Array[BaseCell] = []
	for n in nodes:
		if n is BaseCell:
			cells.append(n)
	return cells

func _get_nearest_cell(cells: Array[BaseCell], pos: Vector2) -> BaseCell:
	var nearest: BaseCell = null
	var min_dist_sq = INF
	for c in cells:
		var d_sq = c.global_position.distance_squared_to(pos)
		if d_sq < min_dist_sq:
			min_dist_sq = d_sq
			nearest = c
	return nearest

func _get_group_for_owner(owner_t: BaseCell.OwnerType) -> String:
	match owner_t:
		BaseCell.OwnerType.PLAYER:       return "player_cells"
		BaseCell.OwnerType.ENEMY_RED:    return "enemy_red_cells"
		BaseCell.OwnerType.ENEMY_GREEN:  return "enemy_green_cells"
		BaseCell.OwnerType.ENEMY_YELLOW: return "enemy_yellow_cells"
	return "cells"

func _evaluate_and_use_perks(_delta: float) -> void:
	var sm = get_tree().get_first_node_in_group("selection_manager")
	if not sm: return
	
	var my_cells = _get_my_cells()
	if my_cells.is_empty(): return
	
	# 1. ЩИТ (Приоритет: спасение)
	# Исправление бага: фильтруем молодые клетки (max_energy < shield_min_max_energy),
	# чтобы ИИ не тратил щит на свеже-захваченные нейтралки с малым HP.
	if _ai_shield_cd <= 0 and ai_perk_energy >= sm.SHIELD_ENERGY_COST:
		var target_shieldee: BaseCell = null
		var current_time: float = Time.get_ticks_msec() / 1000.0
		for cell in my_cells:
			# Пропускаем молодые клетки — у них мало max_energy, это нормально
			if cell.stats.max_energy < shield_min_max_energy:
				continue

			var damaged_by_enemy: bool = false
			for attacker_owner in cell.contributions.keys():
				var attacker_owner_int: int = int(attacker_owner)
				if attacker_owner_int != int(faction) and attacker_owner_int != int(BaseCell.OwnerType.NEUTRAL) and cell.contributions[attacker_owner] > 0.0:
					damaged_by_enemy = true
					break

			# Щит только при реальном бою с другой фракцией, а не при фарме нейтралок.
			if not cell.is_infected and damaged_by_enemy and cell.stats.current_energy < cell.stats.max_energy * shield_hp_threshold and (current_time - cell.last_damage_time) < 1.5:
				if cell.reflect_chance < 0.1: # Еще нет щита
					target_shieldee = cell
					break
				
		if target_shieldee:
			ai_perk_energy -= sm.SHIELD_ENERGY_COST
			_ai_shield_cd = max(5.0, sm.SHIELD_COOLDOWN_MAX)
			
			# Применяем щит по области (чуть больше радиус для ИИ, чтобы это было заметно)
			var a_radius = sm.SHIELD_SELECT_RADIUS * 1.5
			for cell in my_cells:
				if cell.is_infected: continue
				if cell.global_position.distance_to(target_shieldee.global_position) <= a_radius + (cell.radius * cell.scale.x):
					cell.reflect_chance = 0.5
					cell.reflect_timer = 10.0
					cell.queue_redraw()

	# 2. ВИРУС (Приоритет: текущая цель и её соседи)
	if _ai_virus_cd <= 0 and ai_perk_energy >= sm.VIRUS_ENERGY_COST:
		# Оптимизация: не ищем по всей карте, а бьем в текущую цель если там есть толпа
		if current_target_node and is_instance_valid(current_target_node) and current_target_node.owner_type != BaseCell.OwnerType.NEUTRAL:
			var target_faction_group = _get_group_for_owner(current_target_node.owner_type)
			var enemies = get_tree().get_nodes_in_group(target_faction_group)
			
			if enemies.size() >= virus_min_enemy_count: # Бьем если у врага достаточная кучка
				# Ищем нашу ближайшую клетку к цели
				var nearest = _get_nearest_cell(my_cells, current_target_node.global_position)
				if nearest:
					var shooter = nearest.get_node_or_null("ShooterModule")
					if shooter:
						sm.virus_outbreak_counter += 1
						shooter.shoot_virus(current_target_node, sm.VIRUS_DURATION, sm.virus_outbreak_counter)
						ai_perk_energy -= sm.VIRUS_ENERGY_COST
						_ai_virus_cd = max(5.0, sm.VIRUS_COOLDOWN_MAX)

	# 3. СКОРОСТРЕЛЬНОСТЬ (Приоритет: добивание/атака)
	if _ai_rapid_fire_cd <= 0 and ai_perk_energy >= sm.RAPID_FIRE_ENERGY_COST:
		if current_target_node and is_instance_valid(current_target_node) and current_target_node.owner_type != BaseCell.OwnerType.NEUTRAL:
			if current_target_node.stats.current_energy < current_target_node.stats.max_energy * rapid_fire_hp_target_threshold:
				# Проверяем, не включен ли уже перк (чтобы не спамить)
				var already_raging = false
				for c in my_cells:
					if c.rapid_fire_timer > 1.0:
						already_raging = true
						break
				
				if not already_raging:
					ai_perk_energy -= sm.RAPID_FIRE_ENERGY_COST
					_ai_rapid_fire_cd = max(5.0, sm.RAPID_FIRE_COOLDOWN_MAX)
					for c in my_cells:
						if c is BaseCell and not c.is_infected:
							c.apply_rapid_fire(sm.RAPID_FIRE_DURATION, sm.RAPID_FIRE_MULTIPLIER)

	# 4. УСКОРЕНИЕ (Приоритет: догнать цель)
	if _ai_speed_cd <= 0 and ai_perk_energy >= sm.SPEED_ENERGY_COST:
		var center = _get_center(my_cells)
		if current_goal_pos != Vector2.ZERO and center.distance_to(current_goal_pos) > speed_boost_distance_threshold:
			# Не ускоряемся, если уже летим на спринте
			var already_sprinting = false
			for c in my_cells:
				if c.speed_boost_timer > 1.0:
					already_sprinting = true
					break
			
			if not already_sprinting:
				ai_perk_energy -= sm.SPEED_ENERGY_COST
				_ai_speed_cd = max(5.0, sm.SPEED_COOLDOWN_MAX)
				for c in my_cells:
					if c is BaseCell and not c.is_infected:
						c.apply_speed_boost(sm.SPEED_BOOST_DURATION, sm.SPEED_BOOST_MULTIPLIER)
