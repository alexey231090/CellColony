extends Node2D
## Генератор мира. 4 фракции: Игрок (синий), Красные, Зелёные, Жёлтые.
## Каждый начинает с базой и несколькими клетками. Нейтральные разбросаны по карте.

@export var cell_scene: PackedScene = preload("res://scenes/base_cell/cell.tscn")
@export var map_size: Vector2 = Vector2(5000, 5000)
@export var num_neutral_cells: int = 50

# Базовые позиции фракций по углам карты
const FACTION_BASES: Array = [
	{"type": 1, "pos": Vector2(-1800, -1800)},  # PLAYER (синий) — левый верх
	{"type": 2, "pos": Vector2( 1800,  1800)},  # ENEMY_RED  — правый низ
	{"type": 3, "pos": Vector2( 1800, -1800)},  # ENEMY_GREEN — правый верх
	{"type": 4, "pos": Vector2(-1800,  1800)},  # ENEMY_YELLOW — левый низ
]

@onready var bg_rect: ColorRect = $BackgroundLayer/ColorRect
@onready var camera: Camera2D = $Camera2D

func _process(_delta: float) -> void:
	if bg_rect and bg_rect.material and camera:
		# Передаем позицию камеры в шейдер для параллакса.
		# Сделали параллакс почти незаметным (0.15 вместо 0.7)
		bg_rect.material.set_shader_parameter("cam_offset", camera.global_position * 0.15)

func _ready() -> void:
	# 0. Генерируем биологические стенки (границы карты)
	_generate_borders()
	
	# Ограничиваем камеру, чтобы она не уплывала за границы карты
	if camera:
		camera.limit_left = -int(map_size.x / 2.0)
		camera.limit_right = int(map_size.x / 2.0)
		camera.limit_top = -int(map_size.y / 2.0)
		camera.limit_bottom = int(map_size.y / 2.0)
	
	# 1. Спавним игрока из сцены
	var player_cell = get_node_or_null("PlayerCell")
	var player_base = FACTION_BASES[0]
	if player_cell:
		player_cell.position = player_base.pos
		player_cell.owner_type = BaseCell.OwnerType.PLAYER
		player_cell.stats.current_energy = 20

	# 2. Спавним 3 AI-фракции с базой и стартовыми клетками
	for i in range(1, 4):
		var faction_data = FACTION_BASES[i]
		var faction_type = _int_to_owner_type(faction_data.type)
		var base_pos: Vector2 = faction_data.pos

		# Главная база
		_spawn_cell(base_pos, faction_type, 25)
		# 2 стартовые клетки рядом с базой
		_spawn_cell(base_pos + Vector2(randf_range(-200, 200), randf_range(-200, 200)), faction_type, 15)
		_spawn_cell(base_pos + Vector2(randf_range(-200, 200), randf_range(-200, 200)), faction_type, 12)

	# 3. Нейтральные клетки — разбросаны по всей карте
	var base_positions: Array = []
	for bd in FACTION_BASES:
		base_positions.append(bd.pos)

	var spawned := 0
	var attempts := 0
	while spawned < num_neutral_cells and attempts < num_neutral_cells * 5:
		attempts += 1
		var pos = Vector2(
			randf_range(-map_size.x / 2.0, map_size.x / 2.0),
			randf_range(-map_size.y / 2.0, map_size.y / 2.0)
		)
		# Не спавним прямо на базах
		var too_close := false
		for bpos in base_positions:
			if pos.distance_to(bpos) < 500:
				too_close = true
				break
		if too_close:
			continue
		_spawn_cell(pos, BaseCell.OwnerType.NEUTRAL, randf_range(3.0, 22.0))
		spawned += 1

	print("Мир: %d нейтральных, 4 фракции." % spawned)

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
	var thickness = 2000.0 # Толщина внешней "темной материи"
	var segments = 60 # Точность 
	
	# Шум для неровных органических краев
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.003
	
	var wall_color = Color(0.12, 0.08, 0.05) # Органический темно-коричневый цвет (ткань за стенкой)
	var edge_color = Color(0.1, 0.4, 0.25, 0.8) # Светящаяся органическая слизь
	
	# Анонимная функция для генерации одной стороны
	var _build_side = func(start: Vector2, end: Vector2, out_dir: Vector2, side_idx: int):
		var pts = PackedVector2Array()
		var line_pts = PackedVector2Array()
		
		# Генерируем 60 точек вдоль отрезка с шумом
		for i in range(segments + 1):
			var t = float(i) / segments
			var p = start.lerp(end, t)
			# Смещаем точку по нормали(направлению наружу) через функции шума
			# side_idx нужно чтоб шум на каждом крае был разным (оффсет)
			var n = noise.get_noise_2d(p.x + side_idx * 5000.0, p.y + side_idx * 5000.0)
			# Amplitude: до 200px неровностей
			var edge_p = p + out_dir * (n * 250.0)
			
			pts.append(edge_p)
			line_pts.append(edge_p)
			
		# Добавляем толщину снаружи для коллайдера/полигона(чтоб не было дырок)
		pts.append(end + out_dir * thickness)
		pts.append(start + out_dir * thickness)
		
		# 1. Физическая стенка (шоб не выползали)
		var coll = CollisionPolygon2D.new()
		coll.polygon = pts
		border_node.add_child(coll)
		
		# 2. Визуальная "темная масса" снаружи
		var poly = Polygon2D.new()
		poly.polygon = pts
		poly.color = wall_color
		poly.z_index = -5 # Самый низ, позади фона и клеток
		border_node.add_child(poly)
		
		# 3. Красивая неровная биологическая линия(мембрана)
		var line = Line2D.new()
		line.points = line_pts
		line.width = 45.0
		line.default_color = edge_color
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.z_index = -3 # Над фоном
		border_node.add_child(line)
		
		# Внутренний блик мембраны для объема (Juice)
		var hl_line = Line2D.new()
		hl_line.points = line_pts
		hl_line.width = 12.0
		hl_line.default_color = Color(0.5, 0.9, 0.6, 0.6)
		hl_line.joint_mode = Line2D.LINE_JOINT_ROUND
		hl_line.z_index = -2
		hl_line.position = -out_dir * 10.0 # Смещаем внутрь
		border_node.add_child(hl_line)

	# Генерируем 4 стороны (Top, Right, Bottom, Left)
	# Normal: Vector2 наружу карты
	_build_side.call(Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(0, -1), 0)
	_build_side.call(Vector2(hx, -hy), Vector2(hx, hy), Vector2(1, 0), 1)
	_build_side.call(Vector2(hx, hy), Vector2(-hx, hy), Vector2(0, 1), 2)
	_build_side.call(Vector2(-hx, hy), Vector2(-hx, -hy), Vector2(-1, 0), 3)
