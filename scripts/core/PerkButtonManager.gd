extends Node2D
class_name PerkButtonManager
## PerkButtonManager (Liquid & Stable Edition)
## Крупные кнопки с плавным перетеканием, защитой от дёрганья (Stability Timer)
## и жесткими коллизиями. Стратегия: Минимум статического UI.

# --- Константы Дизайна ---
const ICON_SCREEN_RADIUS: float = 24.0
const COLLISION_RADIUS: float = 56.0      # Для 4-х кнопок
const SEEK_INTERVAL: float = 0.05
const STABILITY_TIME: float = 0.5
const DRAG_THRESHOLD: float = 25.0
const HYSTERESIS_RATIO: float = 1.5
const DEAD_ZONE_DISTANCE: float = 80.0

# --- Физика (Liquid Motion) ---
const SPRING_STIFFNESS: float = 120.0
const SPRING_DAMPING: float = 18.0
const CENTER_LERP_SPEED: float = 4.0
const DRIFT_SPEED: float = 1.0
const DRIFT_STRENGTH: float = 8.0
const REPULSION_FORCE: float = 3500.0     # Усилили для 3-х кнопок

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
		for icon in icons: icon.host_cell = null
		return

	var valid_cells: Array[BaseCell] = []
	for c in cells_nodes: if c is BaseCell: valid_cells.append(c)
	
	# Сортировка по близости к центру
	valid_cells.sort_custom(func(a, b):
		return a.global_position.distance_squared_to(_colony_center) < b.global_position.distance_squared_to(_colony_center)
	)

	for i in range(icons.size()):
		var icon = icons[i]
		# Идеальный кандидат: 0-я клетка для Shield, 1-я для Speed (если есть)
		var ideal_candidate: BaseCell = valid_cells[0]
		if i == 1 and valid_cells.size() > 1:
			ideal_candidate = valid_cells[1]
		
		# Проверяем, занята ли идеальная клетка другой кнопкой
		var best_candidate = _find_best_available_cell(ideal_candidate, valid_cells, icon)
		_process_stable_assignment(icon, best_candidate, SEEK_INTERVAL)

func _find_best_available_cell(ideal: BaseCell, valid_cells: Array[BaseCell], current_icon: FloatingIcon) -> BaseCell:
	## Находит лучшую доступную клетку для иконки.
	## Если идеальная клетка занята другой кнопкой, выбирает следующую ближайшую.
	## Использует гистерезис: не переходит на новую клетку, если текущая близко.
	
	# Если идеальная клетка свободна - используем её
	var ideal_occupied = false
	for other_icon in icons:
		if other_icon != current_icon and other_icon.host_cell == ideal:
			ideal_occupied = true
			break
	
	if not ideal_occupied:
		return ideal
	
	# Если текущая клетка существует и близко к идеальной - остаемся на ней (гистерезис)
	if is_instance_valid(current_icon.host_cell):
		var dist_to_ideal = current_icon.host_cell.global_position.distance_squared_to(ideal.global_position)
		var dist_to_current = 0.0  # Расстояние от текущей к себе = 0
		var threshold = (COLLISION_RADIUS * HYSTERESIS_RATIO) * (COLLISION_RADIUS * HYSTERESIS_RATIO)
		
		if dist_to_ideal < threshold:
			return current_icon.host_cell
	
	# Ищем первую свободную клетку из отсортированного списка
	for cell in valid_cells:
		var is_occupied = false
		for other_icon in icons:
			if other_icon != current_icon and other_icon.host_cell == cell:
				is_occupied = true
				break
		
		if not is_occupied:
			return cell
	
	# Fallback: вернуть идеальную (на случай, если все клетки заняты)
	return ideal

func _process_stable_assignment(icon: FloatingIcon, ideal: BaseCell, dt: float) -> void:
	# 1. Если текущий хозяин битый или умер - меняем мгновенно
	if not is_instance_valid(icon.host_cell) or icon.host_cell.owner_type != 1:
		icon.host_cell = ideal
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
		# Если новый кандидат лучше уже 0.5 сек - переключаемся
		if icon.candidate_timer >= STABILITY_TIME:
			icon.host_cell = ideal
			icon.candidate_timer = 0.0

