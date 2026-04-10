extends Node2D
## Генератор мира. 4 фракции: Игрок (синий), Красные, Зелёные, Жёлтые.
## Каждый начинает с базой и несколькими клетками. Нейтральные разбросаны по карте.

@export var cell_scene: PackedScene = preload("res://scenes/base_cell/cell.tscn")
@export var map_size: Vector2 = Vector2(5000, 5000)
@export var num_neutral_cells: int = 50
var cell_speed_mult: float = 1.0

# Базовые "идеальные" позиции фракций (уменьшили до 0.6, чтобы точно попадали в кляксу)
const FACTION_BASES_NORMALIZED: Array = [
	{"type": 1, "pos": Vector2(-0.6, -0.6)},  # PLAYER (синий) — левый верх
	{"type": 2, "pos": Vector2( 0.6,  0.6)},  # ENEMY_RED  — правый низ
	{"type": 3, "pos": Vector2( 0.6, -0.6)},  # ENEMY_GREEN — правый верх
	{"type": 4, "pos": Vector2(-0.6,  0.6)},  # ENEMY_YELLOW — левый низ
]

@onready var bg_rect: ColorRect = $BackgroundLayer/ColorRect
@onready var camera: Camera2D = $Camera2D

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Переключение камер по тильде (~)
		if event.keycode == KEY_QUOTELEFT or event.keycode == KEY_SECTION:
			_toggle_free_camera()

func _toggle_free_camera() -> void:
	var dev_cam = get_node_or_null("DevFreeCamera")
	if not dev_cam: return
	
	if camera:
		if camera.enabled:
			# Переключаемся на Свободную камерu
			camera.enabled = false
			dev_cam.enabled = true
			dev_cam.make_current()
			dev_cam.global_position = camera.global_position # Переносим её к игроку для удобства старта
			print("DEV: Свободная камера ВКЛ")
		else:
			# Возвращаемся к Игроку
			dev_cam.enabled = false
			camera.enabled = true
			camera.make_current()
			print("DEV: Камера игрока ВКЛ")

func _process(_delta: float) -> void:
	if bg_rect and bg_rect.material and camera:
		# Если камера свободная (наблюдатель), отключаем параллакс, 
		# чтобы фон не "ездил" когда камера стоит у стены.
		if camera.is_forced_spectator() or get_tree().get_nodes_in_group("player_cells").is_empty():
			return
			
		# Передаем позицию камеры в шейдер для параллакса.
		bg_rect.material.set_shader_parameter("cam_offset", camera.global_position * 0.15)

