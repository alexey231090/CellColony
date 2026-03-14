extends CharacterBody2D
class_name BaseCell

# 4 фракции: Нейтрал, Игрок (синий), Враг-красный, Враг-зелёный, Враг-жёлтый
enum OwnerType { NEUTRAL, PLAYER, ENEMY_RED, ENEMY_GREEN, ENEMY_YELLOW }

@export var owner_type: OwnerType = OwnerType.NEUTRAL
@export var stats: CellStats = CellStats.new()
@export var radius: float = 32.0

@onready var energy_label: Label = $EnergyLabel
@onready var contr_label: Label = $ContrLabel

# Визуальные эффекты при попадании
var hit_flash_timer: float = 0.0
var hit_impact_wobble: float = 0.0

# Баффы
var reflect_chance: float = 0.0
var reflect_timer: float = 0.0

# Ускорение (новый перк)
var speed_boost_timer: float = 0.0
var current_speed_multiplier: float = 1.0

# Сглаживание желейной физики
var visual_stretch: float = 0.0
var visual_angle: float = 0.0

# Система вклада (для перков)
var contributions: Dictionary = {} # OwnerType -> float
var last_damage_time: float = 0.0
var decay_accum: float = 0.0

# Оптимизация: троттлинг перерисовки
var _redraw_timer: float = 0.0
const REDRAW_INTERVAL: float = 0.033 # ~30 FPS для отрисовки (физика остаётся 60)

func _ready() -> void:
	add_to_group("cells")
	_update_groups()
	_update_visuals()
	
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
	for g in ["player_cells", "enemy_red_cells", "enemy_green_cells", "enemy_yellow_cells"]:
		if is_in_group(g): remove_from_group(g)
	match owner_type:
		OwnerType.PLAYER:       add_to_group("player_cells")
		OwnerType.ENEMY_RED:    add_to_group("enemy_red_cells")
		OwnerType.ENEMY_GREEN:  add_to_group("enemy_green_cells")
		OwnerType.ENEMY_YELLOW: add_to_group("enemy_yellow_cells")

func take_damage(amount: float, attacker_owner: OwnerType) -> void:
	if owner_type == attacker_owner:
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
	# Награда за захват: отдаем накопленный вклад новому владельцу
	if new_owner == OwnerType.PLAYER:
		var reward = contributions.get(OwnerType.PLAYER, 0.0)
		if reward > 0:
			var sm = get_tree().get_first_node_in_group("selection_manager")
			if sm and sm.has_method("add_perk_energy"):
				sm.add_perk_energy(reward)
	
	# Сбрасываем вклады и баффы (щит, ускорение) после смены владельца
	contributions.clear()
	reflect_chance = 0.0
	reflect_timer = 0.0
	speed_boost_timer = 0.0
	
	owner_type = new_owner
	_update_groups()
	_update_visuals()

