extends CharacterBody2D
class_name BaseCell

# 4 фракции: Нейтрал, Игрок (синий), Враг-красный, Враг-зелёный, Враг-жёлтый
enum OwnerType { NEUTRAL, PLAYER, ENEMY_RED, ENEMY_GREEN, ENEMY_YELLOW }

@export var owner_type: OwnerType = OwnerType.NEUTRAL
@export var stats: CellStats = CellStats.new()
@export var radius: float = 32.0

@onready var energy_label: Label = $EnergyLabel
@onready var contr_label: Label = $ContrLabel
@onready var shield_overlay: ColorRect = $ShieldOverlay

# Визуальные эффекты при попадании
var hit_flash_timer: float = 0.0
var hit_impact_wobble: float = 0.0

# Баффы
var reflect_chance: float = 0.0
var reflect_timer: float = 0.0

# Ускорение (новый перк)
var speed_boost_timer: float = 0.0
var current_speed_multiplier: float = 1.0

# Скорострельность (новый перк)
var rapid_fire_timer: float = 0.0
var current_fire_rate_multiplier: float = 1.0

# Вирус (новый перк)
var is_infected: bool = false
var infection_timer: float = 0.0
var _spread_timer: float = 0.0
var _visual_infection_factor: float = 0.0 # Для плавного потемнения
var last_outbreak_id: int = -1 # ID последней волны вируса, которой болела клетка

# Сглаживание желейной физики
var visual_stretch: float = 0.0
var visual_angle: float = 0.0

# Новая механика перков (Щит, Спринт и т.д.)
var assigned_perk: String = ""

# Система вклада (для перков)
var contributions: Dictionary = {} # OwnerType -> float
var last_damage_time: float = 0.0
var decay_accum: float = 0.0

# Оптимизация: троттлинг перерисовки
var _redraw_timer: float = 0.0
var _ui_timer: float = 0.0
const REDRAW_INTERVAL: float = 0.033 # ~30 FPS для отрисовки (физика остаётся 60)
const UI_UPDATE_INTERVAL: float = 0.12

# Кеш RNG для отрисовки вен вируса (избегаем аллокации каждый кадр)
var _vein_rng: RandomNumberGenerator = null
var _vein_rng_seed: int = 0

# Механика "отставшей" клетки
var is_stranded: bool = false
var _stranded_check_timer: float = 0.0
var _stranded_damage_timer: float = 0.0
var stranded_return_target: Vector2 = Vector2.ZERO
var has_stranded_return_target: bool = false
const STRANDED_CHECK_INTERVAL: float = 2.0
const STRANDED_DISTANCE_THRESHOLD: float = 2000.0
const STRANDED_DAMAGE_INTERVAL: float = 1.0
const STRANDED_DAMAGE_AMOUNT: float = 1.0

static func get_group_for_owner(owner: OwnerType) -> String:
	match owner:
		OwnerType.PLAYER:
			return "player_cells"
		OwnerType.ENEMY_RED:
			return "enemy_red_cells"
		OwnerType.ENEMY_GREEN:
			return "enemy_green_cells"
		OwnerType.ENEMY_YELLOW:
			return "enemy_yellow_cells"
	return ""

static func get_colony_center(tree: SceneTree, owner: OwnerType) -> Vector2:
	var group_name := get_group_for_owner(owner)
	if group_name == "":
		return Vector2.ZERO

	var colony_center := Vector2.ZERO
	var count := 0
	for node in tree.get_nodes_in_group(group_name):
		var cell := node as BaseCell
		if cell:
			colony_center += cell.global_position
			count += 1

	if count <= 0:
		return Vector2.ZERO
	return colony_center / float(count)

func _ready() -> void:
	add_to_group("cells")
	_update_groups()
	_update_visuals()
	_set_energy_ui_visible(false)
	_set_contribution_ui_visible(false)
	
	if shield_overlay and shield_overlay.material:
		shield_overlay.material = shield_overlay.material.duplicate()
	
	if energy_label:
		# Оформляем цифры красиво прямо из кода, чтобы они хорошо читались
		var settings = LabelSettings.new()
		settings.font_size = 22
		settings.font_color = Color(1.0, 1.0, 1.0, 0.9) # Слегка прозрачный белый
		settings.outline_size = 6
		settings.outline_color = Color(0.1, 0.1, 0.1, 0.7) # Мягкая темная обводка
		settings.shadow_size = 4
		settings.shadow_color = Color(0, 0, 0, 0.5)
		settings.shadow_offset = Vector2(1, 2)
		energy_label.label_settings = settings

	if contr_label:
		var c_settings = LabelSettings.new()
		c_settings.font_size = 18
		c_settings.font_color = Color(0.2, 0.6, 1.0, 0.9) # Синий
		c_settings.outline_size = 4
		c_settings.outline_color = Color(0, 0, 0, 0.8)
		contr_label.label_settings = c_settings