func _ready() -> void:
	add_to_group("main")
	# 0. Получаем данные уровня
	var level_data := {"num_enemies": 1, "is_organic": false, "map_scale": 1.0, "num_neutrals": 40, "seed": 42}
	if has_node("/root/LevelManager"):
		level_data = get_node("/root/LevelManager").get_current_level_data()
	
	seed(level_data.seed)
	var neutral_rng := RandomNumberGenerator.new()
	neutral_rng.randomize()
	map_size *= level_data.map_scale
	num_neutral_cells = level_data.num_neutrals
	var hx = map_size.x / 2.0
	var hy = map_size.y / 2.0

	# 1. Скрываем старый ручной фон, чтобы было видно шейдер
	var manual_bg = get_node_or_null("BackgroundManual")
	if manual_bg: manual_bg.hide()

	# 2. Сбрасываем камеру в центр
	if camera:
		camera.global_position = Vector2.ZERO
	
	# 1. Генерируем границы и сохраняем полигон игровой зоны
	var playable_polygon_pts: PackedVector2Array = []
	if level_data.get("is_organic", false):
		playable_polygon_pts = _generate_borders_organic(level_data)
	else:
		_generate_borders() # Стандартный прямоугольник
		# Создаем прямоугольный полигон для проверки спавна
		# hx/hy уже объявлены выше
		playable_polygon_pts = PackedVector2Array([
			Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)
		])
	
	# Ограничиваем камеру по границам полигона
	if camera:
		var margin = 1000.0
		var rect = _get_polygon_bounds(playable_polygon_pts)
		camera.limit_left = int(rect.position.x - margin)
		camera.limit_right = int(rect.end.x + margin)
		camera.limit_top = int(rect.position.y - margin)
		camera.limit_bottom = int(rect.end.y + margin)
	
	# 2. Спавним базы фракций (ДЛЯ УРОВНЯ 2)
	if level_data.get("is_organic", false):
		# Возвращаем в САМЫЙ ЦЕНТР (0,0) после фикса физики
		var player_base_pos = Vector2.ZERO
		
		# СПАВНИМ НОВУЮ КЛЕТКУ ИГРОКА
		var player_cell = _spawn_cell(player_base_pos, BaseCell.OwnerType.PLAYER, 40.0)
		player_cell.assigned_perk = "speed"
		player_cell.z_index = 100 
		
		# --- СВОБОДНАЯ КАМЕРА ДЛЯ ТЕСТА (WASD) ---
		var dev_cam = Camera2D.new()
		dev_cam.name = "DevFreeCamera"
		dev_cam.set_script(load("res://scripts/core/DevFreeCamera.gd"))
		add_child(dev_cam)
		dev_cam.global_position = player_base_pos
		dev_cam.enabled = false 
		
		# По умолчанию на уровне 2 включаем обычную камеру ИГРОКА на новой позиции
		if camera:
			camera.enabled = true
			camera.global_position = player_base_pos
			camera._is_first_frame = true 
			
		print("DEBUG: Клетка игрока в САМОМ ЦЕНТРЕ (0,0)")
	else:
		var base_positions: Array = []
		var player_base_pos = _find_safe_pos(FACTION_BASES_NORMALIZED[0].pos * Vector2(hx, hy), playable_polygon_pts)
		base_positions.append(player_base_pos)
		
		var old_pc = get_node_or_null("PlayerCell")
		if old_pc: old_pc.queue_free()
		
		# --- ПРОВЕРКА ПРИЗРАКОВ ---
		print("--- Scene Tree after Purge ---")
		print_tree_pretty()
		print("------------------------------")
		
		var player_cell = get_node_or_null("PlayerCell")
		if player_cell:
			player_cell.show()
			player_cell.visible = true
			player_cell.position = player_base_pos
			player_cell.owner_type = BaseCell.OwnerType.PLAYER
			player_cell.stats.current_energy = 20
			player_cell.assigned_perk = "speed"
		
		# Помощники игрока
		_spawn_cell(player_base_pos + Vector2(160, 80), BaseCell.OwnerType.PLAYER, 15.0).assigned_perk = "shield"
		_spawn_cell(player_base_pos + Vector2(-160, 80), BaseCell.OwnerType.PLAYER, 12.0).assigned_perk = "rapid_fire"
		_spawn_cell(player_base_pos + Vector2(0, 160), BaseCell.OwnerType.PLAYER, 10.0).assigned_perk = "virus"

		# ИИ фракции (в зависимости от num_enemies)
		for i in range(1, level_data.num_enemies + 1):
			if i >= FACTION_BASES_NORMALIZED.size(): break
			var raw_pos = FACTION_BASES_NORMALIZED[i].pos * Vector2(hx, hy)
			var base_pos = _find_safe_pos(raw_pos, playable_polygon_pts)
			base_positions.append(base_pos)
			var faction_type = _int_to_owner_type(FACTION_BASES_NORMALIZED[i].type)
			_spawn_cell(base_pos, faction_type, 25)
			_spawn_cell(base_pos + Vector2(randf_range(-200, 200), randf_range(-200, 200)), faction_type, 15)
			_spawn_cell(base_pos + Vector2(randf_range(-200, 200), randf_range(-200, 200)), faction_type, 12)

		# 3. Нейтральные клетки
		var spawned := 0
		var attempts := 0
		var bounds = _get_polygon_bounds(playable_polygon_pts)
		while spawned < num_neutral_cells and attempts < num_neutral_cells * 10:
			attempts += 1
			var pos = Vector2(
				neutral_rng.randf_range(bounds.position.x + 200, bounds.end.x - 200),
				neutral_rng.randf_range(bounds.position.y + 200, bounds.end.y - 200)
			)
			if not Geometry2D.is_point_in_polygon(pos, playable_polygon_pts): continue
			var too_close := false
			for bpos in base_positions:
				if pos.distance_to(bpos) < 600: too_close = true; break
			if too_close: continue
			_spawn_cell(pos, BaseCell.OwnerType.NEUTRAL, neutral_rng.randf_range(2.0, 9.0))
			spawned += 1
		print("Мир: %d нейтральных, %d фракций." % [spawned, base_positions.size()])

	# 4. Инициализация меню паузы и мобильной UI кнопки
	var pause_menu = preload("res://scenes/ui/pause_menu.gd").new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu) 
	
	# Создаем отдельный CanvasLayer для кнопки паузы, чтобы она была 100% поверх всего (layer 115)
	var pause_hud = CanvasLayer.new()
	pause_hud.name = "PauseHUD"
	pause_hud.layer = 115
	add_child(pause_hud)
	
	var pause_btn = preload("res://scripts/ui/pause_button_mobile.gd").new()
	pause_btn.name = "MobilePauseButton"
	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_btn.pause_menu = pause_menu
	
	# Позиционирование: якорь в правый верхний угол, размеры 68x68, отступ от края 16px
	pause_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.offset_right = -16
	pause_btn.offset_top = 16
	pause_btn.offset_left = -16 - 68
	pause_btn.offset_bottom = 16 + 68
	
	pause_btn.pressed_btn.connect(pause_menu.toggle_pause)
	pause_hud.add_child(pause_btn)


