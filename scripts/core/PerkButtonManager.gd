extends Node2D
class_name PerkButtonManager
## PerkButtonManager (Smooth & Smart Edition)
## Улучшенная система с плавной интерполяцией, умным распределением по клеткам
## и анимацией перелёта. Кнопки исчезают при смерти их клетки.

# --- Константы Дизайна ---
const ICON_SCREEN_RADIUS: float = 24.0
const COLLISION_RADIUS: float = 56.0
const SEEK_INTERVAL: float = 0.05
const STABILITY_TIME: float = 0.5
const DRAG_THRESHOLD: float = 25.0
const HYSTERESIS_RATIO: float = 1.5
const DEAD_ZONE_DISTANCE: float = 140.0    # Увеличено для лучшего разделения
const COOLDOWN_ICON_COLOR := Color(0.55, 0.55, 0.58, 1.0)
const NO_ENERGY_ICON_COLOR := Color(0.28, 0.28, 0.3, 0.92)
const SHIELD_ICON := preload("res://assets/sprites/shield.png")
const SHIELD_ICON_SCALE: float = 1.25
const RAPID_FIRE_ICON := preload("res://assets/sprites/speedfire2.png")
const RAPID_FIRE_ICON_SCALE: float = 1.25
const SPEED_ICON := preload("res://assets/sprites/speed.png")
const SPEED_ICON_SCALE: float = 1.25

# --- Физика (Liquid Motion) ---
const SPRING_STIFFNESS: float = 120.0
const SPRING_DAMPING: float = 18.0
const CENTER_LERP_SPEED: float = 4.0
const DRIFT_SPEED: float = 1.0
const DRIFT_STRENGTH: float = 8.0
const REPULSION_FORCE: float = 5000.0      # Усилено для надёжного разделения
const MAX_VELOCITY: float = 800.0          # Ограничение скорости

# --- Анимация перелёта ---
const TRANSITION_DURATION: float = 0.4     # Длительность перелёта между клетками
const TRAIL_LENGTH: int = 8                # Количество точек в шлейфе

# --- Класс Иконки ---
class FloatingIcon:
	var perk_name: String = ""
	var host_cell: BaseCell = null
	
	# Стабильность выбора
	var candidate_cell: BaseCell = null
	var candidate_timer: float = 0.0
	
	# Физика
	var pos: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var noise_offset: float = 0.0
	var offset_current: Vector2 = Vector2.ZERO
	
	# Плавный переход между клетками
	var is_transitioning: bool = false
	var transition_timer: float = 0.0
	var transition_start_pos: Vector2 = Vector2.ZERO
	var transition_target_pos: Vector2 = Vector2.ZERO
	
	# Trail эффект
	var trail_positions: Array[Vector2] = []
	
	# Видимость (для fade out при смерти клетки)
	var is_visible: bool = true
	var fade_alpha: float = 1.0

var icons: Array[FloatingIcon] = []
var _colony_center: Vector2 = Vector2.ZERO
var _seek_timer: float = 0.0

# Ввод
var _drag_icon: FloatingIcon = null
var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _aim_line: Line2D = null

func _ready() -> void:
	add_to_group("perk_button_manager")
	z_index = 105 # Поверх щитов (100)
	
	var ids = ["shield", "speed", "rapid_fire", "virus"]
	for i in range(ids.size()):
		var id = ids[i]
		var icon = FloatingIcon.new()
		icon.perk_name = id
		# Квадратное/Крестовое распределение
		var angle = (TAU / ids.size()) * i - PI/2.0
		icon.pos = get_viewport().get_visible_rect().size / 2.0 + Vector2.RIGHT.rotated(angle) * 120.0
		icons.append(icon)

func _process(delta: float) -> void:
	_update_colony_center(delta)
	
	# Обновление логики выбора (стабильность)
	_seek_timer -= delta
	if _seek_timer <= 0.0:
		_seek_timer = SEEK_INTERVAL
		_update_targets_logic(delta)

	_update_physics(delta)
	queue_redraw()