func _update_groups() -> void:
	# Убираем из всех фракционных групп
	for g in ["neutral_cells", "player_cells", "enemy_red_cells", "enemy_green_cells", "enemy_yellow_cells"]:
		if is_in_group(g): remove_from_group(g)
	match owner_type:
		OwnerType.NEUTRAL:      add_to_group("neutral_cells")
		OwnerType.PLAYER:       add_to_group("player_cells")
		OwnerType.ENEMY_RED:    add_to_group("enemy_red_cells")
		OwnerType.ENEMY_GREEN:  add_to_group("enemy_green_cells")
		OwnerType.ENEMY_YELLOW: add_to_group("enemy_yellow_cells")

func take_damage(amount: float, attacker_owner: OwnerType) -> void:
	if owner_type == attacker_owner:
		# Запрещено лечить зараженную клетку
		if is_infected: return
		stats.current_energy = min(stats.max_energy, stats.current_energy + amount)
	else:
		stats.current_energy -= amount
		# Отслеживаем вклад атакующего
		contributions[attacker_owner] = contributions.get(attacker_owner, 0.0) + amount
		last_damage_time = Time.get_ticks_msec() / 1000.0
		
		# Визуальный отклик на урон
		hit_flash_timer = 0.2
		hit_impact_wobble = 15.0
		queue_redraw() # Мгновенный редро, не ждём таймер
		
		if stats.current_energy < 0:
			stats.current_energy = abs(stats.current_energy)
			_capture(attacker_owner)

func _capture(new_owner: OwnerType) -> void:
	# Награда за захват: точное количество ХП (вклад), которое игрок отнял у клетки
	var reward = contributions.get(new_owner, 0.0)
	
	if new_owner == OwnerType.PLAYER:
		if reward > 0:
			var sm = get_tree().get_first_node_in_group("selection_manager")
			if sm and sm.has_method("add_perk_energy"):
				sm.add_perk_energy(reward)
	elif new_owner != OwnerType.NEUTRAL:
		# Начисляем энергию ИИ фракции
		if reward > 0:
			var ai_managers = get_tree().get_nodes_in_group("ai_faction_managers")
			for ai in ai_managers:
				if ai.faction == new_owner and ai.has_method("add_perk_energy"):
					ai.add_perk_energy(reward)
					break
	
	# Сбрасываем вклады и баффы (щит, ускорение) после смены владельца
	contributions.clear()
	reflect_chance = 0.0
	reflect_timer = 0.0
	speed_boost_timer = 0.0
	current_speed_multiplier = 1.0
	rapid_fire_timer = 0.0
	current_fire_rate_multiplier = 1.0
	is_infected = false
	infection_timer = 0.0
	_visual_infection_factor = 0.0
	last_outbreak_id = -1
	_vein_rng = null # Сброс кешированного RNG вен
	is_stranded = false
	_stranded_check_timer = 0.0
	_stranded_damage_timer = 0.0
	stranded_return_target = Vector2.ZERO
	has_stranded_return_target = false
	velocity = Vector2.ZERO
	var mover = get_node_or_null("MoverModule") as MoverModule
	if mover:
		mover.is_active = false
		mover.target_position = global_position
	
	owner_type = new_owner
	_update_groups()
	_update_visuals()