func _spawn_cell(pos: Vector2, owner_type: BaseCell.OwnerType, energy: float) -> BaseCell:
	var cell = cell_scene.instantiate() as BaseCell
	cell.position = pos
	cell.owner_type = owner_type
	cell.stats.current_energy = energy
	add_child(cell)
	return cell

func _int_to_owner_type(i: int) -> BaseCell.OwnerType:
	match i:
		1: return BaseCell.OwnerType.PLAYER
		2: return BaseCell.OwnerType.ENEMY_RED
		3: return BaseCell.OwnerType.ENEMY_GREEN
		4: return BaseCell.OwnerType.ENEMY_YELLOW
	return BaseCell.OwnerType.NEUTRAL

func _generate_borders() -> void:
	var border_node = StaticBody2D.new()
	border_node.name = "BiologicalWalls"
	add_child(border_node)
	
	var hx = map_size.x / 2.0
	var hy = map_size.y / 2.0
	var thickness = 3000.0 # Увеличили толщину, чтобы точно не было дырок
	var segments = 100 # Увеличили точность для плавности
	
	# Шум для неровных органических краев
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.002 # Сделали шум "крупнее" (плавнее)
	
	var wall_color = Color(0.15, 0.15, 0.16) # Нейтральный темно-серый
	var edge_color = Color(0.35, 0.38, 0.4, 0.8) # Приглушенный серо-бежевый тон слизи
	
	# Анонимная функция для генерации одной стороны
	var _build_side = func(start: Vector2, end: Vector2, out_dir: Vector2, side_idx: int):
		var pts = PackedVector2Array()
		var line_pts = PackedVector2Array()
		var tangent = (end - start).normalized()
		
		# Генерируем точки вдоль отрезка с мягким шумом
		for i in range(segments + 1):
			var t = float(i) / segments
			var p = start.lerp(end, t)
			var n = noise.get_noise_2d(p.x + side_idx * 5000.0, p.y + side_idx * 5000.0)
			# Снизили амплитуду с 250 до 160 для плавности
			var edge_p = p + out_dir * (n * 160.0)
			
			pts.append(edge_p)
			line_pts.append(edge_p)
			
		# Добавляем "уши" за границы углов, чтобы перекрыть дырки (добавляем tangent * thickness)
		pts.append(end + out_dir * thickness + tangent * thickness)
		pts.append(start + out_dir * thickness - tangent * thickness)
		
		# 1. Физическая стенка
		var coll = CollisionPolygon2D.new()
		coll.polygon = pts
		border_node.add_child(coll)
		
		# 2. Визуальная масса
		var poly = Polygon2D.new()
		poly.polygon = pts
		poly.color = wall_color
		poly.z_index = -5
		border_node.add_child(poly)
		
		# 3. Биологическая мембрана (более плавная за счет segments и частоты шума)
		var line = Line2D.new()
		line.points = line_pts
		line.width = 50.0 # Чуть шире для мягкости
		line.default_color = edge_color
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.z_index = -3
		border_node.add_child(line)
		
		# Внутренний блик
		var hl_line = Line2D.new()
		hl_line.points = line_pts
		hl_line.width = 15.0
		hl_line.default_color = Color(0.6, 0.65, 0.7, 0.4) # Бежево-серый блик
		hl_line.joint_mode = Line2D.LINE_JOINT_ROUND
		hl_line.z_index = -2
		hl_line.position = -out_dir * 8.0
		border_node.add_child(hl_line)

	# Генерируем 4 стороны (Top, Right, Bottom, Left)
	# Normal: Vector2 наружу карты
	_build_side.call(Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(0, -1), 0)
	_build_side.call(Vector2(hx, -hy), Vector2(hx, hy), Vector2(1, 0), 1)
	_build_side.call(Vector2(hx, hy), Vector2(-hx, hy), Vector2(0, 1), 2)
	_build_side.call(Vector2(-hx, hy), Vector2(-hx, -hy), Vector2(-1, 0), 3)