func _update_colony_center(delta: float) -> void:
	var cells = get_tree().get_nodes_in_group("player_cells")
	if cells.is_empty(): return
	var sum := Vector2.ZERO
	var count := 0
	for c in cells:
		if c is BaseCell:
			sum += c.global_position
			count += 1
	if count > 0:
		var raw = sum / float(count)
		if _colony_center == Vector2.ZERO: _colony_center = raw
		else: _colony_center = _colony_center.lerp(raw, delta * CENTER_LERP_SPEED)

func _update_targets_logic(delta: float) -> void:
	var cells_nodes = get_tree().get_nodes_in_group("player_cells")
	if cells_nodes.is_empty():
		for icon in icons:
			if icon.host_cell != null:
				_start_fade_out(icon)
		return

	var valid_cells: Array[BaseCell] = []
	for c in cells_nodes: if c is BaseCell: valid_cells.append(c)
	
	# Сортировка по близости к центру
	valid_cells.sort_custom(func(a, b):
		return a.global_position.distance_squared_to(_colony_center) < b.global_position.distance_squared_to(_colony_center)
	)

	# Умное распределение: каждая кнопка получает свою клетку из топ-4
	for i in range(icons.size()):
		var icon = icons[i]
		
		# Если клеток меньше, чем кнопок - распределяем равномерно
		var cell_index = i % valid_cells.size()
		var ideal_candidate: BaseCell = valid_cells[cell_index]
		
		_process_stable_assignment(icon, ideal_candidate, SEEK_INTERVAL)

func _process_stable_assignment(icon: FloatingIcon, ideal: BaseCell, dt: float) -> void:
	# 1. Если текущий хозяин битый или умер - начинаем переход к новой клетке
	if not is_instance_valid(icon.host_cell) or icon.host_cell.owner_type != 1:
		if is_instance_valid(ideal):
			_start_transition(icon, ideal)
		else:
			_start_fade_out(icon)
		icon.candidate_cell = null
		icon.candidate_timer = 0.0
		return
		
	# 2. Если идеальный совпадает с текущим - сбрасываем таймер
	if icon.host_cell == ideal:
		icon.candidate_cell = null
		icon.candidate_timer = 0.0
		return
		
	# 3. Если появился новый кандидат
	if icon.candidate_cell != ideal:
		icon.candidate_cell = ideal
		icon.candidate_timer = 0.0
	else:
		icon.candidate_timer += dt
		# Если новый кандидат лучше уже 0.5 сек - начинаем плавный переход
		if icon.candidate_timer >= STABILITY_TIME:
			_start_transition(icon, ideal)
			icon.candidate_timer = 0.0

func _start_transition(icon: FloatingIcon, new_cell: BaseCell) -> void:
	## Запускает плавный переход кнопки к новой клетке
	if not is_instance_valid(new_cell): return
	
	icon.is_transitioning = true
	icon.transition_timer = 0.0
	icon.transition_start_pos = icon.pos
	icon.transition_target_pos = new_cell.global_position
	icon.host_cell = new_cell
	icon.velocity = Vector2.ZERO  # Сбрасываем скорость для плавного перехода
	icon.is_visible = true
	icon.fade_alpha = 1.0

func _start_fade_out(icon: FloatingIcon) -> void:
	## Запускает исчезновение кнопки
	icon.host_cell = null
	icon.is_visible = false