func _draw() -> void:
	var base_color = _get_cell_color()
	var time = Time.get_ticks_msec() / 1000.0
	
	# Расчет эффекта попадания
	var hit_intensity = clampf(hit_flash_timer / 0.2, 0.0, 1.0)
	var display_color = base_color.lerp(Color.WHITE, hit_intensity)
	
	# Плавное потемнение при заражении
	if _visual_infection_factor > 0.01:
		var dark_color = display_color.darkened(0.7)
		display_color = display_color.lerp(dark_color, _visual_infection_factor)
	
	# Цвет обводки меняется если активен щит или скорострельность или спринт
	var outline_color = display_color.lightened(0.4)
	if reflect_chance > 0.0:
		# Цвет обводки совпадает с цветом щита
		var s_color = _get_cell_color().lightened(0.5)
		s_color.s = 1.0
		outline_color = s_color.lerp(Color.WHITE, hit_intensity)
	elif rapid_fire_timer > 0:
		# Пульсирующий оранжевый контур для скорострельности
		var pulse = (sin(time * 15.0) + 1.0) / 2.0
		var orange = Color(1.0, 0.5, 0.0)
		outline_color = display_color.lerp(orange, 0.4 + pulse * 0.6)
	elif speed_boost_timer > 0:
		# Яркий неоново-синий (изумрудно-голубой) контур для спринта
		var pulse = (sin(time * 20.0) + 1.0) / 2.0
		var cyan = Color(0.0, 0.8, 1.0)
		outline_color = display_color.lerp(cyan, 0.6 + pulse * 0.4)
	
	# ==========================================
	# ЖЕЛЕЙНАЯ ФИЗИКА (Squash and Stretch)
	# ==========================================
	var scale_x = 1.0 + visual_stretch
	var scale_y = 1.0 / max(0.1, scale_x) # Сохраняем объем (сплющиваем по бокам)
	
	# Применяем трансформацию ко всему, что будет нарисовано ниже
	draw_set_transform(Vector2.ZERO, visual_angle, Vector2(scale_x, scale_y))
	
	# Уникальный сдвиг фазы анимации для этой конкретной клетки
	var phase_offset = (global_position.x + global_position.y) * 0.01
	var local_time = time + phase_offset
	
	# Анимационное дыхание (пульсация мембраны)
	var breathe_factor = sin(local_time * 3.0) * 0.05 + 1.0 # от 0.95 до 1.05
	# При попадании клетка слегка вздувается
	var current_radius = radius * breathe_factor + (hit_intensity * 5.0)
	var screen_radius: float = _get_screen_radius(current_radius)
	var is_low_detail: bool = screen_radius < 18.0
	var is_medium_detail: bool = not is_low_detail and screen_radius < 30.0
	var organelles_enabled: bool = stats.current_energy > 15.0 and screen_radius >= 10.0
	
	# 1. Ламповое мягкое свечение (Glow)
	# ОПТИМИЗАЦИЯ: Свечение для Спринта и Щита теперь в Шейдере!
	# Оставляем тут только свечение для скорострельности
	if rapid_fire_timer > 0 and not is_low_detail:
		var glow_color = Color(1.0, 0.4, 0.1)
		glow_color.a = 0.15 + sin(local_time * 2.5) * 0.05 
		draw_circle(Vector2.ZERO, current_radius * 1.5, glow_color)
	
	# 2. Основное тело клетки (волнистая мембрана)
	var num_points: int = 12 if is_low_detail else (16 if is_medium_detail else 20)
	var points = PackedVector2Array()
	var fill_color = display_color.darkened(0.2)
	
	for i in range(num_points):
		var angle = (i / float(num_points)) * TAU
		var wobble = sin(angle * 5.0 + time * 4.0) * (current_radius * 0.08)
		
		# Хаотичное дрожание при попадании снаряда
		if hit_impact_wobble > 0.1:
			wobble += sin(angle * 12.0 + time * 20.0) * hit_impact_wobble
			
		var r = current_radius + wobble
		points.append(Vector2(cos(angle), sin(angle)) * r)
	
	# Оптимизация: один цвет вместо PackedColorArray
	draw_colored_polygon(points, fill_color)
	
	# Отрисовка вен (вирус)
	if _visual_infection_factor > 0.01 and not is_low_detail:
		var vein_color = display_color.darkened(0.9)
		vein_color.a = _visual_infection_factor * 0.8
		var seed_val = int(global_position.x * 13.0 + global_position.y * 37.0) 
		if last_outbreak_id != -1: seed_val += last_outbreak_id * 1024
		
		# Кешированный RNG (создаём только при смене сида)
		if _vein_rng == null or _vein_rng_seed != seed_val:
			_vein_rng = RandomNumberGenerator.new()
			_vein_rng_seed = seed_val
		_vein_rng.seed = seed_val # Сбрасываем seed каждый кадр для детерминизма
		
		for v in range(4):
			var v_pts = PackedVector2Array()
			var start_ang = _vein_rng.randf_range(0.0, TAU)
			var c_pos = Vector2(cos(start_ang), sin(start_ang)) * (current_radius * 0.9)
			v_pts.append(c_pos)
			
			for seg in range(4):
				var to_center = -c_pos.normalized().rotated(_vein_rng.randf_range(-0.6, 0.6))
				c_pos += to_center * (current_radius * 0.2)
				v_pts.append(c_pos)
			
			draw_polyline(v_pts, vein_color, 2.0 + _vein_rng.randf_range(0.0, 1.5), true)
	
	# 3. Основная обводка (мембрана)
	var main_points = points.duplicate()
	main_points.append(main_points[0]) # Замыкаем
	draw_polyline(main_points, outline_color, 2.5, true)

	# 3.1 Маркер отставшей клетки: тревожное кольцо и стрелка к центру колонии
	if is_stranded and has_stranded_return_target and owner_type != OwnerType.NEUTRAL and not is_low_detail:
		var alert_pulse = (sin(local_time * 8.0) + 1.0) * 0.5
		var alert_color = Color(1.0, 0.35, 0.2, 0.45 + alert_pulse * 0.25)
		var ring_radius = current_radius * (1.3 + alert_pulse * 0.08)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 40, alert_color, 3.0, true)

		var to_center = stranded_return_target - global_position
		if to_center.length_squared() > 0.001:
			var pointer_dir = to_center.normalized()
			var pointer_tip = pointer_dir * (current_radius * 1.75)
			var pointer_base = pointer_dir * (current_radius * 1.22)
			var pointer_side = Vector2(-pointer_dir.y, pointer_dir.x) * (current_radius * 0.22)
			var pointer_points = PackedVector2Array([
				pointer_tip,
				pointer_base + pointer_side,
				pointer_base - pointer_side,
			])
			draw_colored_polygon(pointer_points, Color(1.0, 0.55, 0.2, 0.95))
			draw_polyline(pointer_points + PackedVector2Array([pointer_tip]), Color(1.0, 0.9, 0.7, 0.85), 1.5, true)
	
	# 4. ЭНЕРГЕТИЧЕСКИЙ КУПОЛ (ЩИТ / СПРИНТ) - визуализация перенесена в _process
	
	# 4. Ядро (Nucleus) - плавает около центра
	var nucleus_pos = Vector2(cos(local_time * 1.5), sin(local_time * 2.1)) * (current_radius * 0.15)
	var nucleus_color = display_color.lightened(0.6)
	if rapid_fire_timer > 0:
		nucleus_color = Color(1.0, 0.6, 0.1) # Раскаленное оранжевое ядро
	nucleus_color.a = 0.85
	draw_circle(nucleus_pos, current_radius * 0.4, nucleus_color)
	# Блик на ядре оставляем всегда, чтобы клетка не выглядела пустой на дальнем плане.
	var highlight_pos = nucleus_pos + Vector2(-current_radius * 0.1, -current_radius * 0.1)
	draw_circle(highlight_pos, current_radius * 0.1, Color.WHITE)
	
	# 5. Органеллы (маленькие точки внутри), которые медленно кружатся (или быстро при спринте)
	var organelle_count: int = 0
	if organelles_enabled:
		organelle_count = 1 if screen_radius < 20.0 else (2 if is_medium_detail else 3)
	for i in range(organelle_count):
		var org_speed = 1.0 + i * 0.2
		if speed_boost_timer > 0:
			org_speed *= 4.0 # Завихрение энергии внутри
			
		var org_angle = local_time * org_speed + (i * TAU / 3.0)
		# орбита чуть дышит
		var org_dist = current_radius * 0.6 + sin(local_time * 3.0 + i) * 3.0
		var org_pos = Vector2(cos(org_angle), sin(org_angle)) * org_dist
		var org_color = display_color.lightened(0.3)
		org_color.a = 0.7
		draw_circle(org_pos, current_radius * 0.12, org_color)