func _draw() -> void:
	var base_color = _get_cell_color()
	var time = Time.get_ticks_msec() / 1000.0
	
	# Расчет эффекта попадания
	var hit_intensity = clampf(hit_flash_timer / 0.2, 0.0, 1.0)
	var display_color = base_color.lerp(Color.WHITE, hit_intensity)
	
	# Цвет обводки меняется если активен щит
	var outline_color = display_color.lightened(0.4)
	if reflect_chance > 0.0:
		# Ярко-зеленый цвет для щита
		outline_color = Color(0.2, 1.0, 0.5).lerp(Color.WHITE, hit_intensity)
	
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
	
	# 1. Ламповое мягкое свечение (Glow)
	var glow_color = display_color
	if speed_boost_timer > 0:
		glow_color = Color(0.2, 0.5, 1.0) # Синее свечение для спринта
		
	# Мягкая пульсация прозрачности свечения
	glow_color.a = 0.15 + sin(local_time * 2.5) * 0.05 
	draw_circle(Vector2.ZERO, current_radius * 1.5, glow_color)
	
	# 2. Основное тело клетки (волнистая мембрана)
	var num_points: int = 20 # Оптимизация: 20 вместо 32, визуально незаметно
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
	
	# 3. Основная обводка (мембрана)
	var main_points = points.duplicate()
	main_points.append(main_points[0]) # Замыкаем
	draw_polyline(main_points, outline_color, 2.5, true)
	
	# 4. Пунктирные линии щита (бегут прямо ПО обводке)
	if reflect_chance > 0.0:
		var dash_color = Color(0.088, 0.06, 0.216, 0.502) # Темный пунктир
		var dash_count = 4 # Количество длинных сегментов
		var segment_size = 4 # Сколько точек в одном пунктире (из 20 всего)
		
		# Рассчитываем стартовый индекс от времени для анимации движения
		var offset_idx = int(time * 15.0) % num_points
		
		for d in range(dash_count):
			var start_idx = (offset_idx + d * (num_points / dash_count)) % num_points
			var dash_seg = PackedVector2Array()
			
			for step in range(segment_size + 1):
				var idx = (start_idx + step) % num_points
				dash_seg.append(points[idx])
			
			# Рисуем сегмент пунктира ПОВЕРХ основной линии
			# Используем чуть большую толщину, чтобы он перекрывал зеленую линию
			draw_polyline(dash_seg, dash_color, 3.2, true)
	
	# 4. Ядро (Nucleus) - плавает около центра
	var nucleus_pos = Vector2(cos(local_time * 1.5), sin(local_time * 2.1)) * (current_radius * 0.15)
	var nucleus_color = display_color.lightened(0.6)
	nucleus_color.a = 0.85
	draw_circle(nucleus_pos, current_radius * 0.4, nucleus_color)
	# Блик на ядре
	var highlight_pos = nucleus_pos + Vector2(-current_radius * 0.1, -current_radius * 0.1)
	draw_circle(highlight_pos, current_radius * 0.1, Color.WHITE)
	
	# 5. Органеллы (маленькие точки внутри), которые медленно кружатся
	for i in range(3):
		var org_speed = 1.0 + i * 0.2
		var org_angle = local_time * org_speed + (i * TAU / 3.0)
		# орбита чуть дышит
		var org_dist = current_radius * 0.6 + sin(local_time * 3.0 + i) * 3.0
		var org_pos = Vector2(cos(org_angle), sin(org_angle)) * org_dist
		var org_color = display_color.lightened(0.3)
		org_color.a = 0.7
		draw_circle(org_pos, current_radius * 0.12, org_color)

	# 6. Щит (Отражение) - визуализация теперь через ShieldOverlay
	pass

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
			
	# Обработка таймера ускорения
	if speed_boost_timer > 0.0:
		speed_boost_timer -= delta
		if speed_boost_timer <= 0.0:
			speed_boost_timer = 0.0
			queue_redraw()

	# Сглаживание желейной физики
	var speed = velocity.length()
	var target_stretch = clampf(speed / 250.0, 0.0, 0.4)
	visual_stretch = lerp(visual_stretch, target_stretch, delta * 12.0)
	
	if speed > 5.0:
		visual_angle = lerp_angle(visual_angle, velocity.angle(), delta * 8.0)

	if owner_type != OwnerType.NEUTRAL:
		stats.current_energy = min(stats.max_energy, stats.current_energy + stats.energy_gain_rate * delta)
	
	_update_size()
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

	# Оптимизация: перерисовка только ~30 раз в секунду (физика остаётся 60fps)
	_redraw_timer += delta
	if _redraw_timer >= REDRAW_INTERVAL:
		_redraw_timer = 0.0
		queue_redraw()

func _physics_process(_delta: float) -> void:
	move_and_slide()

func command_attack(target_pos: Vector2, target_node: Node2D = null) -> void:
	var shooter = get_node_or_null("ShooterModule")
	if shooter: shooter.set_target(target_pos, target_node)
	var mover = get_node_or_null("MoverModule")
	if mover: mover.set_target(target_pos)

func command_move(target_pos: Vector2) -> void:
	var shooter = get_node_or_null("ShooterModule")
	if shooter:
		shooter.is_active = false
		shooter.target_node = null
	var mover = get_node_or_null("MoverModule")
	if mover: mover.set_target(target_pos)

func apply_speed_boost(duration: float, multiplier: float) -> void:
	speed_boost_timer = duration
	current_speed_multiplier = multiplier
	queue_redraw()

func _update_visuals() -> void:
	queue_redraw()

func _update_size() -> void:
	var target_scale = max(0.5, 1.0 + (stats.current_energy * stats.size_multiplier))
	scale = lerp(scale, Vector2(target_scale, target_scale), 0.1)

func _update_ui() -> void:
	if energy_label:
		# roundi() переводит float в красивый int без ".0"
		energy_label.text = str(roundi(stats.current_energy))
		# Чтобы текст не расплющивало вместе с желейной физикой:
		# Используем общий scale клетки, а не её текущий сплющенный scale_x / scale_y
		var base_scale = max(0.5, 1.0 + (stats.current_energy * stats.size_multiplier))
		energy_label.scale = Vector2.ONE / base_scale
	
	if contr_label:
		var player_cont = contributions.get(OwnerType.PLAYER, 0.0)
		if player_cont > 0.5:
			contr_label.text = "+" + str(roundi(player_cont))
			contr_label.show()
			# Позиционируем Label за пределами клетки
			contr_label.position = Vector2(radius * 0.8, -radius * 1.5)
			
			var base_scale = max(0.5, 1.0 + (stats.current_energy * stats.size_multiplier))
			contr_label.scale = Vector2.ONE / base_scale
		else:
			contr_label.hide()