func _update_physics(delta: float) -> void:
	var camera = get_viewport().get_camera_2d()
	var zoom = camera.zoom.x if camera else 1.0
	var min_dist = (COLLISION_RADIUS * 2.0) / zoom
	var time = Time.get_ticks_msec() / 1000.0

	for i in range(icons.size()):
		var icon = icons[i]
		
		# Обновление trail эффекта
		_update_trail(icon)
		
		# Если кнопка невидима - пропускаем физику
		if not icon.is_visible:
			icon.fade_alpha = max(0.0, icon.fade_alpha - delta * 3.0)
			continue
		
		# Режим плавного перехода между клетками
		if icon.is_transitioning:
			icon.transition_timer += delta
			var progress = min(1.0, icon.transition_timer / TRANSITION_DURATION)
			
			# Ease-out интерполяция для плавности
			var eased = 1.0 - pow(1.0 - progress, 3.0)
			icon.pos = icon.transition_start_pos.lerp(icon.transition_target_pos, eased)
			
			# Завершение перехода
			if progress >= 1.0:
				icon.is_transitioning = false
				icon.transition_timer = 0.0
			
			continue  # Пропускаем обычную физику во время перехода
		
		# Обычная физика (когда не в режиме перехода)
		if not is_instance_valid(icon.host_cell): continue
		
		# А) Расположение (Offset) - угловое распределение для предсказуемости
		var angle_offset = (TAU / icons.size()) * i - PI/2.0  # Начинаем сверху
		var target_offset = Vector2.RIGHT.rotated(angle_offset)
		
		icon.offset_current = icon.offset_current.lerp(target_offset, delta * 3.0)
		var target_pos = icon.host_cell.global_position + icon.offset_current * (icon.host_cell.radius * 1.6)
		
		if icon.pos == Vector2.ZERO: icon.pos = target_pos
		
		# Б) Пружина
		var diff = icon.pos - target_pos
		var acc = -diff * SPRING_STIFFNESS - icon.velocity * SPRING_DAMPING
		
		# В) Дрейф
		var drift = Vector2(
			sin(time * DRIFT_SPEED + icon.noise_offset),
			cos(time * DRIFT_SPEED * 0.8 + icon.noise_offset * 1.5)
		) * DRIFT_STRENGTH
		acc += drift * 15.0
		
		# Г) Улучшенная система отталкивания с зонами приоритета
		for j in range(icons.size()):
			if i == j: continue
			var other = icons[j]
			if not is_instance_valid(other.host_cell) or other.is_transitioning: continue
			
			var push_vec = icon.pos - other.pos
			var dist = push_vec.length()
			
			# Мертвая зона: усиленное отталкивание
			if dist < DEAD_ZONE_DISTANCE and dist > 0.1:
				var dead_zone_force = REPULSION_FORCE * 4.0
				acc += push_vec.normalized() * dead_zone_force
			elif dist < min_dist and dist > 0.1:
				# Обычное отталкивание
				var ratio = 1.0 - (dist / min_dist)
				var force = ratio * ratio * REPULSION_FORCE * 2.5
				acc += push_vec.normalized() * force
				
				# Жесткая коллизия
				var hard_radius = (ICON_SCREEN_RADIUS * 2.2 / zoom)
				if dist < hard_radius:
					var overlap = hard_radius - dist
					icon.pos += push_vec.normalized() * overlap * 0.7
					if not other.is_transitioning:
						other.pos -= push_vec.normalized() * overlap * 0.7

		# Интеграция с ограничением скорости
		icon.velocity += acc * delta
		
		# Ограничение максимальной скорости
		if icon.velocity.length() > MAX_VELOCITY:
			icon.velocity = icon.velocity.normalized() * MAX_VELOCITY
		
		icon.pos += icon.velocity * delta

func _update_trail(icon: FloatingIcon) -> void:
	## Обновляет шлейф за кнопкой
	icon.trail_positions.push_front(icon.pos)
	if icon.trail_positions.size() > TRAIL_LENGTH:
		icon.trail_positions.resize(TRAIL_LENGTH)