func _get_cell_color() -> Color:
	match owner_type:
		OwnerType.PLAYER:       return Color(0.40, 0.60, 1.00)  # Синий
		OwnerType.ENEMY_RED:    return Color(0.90, 0.30, 0.30)  # Красный
		OwnerType.ENEMY_GREEN:  return Color(0.25, 0.80, 0.35)  # Зелёный
		OwnerType.ENEMY_YELLOW: return Color(0.95, 0.80, 0.15)  # Жёлтый
	return Color(0.55, 0.55, 0.55) # Серый нейтрал

func _process(delta: float) -> void:
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
	if hit_impact_wobble > 0.0:
		hit_impact_wobble = lerp(hit_impact_wobble, 0.0, delta * 15.0)

	if reflect_timer > 0.0:
		reflect_timer -= delta
		if reflect_timer <= 0.0:
			reflect_chance = 0.0
			queue_redraw()

	_update_stranded_state(delta)
			
	# Обработка таймера ускорения
	if speed_boost_timer > 0.0:
		speed_boost_timer -= delta
		if speed_boost_timer <= 0.0:
			speed_boost_timer = 0.0
			queue_redraw()
			
	# Обработка таймера скорострельности
	if rapid_fire_timer > 0.0:
		rapid_fire_timer -= delta
		if rapid_fire_timer <= 0.0:
			rapid_fire_timer = 0.0
			current_fire_rate_multiplier = 1.0
			queue_redraw()

	# Обработка таймера вируса
	if is_infected:
		infection_timer -= delta
		_spread_timer -= delta
		
		# Распространение вируса раз в секунду
		if _spread_timer <= 0:
			_spread_timer = 1.0
			_spread_infection()
			
		if infection_timer <= 0:
			is_infected = false
			
		_visual_infection_factor = lerp(_visual_infection_factor, 1.0, delta * 2.0)
	else:
		_visual_infection_factor = lerp(_visual_infection_factor, 0.0, delta * 3.0)

	# Сглаживание желейной физики
	var speed = velocity.length()
	var max_stretch = 0.4
	if speed_boost_timer > 0:
		max_stretch = 0.75 # При ускорении клетка становится более "стреловидной"
		
	var target_stretch = clampf(speed / 250.0, 0.0, max_stretch)
	visual_stretch = lerp(visual_stretch, target_stretch, delta * 12.0)
	
	if speed > 5.0:
		visual_angle = lerp_angle(visual_angle, velocity.angle(), delta * 8.0)

	if is_infected:
		# Истощение энергии при заражении (1 HP каждые 1.5 сек)
		var drain = (1.0 / 1.5) * delta
		stats.current_energy -= drain
		
		# Если энергия упала до нуля - клетка становится нейтральной
		if stats.current_energy <= 0.0:
			stats.current_energy = 0.0
			_capture(OwnerType.NEUTRAL)
	elif is_stranded:
		_apply_stranded_damage(delta)
	elif owner_type != OwnerType.NEUTRAL:
		_stranded_damage_timer = 0.0
		stats.current_energy = min(stats.max_energy, stats.current_energy + stats.energy_gain_rate * delta)
	else:
		_stranded_damage_timer = 0.0
	
	_update_size()
	_ui_timer += delta
	if _ui_timer >= UI_UPDATE_INTERVAL:
		_ui_timer = 0.0
		_update_ui()
	
	# Распад вклада через 10 секунд бездействия
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_damage_time > 10.0:
		decay_accum += delta
		if decay_accum >= 2.0: # Каждые 2 секунды
			decay_accum = 0.0
			for key in contributions.keys():
				contributions[key] = max(0.0, contributions[key] - 1.0)
			queue_redraw()

	# Обновление ShieldOverlay (перенесено из _draw, чтобы не вызывать побочные эффекты при отрисовке)
	if reflect_chance > 0.0 or speed_boost_timer > 0.0:
		_update_shield_overlay()
	elif shield_overlay and shield_overlay.visible:
		shield_overlay.visible = false

	# Оптимизация: перерисовка только ~30 раз в секунду (физика остаётся 60fps)
	_redraw_timer += delta
	if _redraw_timer >= REDRAW_INTERVAL:
		_redraw_timer = 0.0
		queue_redraw()