func _generate_borders_organic(level_data: Dictionary) -> PackedVector2Array:
	var border_node = StaticBody2D.new()
	border_node.name = "BiologicalWalls"
	add_child(border_node)
	
	# 1. Генерируем основную "кляксу" (волнистый круг)
	var radius = min(map_size.x, map_size.y) / 2.0
	var noise = FastNoiseLite.new()
	noise.seed = level_data.seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = level_data.get("noise_freq", 0.001)
	
	var amp = level_data.get("noise_amp", 0.2)
	var segments = 120
	var blob_pts = PackedVector2Array()
	
	for i in range(segments):
		var angle = (TAU / segments) * i
		var dir = Vector2(cos(angle), sin(angle))
		var noise_val = noise.get_noise_2d(dir.x * 500.0, dir.y * 500.0)
		var p = dir * radius * (1.0 + noise_val * amp)
		blob_pts.append(p)
	
	# Гарантируем CCW для Geometry2D.clip (отверстие должно быть против часовой)
	if Geometry2D.is_polygon_clockwise(blob_pts): blob_pts.reverse()

	# 2. Создаем внешний прямоугольник (Plate)
	var outer_margin = 4000.0
	var rect_pts = PackedVector2Array([
		Vector2(-radius - outer_margin, -radius - outer_margin),
		Vector2( radius + outer_margin, -radius - outer_margin),
		Vector2( radius + outer_margin,  radius + outer_margin),
		Vector2(-radius - outer_margin,  radius + outer_margin)
	])
	# Внешний контур по часовой (CW)
	if not Geometry2D.is_polygon_clockwise(rect_pts): rect_pts.reverse()

	# 3. Вырезаем отверстие (Blob) из ОГРОМНОГО прямоугольника (Plate with Hole)
	var walls_polys = Geometry2D.clip_polygons(rect_pts, blob_pts)
	var edge_color = Color(0.5, 0.55, 0.6, 0.95) # Цвет бортика
	
	for poly_pts in walls_polys:
		# Физика (невидимая стена)
		var coll = CollisionPolygon2D.new()
		coll.polygon = poly_pts
		border_node.add_child(coll)
		
		# Визуал (УДАЛЕНО ПО ПРОСЬБЕ ПОЛЬЗОВАТЕЛЯ)

	# 4. Отрисовка "слизи" (мембраны) по краю кляксы
	var line = Line2D.new()
	var line_loop = blob_pts.duplicate()
	line_loop.append(line_loop[0]) # Замыкаем
	line.points = line_loop
	line.width = 60.0
	line.default_color = edge_color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = -3
	border_node.add_child(line)

	# Внутренний блик для объема
	var hl = Line2D.new()
	hl.points = line_loop
	hl.width = 18.0
	hl.default_color = Color(0.6, 0.65, 0.7, 0.35)
	hl.joint_mode = Line2D.LINE_JOINT_ROUND
	hl.z_index = -2
	# Сдвигаем блик чуть внутрь (на 10 пикселей к центру)
	hl.scale = Vector2(0.99, 0.99)
	border_node.add_child(hl)
	
	return blob_pts

func _find_safe_pos(target_pos: Vector2, polygon: PackedVector2Array) -> Vector2:
	# Если точка внутри — всё ок
	if Geometry2D.is_point_in_polygon(target_pos, polygon):
		return target_pos
	
	# Если нет — плавно тянем её к центру (0,0), пока не окажемся внутри
	var current = target_pos
	var center = Vector2.ZERO
	# Пытаемся 30 раз с большим шагом, чтобы точно попасть в центр
	for i in range(30):
		current = current.lerp(center, 0.2)
		if Geometry2D.is_point_in_polygon(current, polygon):
			# Даем еще небольшой отстут от стены к центру
			return current * 0.85
	return center

func _get_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.size() == 0: return Rect2()
	var min_p = polygon[0]; var max_p = polygon[0]
	for p in polygon:
		min_p.x = min(min_p.x, p.x); min_p.y = min(min_p.y, p.y)
		max_p.x = max(max_p.x, p.x); max_p.y = max(max_p.y, p.y)
	return Rect2(min_p, max_p - min_p)