func _draw() -> void:
	var camera = get_viewport().get_camera_2d()
	var zoom = camera.zoom.x if camera else 1.0
	var r = ICON_SCREEN_RADIUS / zoom

	var sm = get_tree().get_first_node_in_group("selection_manager")
	
	# 1. При перетаскивании - рисуем линию прицеливания и РАДИУС
	if _is_dragging and _drag_icon and sm:
		var target_pos = get_global_mouse_position()
		var d_pos = to_local(_drag_icon.pos)
		var t_pos_loc = to_local(target_pos)
		
		# Линия прицеливания (Линия от иконки до мыши)
		draw_line(d_pos, t_pos_loc, Color(0.2, 0.9, 1.0, 0.3), 4.0/zoom)
		
		# Зона воздействия (Круг радиуса)
		var aoe_radius = 0.0
		var aoe_col = Color(1, 1, 1, 0.15)
		
		if _drag_icon.perk_name == "shield":
			aoe_radius = sm.SHIELD_SELECT_RADIUS
			aoe_col = Color(0.2, 0.8, 1.0, 0.15)
		elif _drag_icon.perk_name == "virus":
			aoe_radius = sm.VIRUS_SPREAD_RADIUS
			aoe_col = Color(0.8, 0.1, 0.1, 0.15)
			
		if aoe_radius > 0:
			draw_circle(t_pos_loc, aoe_radius, aoe_col)
			draw_arc(t_pos_loc, aoe_radius, 0, TAU, 64, Color(aoe_col.r, aoe_col.g, aoe_col.b, 0.4), 2.0/zoom)

	for icon in icons:
		# Пропускаем невидимые кнопки
		if not icon.is_visible and icon.fade_alpha <= 0.0: continue
		if not is_instance_valid(icon.host_cell) and not icon.is_transitioning: continue
		if icon.pos == Vector2.ZERO: continue
		
		var d_pos = to_local(icon.pos)
		var alpha_mult = icon.fade_alpha if not icon.is_visible else 1.0
		
		# Trail эффект во время перехода
		if icon.is_transitioning and icon.trail_positions.size() > 1:
			for t in range(1, icon.trail_positions.size()):
				var trail_alpha = (1.0 - float(t) / TRAIL_LENGTH) * 0.3 * alpha_mult
				var trail_pos = to_local(icon.trail_positions[t])
				var trail_size = r * (1.0 - float(t) / TRAIL_LENGTH) * 0.5
				draw_circle(trail_pos, trail_size, Color(1, 1, 1, trail_alpha))
		
		# Трос (связь с клеткой) - только если не в переходе
		if is_instance_valid(icon.host_cell) and not icon.is_transitioning:
			var host_local = to_local(icon.host_cell.global_position)
			draw_line(d_pos, host_local, Color(1, 1, 1, 0.1 * alpha_mult), 1.5/zoom)
			draw_circle(host_local, 4.0/zoom, Color(1, 1, 1, 0.3 * alpha_mult))

		if not sm: continue
		
		var cd = sm.get_perk_cooldown_ratio(icon.perk_name) as float
		var energy_cost = sm.get_perk_energy_cost(icon.perk_name)
		var has_enough_energy := sm.perk_energy >= energy_cost
		var is_ready = (cd <= 0.0 and has_enough_energy)
		
		_draw_button(d_pos, r, icon.perk_name, is_ready, cd, has_enough_energy, zoom, alpha_mult)

func _draw_button(pos: Vector2, r: float, perk: String, is_ready: bool, cd: float, has_enough_energy: bool, zoom: float, alpha: float = 1.0) -> void:
	var col = Color(0.2, 0.8, 1.0) # Синий для щита
	if perk == "virus":
		col = Color(0.9, 0.1, 0.1) # Красный для вируса
	elif perk == "rapid_fire":
		col = Color(1.0, 0.5, 0.1) # Оранжевый для скорострельности
	elif perk == "speed":
		col = Color(1.0, 0.9, 0.1) # Желтоватый для спринта
	else:
		col = Color(0.0, 1.0, 0.5) # Зеленый (дефолт)

	if cd <= 0.0 and not has_enough_energy:
		col = Color(0.14, 0.14, 0.17)
	
	# Тень/Обводка с учётом прозрачности
	draw_circle(pos, r * 1.25, Color(0, 0, 0, 0.7 * alpha))
	
	if is_ready:
		var pulse = (sin(Time.get_ticks_msec() / 180.0) + 1.0) * 0.5
		var glow = col
		glow.a = (0.2 + pulse * 0.4) * alpha
		draw_arc(pos, r + 5.0/zoom, 0, TAU, 32, glow, 4.0/zoom, true)
	elif cd > 0.0:
		var cd_col = Color(1, 1, 1, 0.5 * alpha)
		draw_arc(pos, r + 3.0/zoom, -PI/2, -PI/2 + TAU * cd, 32, cd_col, 5.0/zoom, true)

	var icon_col = col
	if cd > 0.0:
		icon_col = COOLDOWN_ICON_COLOR
	elif not has_enough_energy:
		icon_col = NO_ENERGY_ICON_COLOR
	icon_col.a *= alpha
	_draw_symbol(pos, r * 0.6, perk, icon_col, zoom)