func _update_stranded_state(delta: float) -> void:
	if owner_type == OwnerType.NEUTRAL:
		is_stranded = false
		_stranded_damage_timer = 0.0
		stranded_return_target = Vector2.ZERO
		has_stranded_return_target = false
		return

	_stranded_check_timer += delta
	if _stranded_check_timer < STRANDED_CHECK_INTERVAL:
		return
	_stranded_check_timer = 0.0

	var group_name := get_group_for_owner(owner_type)
	if group_name == "":
		is_stranded = false
		_stranded_damage_timer = 0.0
		stranded_return_target = Vector2.ZERO
		has_stranded_return_target = false
		return

	var own_cells := get_tree().get_nodes_in_group(group_name)
	if own_cells.is_empty():
		is_stranded = false
		_stranded_damage_timer = 0.0
		stranded_return_target = Vector2.ZERO
		has_stranded_return_target = false
		return

	var colony_center := get_colony_center(get_tree(), owner_type)
	stranded_return_target = colony_center
	has_stranded_return_target = true
	var was_stranded := is_stranded
	is_stranded = global_position.distance_to(colony_center) > STRANDED_DISTANCE_THRESHOLD
	if not is_stranded:
		_stranded_damage_timer = 0.0
	elif not was_stranded:
		_stranded_damage_timer = 0.0