func _update_physics(delta: float) -> void:
	var camera = get_viewport().get_camera_2d()
	var zoom = camera.zoom.x if camera else 1.0
	var min_dist = (COLLISION_RADIUS * 2.0) / zoom
	var time = Time.get_ticks_msec() / 1000.0

	for i in range(icons.size()):
		var icon = icons[i]
		if not is_instance_valid(icon.host_cell): continue
		
		# А) Расположение (Offset)
		var target_offset = Vector2(0, -1)
		if icons.size() > 1 and icons[0].host_cell == icons[1].host_cell:
			target_offset = Vector2(-0.85 if i == 0 else 0.85, -0.6).normalized()
		
		icon.offset_current = icon.offset_current.lerp(target_offset, delta * 3.0)
		var target_pos = icon.host_cell.global_position + icon.offset_current * (icon.host_cell.radius * 1.4)
		
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
		
		# Г) Коллизии и Отталкивание
		for j in range(icons.size()):
			if i == j: continue
			var other = icons[j]
			if not is_instance_valid(other.host_cell): continue
			
			var push_vec = icon.pos - other.pos
			var dist = push_vec.length()
			
			# Мертвая зона: если слишком близко, увеличиваем отталкивание
			if dist < DEAD_ZONE_DISTANCE and dist > 0.1:
				# Усиленное отталкивание в мертвой зоне
				var dead_zone_force = REPULSION_FORCE * 3.0
				acc += push_vec.normalized() * dead_zone_force
			elif dist < min_dist and dist > 0.1:
				# Обычное отталкивание
				var ratio = 1.0 - (dist / min_dist)
				var force = ratio * ratio * REPULSION_FORCE * 2.0
				acc += push_vec.normalized() * force
				
				# Жесткая коллизия
				var hard_radius = (ICON_SCREEN_RADIUS * 2.2 / zoom)
				if dist < hard_radius:
					var overlap = hard_radius - dist
					icon.pos += push_vec.normalized() * overlap * 0.7
					other.pos -= push_vec.normalized() * overlap * 0.7

		# Интеграция
		icon.velocity += acc * delta
		icon.pos += icon.velocity * delta

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
		if not is_instance_valid(icon.host_cell) or icon.pos == Vector2.ZERO: continue
		
		var d_pos = to_local(icon.pos)
		
		# Трос (связь с клеткой)
		var host_local = to_local(icon.host_cell.global_position)
		draw_line(d_pos, host_local, Color(1, 1, 1, 0.1), 1.5/zoom)
		draw_circle(host_local, 4.0/zoom, Color(1, 1, 1, 0.3))

		if not sm: continue
		
		var cd = sm.get_perk_cooldown_ratio(icon.perk_name) as float
		var energy_cost = sm.get_perk_energy_cost(icon.perk_name)
		var is_ready = (cd <= 0.0 and sm.perk_energy >= energy_cost)
		
		_draw_button(d_pos, r, icon.perk_name, is_ready, cd, zoom)

func _draw_button(pos: Vector2, r: float, perk: String, is_ready: bool, cd: float, zoom: float) -> void:
	var col = Color(0.2, 0.8, 1.0) # Синий для щита
	if perk == "virus":
		col = Color(0.9, 0.1, 0.1) # Красный для вируса
	elif perk == "rapid_fire":
		col = Color(1.0, 0.5, 0.1) # Оранжевый для скорострельности
	elif perk == "speed":
		col = Color(1.0, 0.9, 0.1) # Желтоватый для спринта
	else:
		col = Color(0.0, 1.0, 0.5) # Зеленый (дефолт)
	
	# Тень/Обводка
	draw_circle(pos, r * 1.25, Color(0, 0, 0, 0.7))
	
	if is_ready:
		var pulse = (sin(Time.get_ticks_msec() / 180.0) + 1.0) * 0.5
		var glow = col
		glow.a = 0.2 + pulse * 0.4
		draw_arc(pos, r + 5.0/zoom, 0, TAU, 32, glow, 4.0/zoom, true)
	elif cd > 0.0:
		draw_arc(pos, r + 3.0/zoom, -PI/2, -PI/2 + TAU * cd, 32, Color(1, 1, 1, 0.5), 5.0/zoom, true)

	var icon_col = col if cd <= 0.0 else Color(0.5, 0.5, 0.5)
	_draw_symbol(pos, r * 0.6, perk, icon_col, zoom)

func _draw_symbol(pos: Vector2, s: float, type: String, col: Color, zoom: float) -> void:
	if type == "shield":
		var pts = PackedVector2Array([
			pos + Vector2(-s, -s*0.85), pos + Vector2(s, -s*0.85),
			pos + Vector2(s, s*0.25), pos + Vector2(0, s), pos + Vector2(-s, s*0.25)
		])
		draw_colored_polygon(pts, col)
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
		# Символ скорострельности: три стрелки/пули вверх
		for offset in [-s*0.6, 0, s*0.6]:
			var pts = PackedVector2Array([
				pos + Vector2(offset, -s*0.8), 
				pos + Vector2(offset + s*0.3, s*0.2), 
				pos + Vector2(offset - s*0.3, s*0.2)
			])
			draw_colored_polygon(pts, col)
		draw_rect(Rect2(pos.x - s*0.8, pos.y + s*0.3, s*1.6, s*0.2), col)
	else:
		# Молния
		var pts = PackedVector2Array([
			pos + Vector2(s*0.3, -s),      # Верхний правый угол
			pos + Vector2(-s*0.5, s*0.2), # Сгиб слева сверху
			pos + Vector2(s*0.1, s*0.2),  # Вход в центр справа
			pos + Vector2(-s*0.3, s),     # Нижний левый угол
			pos + Vector2(s*0.5, -s*0.2), # Сгиб справа снизу
			pos + Vector2(-s*0.1, -s*0.2) # Вход в центр слева
		])
		draw_colored_polygon(pts, col)

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
		if is_instance_valid(icon.host_cell) and icon.pos.distance_to(world_pos) < hit_r:
			return icon
	return null

func _activate_perk(icon: FloatingIcon, target: Vector2) -> void:
	var sm = get_tree().get_first_node_in_group("selection_manager")
	if sm and is_instance_valid(icon.host_cell):
		var prev = icon.host_cell.assigned_perk
		icon.host_cell.assigned_perk = icon.perk_name
		sm.try_activate_cell_perk(icon.host_cell, target)
		icon.host_cell.assigned_perk = prev