func _draw_symbol(pos: Vector2, s: float, type: String, col: Color, zoom: float) -> void:
	if type == "shield":
		if SHIELD_ICON != null:
			var shield_half_size := s * SHIELD_ICON_SCALE
			var icon_rect := Rect2(pos - Vector2(shield_half_size, shield_half_size), Vector2(shield_half_size * 2.0, shield_half_size * 2.0))
			draw_texture_rect(SHIELD_ICON, icon_rect, false, col)
	elif type == "virus":
		# Символ вируса: Череп (упрощенный)
		# 1. Основной круг головы
		draw_circle(pos + Vector2(0, -s*0.2), s*0.7, col)
		# 2. Челюсть
		var jaw = PackedVector2Array([
			pos + Vector2(-s*0.4, s*0.2), pos + Vector2(s*0.4, s*0.2),
			pos + Vector2(s*0.3, s*0.8), pos + Vector2(-s*0.3, s*0.8)
		])
		draw_colored_polygon(jaw, col)
		# 3. Глазницы (фоновый цвет или прозрачный)
		var bg = Color(0, 0, 0, 0.4)
		draw_circle(pos + Vector2(-s*0.3, -s*0.2), s*0.15, bg)
		draw_circle(pos + Vector2(s*0.3, -s*0.2), s*0.15, bg)
		# 4. Зубы (линии)
		draw_line(pos + Vector2(-s*0.1, s*0.4), pos + Vector2(-s*0.1, s*0.7), bg, 1.5/zoom)
		draw_line(pos + Vector2(s*0.1, s*0.4), pos + Vector2(s*0.1, s*0.7), bg, 1.5/zoom)
	elif type == "rapid_fire":
		if RAPID_FIRE_ICON != null:
			var rapid_fire_half_size := s * RAPID_FIRE_ICON_SCALE
			var icon_rect := Rect2(pos - Vector2(rapid_fire_half_size, rapid_fire_half_size), Vector2(rapid_fire_half_size * 2.0, rapid_fire_half_size * 2.0))
			draw_texture_rect(RAPID_FIRE_ICON, icon_rect, false, col)
	else:
		if SPEED_ICON != null:
			var speed_half_size := s * SPEED_ICON_SCALE
			var icon_rect := Rect2(pos - Vector2(speed_half_size, speed_half_size), Vector2(speed_half_size * 2.0, speed_half_size * 2.0))
			draw_texture_rect(SPEED_ICON, icon_rect, false, col)

# --- Ввод ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT: return
		var m_pos = get_global_mouse_position()
		
		if mb.pressed:
			var icon = _get_icon_at(m_pos)
			if icon:
				_drag_icon = icon
				_is_dragging = false
				_drag_start_pos = m_pos
				get_viewport().set_input_as_handled()
		elif _drag_icon:
			var target = m_pos if _is_dragging else Vector2.ZERO
			_activate_perk(_drag_icon, target)
			_drag_icon = null
			_is_dragging = false
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _drag_icon:
		if _drag_start_pos.distance_to(get_global_mouse_position()) > DRAG_THRESHOLD:
			_is_dragging = true

func _get_icon_at(world_pos: Vector2) -> FloatingIcon:
	var camera = get_viewport().get_camera_2d()
	var hit_r = (ICON_SCREEN_RADIUS + 20.0) / (camera.zoom.x if camera else 1.0)
	for icon in icons:
		if icon.is_visible and icon.pos.distance_to(world_pos) < hit_r:
			return icon
	return null

func _activate_perk(icon: FloatingIcon, target: Vector2) -> void:
	var sm = get_tree().get_first_node_in_group("selection_manager")
	if sm and is_instance_valid(icon.host_cell):
		var prev = icon.host_cell.assigned_perk
		icon.host_cell.assigned_perk = icon.perk_name
		sm.try_activate_cell_perk(icon.host_cell, target)
		icon.host_cell.assigned_perk = prev