func _apply_stranded_damage(delta: float) -> void:
	_stranded_damage_timer += delta
	if _stranded_damage_timer < STRANDED_DAMAGE_INTERVAL:
		return

	while _stranded_damage_timer >= STRANDED_DAMAGE_INTERVAL:
		_stranded_damage_timer -= STRANDED_DAMAGE_INTERVAL
		stats.current_energy -= STRANDED_DAMAGE_AMOUNT
		# Тот же визуальный отклик, как при попадании снаряда
		hit_flash_timer = 0.2
		hit_impact_wobble = 15.0
		queue_redraw()

		if stats.current_energy <= 0.0:
			stats.current_energy = 0.0
			_capture(OwnerType.NEUTRAL)
			return

func _physics_process(_delta: float) -> void:
	move_and_slide()

func command_attack(target_pos: Vector2, target_node: Node2D = null) -> void:
	if is_infected: return # Зараженная клетка не слушает команд
	var shooter = get_node_or_null("ShooterModule")
	if shooter: shooter.set_target(target_pos, target_node)
	var mover = get_node_or_null("MoverModule")
	if mover: mover.set_target(target_pos)

func command_move(target_pos: Vector2) -> void:
	if is_infected: return # Зараженная клетка не слушает команд
	var shooter = get_node_or_null("ShooterModule")
	if shooter:
		shooter.is_active = false
		shooter.target_node = null
	var mover = get_node_or_null("MoverModule")
	if mover: mover.set_target(target_pos)

func apply_speed_boost(duration: float, multiplier: float) -> void:
	if is_infected: return
	speed_boost_timer = duration
	current_speed_multiplier = multiplier
	queue_redraw()

func apply_rapid_fire(duration: float, multiplier: float) -> void:
	if is_infected: return
	rapid_fire_timer = duration
	current_fire_rate_multiplier = multiplier
	queue_redraw()

func infect(duration: float = -1.0, outbreak_id: int = -1) -> void:
	# Если мы уже болеем этой конкретной волной или уже переболели ей — игнорируем
	if outbreak_id != -1 and (is_infected or last_outbreak_id == outbreak_id):
		return
		
	is_infected = true
	
	# Сброс баффов при заражении
	reflect_chance = 0.0
	reflect_timer = 0.0
	speed_boost_timer = 0.0
	current_speed_multiplier = 1.0
	rapid_fire_timer = 0.0
	current_fire_rate_multiplier = 1.0
	if shield_overlay and shield_overlay.visible:
		shield_overlay.visible = false
	
	if outbreak_id != -1:
		last_outbreak_id = outbreak_id
	
	# Если длительность не передана, берем из настроек SelectionManager
	if duration < 0:
		var sm = get_tree().get_first_node_in_group("selection_manager")
		if sm: infection_timer = sm.VIRUS_DURATION
		else: infection_timer = 6.0
	else:
		infection_timer = duration
		
	_spread_timer = 1.0
	queue_redraw()

func _spread_infection() -> void:
	var sm = get_tree().get_first_node_in_group("selection_manager")
	var spread_range = 200.0
	if sm: spread_range = sm.VIRUS_SPREAD_RADIUS
	
	var all_cells = get_tree().get_nodes_in_group("cells")
	for cell in all_cells:
		if cell != self and cell is BaseCell and cell.owner_type == owner_type:
			if not cell.is_infected and cell.last_outbreak_id != last_outbreak_id:
				if global_position.distance_to(cell.global_position) <= spread_range:
					cell.infect(-1.0, last_outbreak_id) # Передаем ID текущей волны

func _update_shield_overlay() -> void:
	if not shield_overlay: return
	
	if is_infected:
		shield_overlay.visible = false
		return
		
	if not shield_overlay.visible: shield_overlay.visible = true
	
	# Подгоняем размер под текущий радиус клетки
	var s = radius * 3.0 # Сделали чуть больше для ауры
	shield_overlay.size = Vector2(s, s)
	shield_overlay.position = -Vector2(s, s) / 2.0
	
	var mat = shield_overlay.material as ShaderMaterial
	if not mat: return
	
	if reflect_chance > 0.0:
		# РЕЖИМ ЩИТА (Базовый цвет щита)
		var s_color = _get_cell_color().lightened(0.5)
		s_color.s = 1.0
		mat.set_shader_parameter("shield_color", s_color)
		mat.set_shader_parameter("has_shield", true)
	else:
		mat.set_shader_parameter("has_shield", false)
		
	if speed_boost_timer > 0.0:
		# РЕЖИМ СПРИНТА (Оптимизированные полоски скорости)
		var c_color = Color(0.0, 0.8, 1.0) # Неоново-синий
		mat.set_shader_parameter("sprint_color_tint", c_color)
		mat.set_shader_parameter("sprint_mode", true)
		mat.set_shader_parameter("aura_intensity", 1.0)
		mat.set_shader_parameter("sprint_angle", visual_angle)
	else:
		mat.set_shader_parameter("sprint_mode", false)

	# Интенсивность подгоняем
	if speed_boost_timer > 0.0 and reflect_chance <= 0.0:
		mat.set_shader_parameter("intensity", 1.8) # Поярче, если только спринт
	elif speed_boost_timer > 0.0 and reflect_chance > 0.0:
		mat.set_shader_parameter("intensity", 1.2) # Слегка ярче при обоих
	else:
		mat.set_shader_parameter("intensity", 1.0) # Обычный щит

func _update_visuals() -> void:
	queue_redraw()

func _update_size() -> void:
	var target_scale = max(0.5, 1.0 + (stats.current_energy * stats.size_multiplier))
	scale = lerp(scale, Vector2(target_scale, target_scale), 0.1)

func _update_ui() -> void:
	var screen_radius: float = _get_screen_radius(radius * scale.x)
	var show_energy: bool = false
	match owner_type:
		OwnerType.PLAYER:
			show_energy = screen_radius >= 14.0
		OwnerType.NEUTRAL:
			show_energy = screen_radius >= 26.0
		_:
			show_energy = screen_radius >= 20.0

	if energy_label:
		if show_energy:
			# roundi() переводит float в красивый int без ".0"
			energy_label.text = str(roundi(stats.current_energy))
			# Чтобы текст не расплющивало вместе с желейной физикой:
			# Используем общий scale клетки, а не её текущий сплющенный scale_x / scale_y
			var base_scale = max(0.5, 1.0 + (stats.current_energy * stats.size_multiplier))
			energy_label.scale = Vector2.ONE / base_scale
			_set_energy_ui_visible(true)
		else:
			_set_energy_ui_visible(false)
	
	if contr_label:
		var player_cont = contributions.get(OwnerType.PLAYER, 0.0)
		if player_cont > 0.5 and screen_radius >= 24.0:
			contr_label.text = "+" + str(roundi(player_cont))
			_set_contribution_ui_visible(true)
			# Позиционируем Label за пределами клетки
			contr_label.position = Vector2(radius * 0.8, -radius * 1.5)
			
			var base_scale = max(0.5, 1.0 + (stats.current_energy * stats.size_multiplier))
			contr_label.scale = Vector2.ONE / base_scale
		else:
			_set_contribution_ui_visible(false)

func _get_screen_radius(world_radius: float) -> float:
	var viewport := get_viewport()
	if viewport == null:
		return world_radius
	var canvas_transform: Transform2D = viewport.get_canvas_transform()
	var screen_offset: Vector2 = canvas_transform.basis_xform(Vector2(world_radius, 0.0))
	return screen_offset.length()

func _set_energy_ui_visible(visible: bool) -> void:
	if energy_label and energy_label.visible != visible:
		energy_label.visible = visible

func _set_contribution_ui_visible(visible: bool) -> void:
	if contr_label and contr_label.visible != visible:
		contr_label.visible = visible
