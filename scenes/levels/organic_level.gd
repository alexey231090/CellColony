extends Node2D

const SPAWN_SLOTS_NORMALIZED: Array[Vector2] = [
	Vector2(-0.68, -0.68),
	Vector2(0.68, 0.68),
	Vector2(0.68, -0.68),
	Vector2(-0.68, 0.68),
]

const DEFAULT_ENEMY_TYPES: Array[int] = [
	BaseCell.OwnerType.ENEMY_RED,
	BaseCell.OwnerType.ENEMY_GREEN,
	BaseCell.OwnerType.ENEMY_YELLOW,
]

## ORGANIC LEVEL - CLEAN VERSION ##
# Этот уровень полностью отделен от классического main.tscn.
# Здесь используется только органическая генерация и шейдеры.

@export var cell_scene: PackedScene = preload("res://scenes/base_cell/cell.tscn")
@export var map_size: Vector2 = Vector2(4500, 4500)
var cell_speed_mult: float = 1.0
const DEFAULT_BORDER_SEGMENTS: int = 48
const DEFAULT_ISLAND_SEGMENTS: int = 18
const BG_SHADER_UPDATE_INTERVAL: float = 0.05
const BG_SHADER_MOVE_THRESHOLD_SQ: float = 4.0
const CHAPTER_2_PALETTE := {
	"outer_wall_color": Color(0.11, 0.20, 0.10, 1.0),
	"outer_edge_color": Color(0.61, 0.95, 0.32, 0.95),
	"outer_highlight_color": Color(0.88, 1.0, 0.72, 0.34),
	"island_wall_color": Color(0.12, 0.24, 0.11, 1.0),
	"island_edge_color": Color(0.48, 0.83, 0.28, 0.92),
	"island_highlight_color": Color(0.84, 0.98, 0.66, 0.26),
}
const CHAPTER_3_PALETTE := {
	"outer_wall_color": Color(0.24, 0.14, 0.06, 1.0),
	"outer_edge_color": Color(0.95, 0.67, 0.18, 0.95),
	"outer_highlight_color": Color(1.0, 0.9, 0.58, 0.34),
	"island_wall_color": Color(0.28, 0.16, 0.07, 1.0),
	"island_edge_color": Color(0.86, 0.56, 0.16, 0.92),
	"island_highlight_color": Color(1.0, 0.84, 0.46, 0.26),
}
const CHAPTER_4_PALETTE := {
	"outer_wall_color": Color(0.16, 0.09, 0.22, 1.0),
	"outer_edge_color": Color(0.78, 0.36, 0.96, 0.95),
	"outer_highlight_color": Color(0.96, 0.72, 1.0, 0.34),
	"island_wall_color": Color(0.18, 0.1, 0.25, 1.0),
	"island_edge_color": Color(0.66, 0.3, 0.86, 0.92),
	"island_highlight_color": Color(0.92, 0.64, 0.98, 0.26),
}
const CHAPTER_5_PALETTE := {
	"outer_wall_color": Color(0.25, 0.1, 0.1, 1.0),
	"outer_edge_color": Color(0.95, 0.46, 0.42, 0.95),
	"outer_highlight_color": Color(1.0, 0.78, 0.72, 0.34),
	"island_wall_color": Color(0.29, 0.12, 0.11, 1.0),
	"island_edge_color": Color(0.86, 0.38, 0.34, 0.92),
	"island_highlight_color": Color(0.98, 0.7, 0.62, 0.26),
}
const CHAPTER_6_PALETTE := {
	"outer_wall_color": Color(0.08, 0.11, 0.24, 1.0),
	"outer_edge_color": Color(0.34, 0.68, 1.0, 0.95),
	"outer_highlight_color": Color(0.82, 0.94, 1.0, 0.34),
	"island_wall_color": Color(0.09, 0.13, 0.28, 1.0),
	"island_edge_color": Color(0.28, 0.56, 0.92, 0.92),
	"island_highlight_color": Color(0.74, 0.9, 1.0, 0.26),
}

var playable_polygon_pts: PackedVector2Array = []
var island_collision_polygons: Array[PackedVector2Array] = []
var _bg_shader_timer: float = 0.0
var _last_bg_cam_offset: Vector2 = Vector2.INF
@onready var camera: Camera2D = $Camera2D
@onready var bg_rect: ColorRect = $BackgroundLayer/ColorRect

func _ready() -> void:
	add_to_group("main") # Важно для DevConsole и Mover
	
	# 0. Получаем данные (у нас они фиксированные для органики обычно)
	var level_data: Dictionary = {
		"seed": 202,
		"map_scale": 1.0,
		"shape_type": "blob",
		"shape_size": Vector2(3600, 2400),
		"shape_power": 4.0,
		"play_area_radius_mult": 1.0,
		"island_count": 4,
		"island_radius": 620.0,
		"island_noise_freq": 0.0025,
		"island_noise_amp": 0.2,
		"island_specs": [],
		"noise_freq": 0.0012,
		"noise_amp": 0.18,
	}
	if has_node("/root/LevelManager"):
		level_data = get_node("/root/LevelManager").get_current_level_data()
	
	seed(level_data.seed)
	var neutral_rng := RandomNumberGenerator.new()
	neutral_rng.randomize()
	map_size *= float(level_data.get("map_scale", 1.0))
	
	# 1. Генерация органических физических границ уровня
	playable_polygon_pts = _generate_borders_organic(level_data)
	var level_rect: Rect2 = _get_polygon_bounds(playable_polygon_pts)
	
	# 2. Настройка камеры
	if camera:
		var margin = 1000.0
		camera.limit_left = int(level_rect.position.x - margin)
		camera.limit_right = int(level_rect.end.x + margin)
		camera.limit_top = int(level_rect.position.y - margin)
		camera.limit_bottom = int(level_rect.end.y + margin)
		camera.global_position = Vector2.ZERO
	
	# 3. Спавним игрока и врагов по конфигу уровня
	var base_positions: Array[Vector2] = []
	var player_spawn_slot: int = clampi(int(level_data.get("player_spawn_slot", 0)), 0, SPAWN_SLOTS_NORMALIZED.size() - 1)
	var enemy_spawn_slots: Array = level_data.get("enemy_spawn_slots", [1, 2, 3])
	var player_base_pos: Vector2 = _find_safe_pos(
		SPAWN_SLOTS_NORMALIZED[player_spawn_slot] * Vector2(level_rect.size.x * 0.5, level_rect.size.y * 0.5),
		playable_polygon_pts
	)
	base_positions.append(player_base_pos)
	var player_cell = _spawn_cell(player_base_pos, BaseCell.OwnerType.PLAYER, 40.0)
	player_cell.assigned_perk = "speed"
	player_cell.z_index = 100
	var difficulty: String = String(level_data.get("selected_difficulty", "easy"))
	var enemy_start_cell_count: int = _get_enemy_start_cell_count(difficulty)
	var configured_enemy_types: Array = level_data.get("enemy_types", [])
	
	for i in range(1, int(level_data.get("num_enemies", 1)) + 1):
		if i > DEFAULT_ENEMY_TYPES.size():
			break
		var spawn_slot_index: int = i
		if i - 1 < enemy_spawn_slots.size():
			spawn_slot_index = clampi(int(enemy_spawn_slots[i - 1]), 0, SPAWN_SLOTS_NORMALIZED.size() - 1)
		var raw_pos: Vector2 = SPAWN_SLOTS_NORMALIZED[spawn_slot_index] * Vector2(level_rect.size.x * 0.5, level_rect.size.y * 0.5)
		var enemy_pos: Vector2 = _find_safe_pos(raw_pos, playable_polygon_pts)
		base_positions.append(enemy_pos)
		var enemy_type: int = DEFAULT_ENEMY_TYPES[i - 1]
		if i - 1 < configured_enemy_types.size():
			enemy_type = int(configured_enemy_types[i - 1])
		elif i == 1:
			enemy_type = int(level_data.get("enemy_type", enemy_type))
		var enemy_spawn_energies: Array[float] = [28.0, 16.0, 12.0]
		for spawn_index in range(enemy_start_cell_count):
			var spawn_pos := enemy_pos
			if spawn_index > 0:
				spawn_pos += Vector2(randf_range(-140, 140), randf_range(-140, 140))
			_spawn_cell(spawn_pos, enemy_type, enemy_spawn_energies[spawn_index])
	
	_spawn_neutral_cells(int(level_data.get("num_neutrals", 18)), base_positions, neutral_rng)
	
	# Сбрасываем камеру, чтобы она сразу прыгнула на игрока
	if camera:
		camera.global_position = player_base_pos
		camera._is_first_frame = true
	
	# 4. Свободная камера
	_setup_dev_camera()
	_setup_pause_ui()
	
	# 5. Применяем профиль сложности ИИ (deferred, чтобы AIFactionManager был готов)
	call_deferred("_apply_ai_difficulty", difficulty)
	
	print("--- ORGANIC LEVEL LOADED: Чистое пространство (0,0), сложность: %s ---" % difficulty)

func _get_enemy_start_cell_count(difficulty: String) -> int:
	match difficulty:
		"medium":
			return 2
		"hard":
			return 3
		_:
			return 1

func _process(delta: float) -> void:
	# Это не острова, а фоновый шейдер. Обновляем его реже, чтобы не дергать материал каждый кадр.
	if bg_rect and camera and bg_rect.material:
		_bg_shader_timer += delta
		var cam_offset: Vector2 = camera.global_position * 0.15
		if _bg_shader_timer >= BG_SHADER_UPDATE_INTERVAL or _last_bg_cam_offset == Vector2.INF or _last_bg_cam_offset.distance_squared_to(cam_offset) >= BG_SHADER_MOVE_THRESHOLD_SQ:
			_bg_shader_timer = 0.0
			_last_bg_cam_offset = cam_offset
			bg_rect.material.set_shader_parameter("cam_offset", cam_offset)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_QUOTELEFT:
			_toggle_free_camera()

func _spawn_cell(pos: Vector2, owner_type: int, energy: float):
	var cell: BaseCell = cell_scene.instantiate() as BaseCell
	cell.position = pos
	cell.owner_type = owner_type
	cell.stats.current_energy = energy
	
	# ВАЖНО: Добавляем в группы, чтобы SelectionManager и Camera его видели
	cell.add_to_group("cells")
	if owner_type == 1: # PLAYER
		cell.add_to_group("player_cells")
		cell.name = "PlayerCell"
	
	add_child(cell)
	
	return cell

func _spawn_neutral_cells(count: int, base_positions: Array[Vector2], rng: RandomNumberGenerator) -> void:
	var spawned: int = 0
	var attempts: int = 0
	var bounds: Rect2 = _get_polygon_bounds(playable_polygon_pts)
	while spawned < count and attempts < count * 15:
		attempts += 1
		var pos: Vector2 = Vector2(
			rng.randf_range(bounds.position.x + 200.0, bounds.end.x - 200.0),
			rng.randf_range(bounds.position.y + 200.0, bounds.end.y - 200.0)
		)
		if not Geometry2D.is_point_in_polygon(pos, playable_polygon_pts):
			continue
		if _is_inside_any_island(pos):
			continue
		var too_close: bool = false
		for base_pos in base_positions:
			if pos.distance_to(base_pos) < 700.0:
				too_close = true
				break
		if too_close:
			continue
		_spawn_cell(pos, BaseCell.OwnerType.NEUTRAL, rng.randf_range(2.0, 9.0))
		spawned += 1

func _setup_dev_camera() -> void:
	var dev_cam = Camera2D.new()
	dev_cam.name = "DevFreeCamera"
	dev_cam.set_script(load("res://scripts/core/DevFreeCamera.gd"))
	add_child(dev_cam)
	dev_cam.global_position = Vector2.ZERO
	dev_cam.enabled = false

func _toggle_free_camera() -> void:
	var dev_cam = get_node_or_null("DevFreeCamera")
	if not dev_cam: return
	
	if camera.enabled:
		dev_cam.global_position = camera.global_position
		camera.enabled = false
		dev_cam.enabled = true
		dev_cam.make_current()
	else:
		dev_cam.enabled = false
		camera.enabled = true
		camera.make_current()

func _setup_pause_ui() -> void:
	var pause_menu = preload("res://scenes/ui/pause_menu.gd").new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	
	var pause_hud: CanvasLayer = CanvasLayer.new()
	pause_hud.name = "PauseHUD"
	pause_hud.layer = 115
	add_child(pause_hud)
	
	var pause_btn = preload("res://scripts/ui/pause_button_mobile.gd").new()
	pause_btn.name = "MobilePauseButton"
	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_btn.pause_menu = pause_menu
	pause_btn.custom_minimum_size = Vector2(68, 68)
	
	# Явно задаем размеры и привязку, чтобы кнопка не схлопывалась до нуля.
	pause_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.offset_right = -16
	pause_btn.offset_top = 16
	pause_btn.offset_left = -16 - 68
	pause_btn.offset_bottom = 16 + 68
	
	pause_btn.pressed_btn.connect(pause_menu.toggle_pause)
	pause_hud.add_child(pause_btn)

func _generate_borders_organic(level_data: Dictionary) -> PackedVector2Array:
	var border_node: StaticBody2D = StaticBody2D.new()
	border_node.name = "BiologicalWalls"
	add_child(border_node)
	var palette := _get_level_palette(level_data)
	
	var radius_mult: float = float(level_data.get("play_area_radius_mult", 1.0))
	var shape_type: String = String(level_data.get("shape_type", "blob"))
	var shape_size: Vector2 = level_data.get("shape_size", Vector2(map_size.x, map_size.y))
	var radius: float = minf(map_size.x, map_size.y) / 2.0 * radius_mult
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = int(level_data.get("seed", randi()))
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = float(level_data.get("noise_freq", 0.0012))
	
	var amp: float = float(level_data.get("noise_amp", 0.18))
	var segments: int = max(24, int(level_data.get("border_segments", DEFAULT_BORDER_SEGMENTS)))
	var blob_pts: PackedVector2Array = PackedVector2Array()
	var outer_wall_color: Color = palette.outer_wall_color
	var outer_edge_color: Color = palette.outer_edge_color
	var outer_highlight_color: Color = palette.outer_highlight_color
	var island_wall_color: Color = palette.island_wall_color
	var island_edge_color: Color = palette.island_edge_color
	var island_highlight_color: Color = palette.island_highlight_color
	var outer_line_width: float = 110.0
	var outer_highlight_width: float = 42.0
	var island_line_width: float = 48.0
	var island_highlight_width: float = 14.0
	var visual_thickness: float = 3000.0
	var collision_thickness: float = 3000.0
	var collision_inset: float = 90.0
	var segment_overlap: float = 160.0
	var center: Vector2 = Vector2.ZERO
	
	if shape_type == "rounded_box":
		blob_pts = _build_rounded_box_polygon(
			Vector2.ZERO,
			shape_size,
			float(level_data.get("shape_power", 4.0)),
			segments,
			int(level_data.get("seed", 0)),
			float(level_data.get("noise_freq", 0.0012)),
			amp
		)
	else:
		for i in range(segments):
			var angle: float = (TAU / float(segments)) * float(i)
			var dir: Vector2 = Vector2(cos(angle), sin(angle))
			var noise_val: float = noise.get_noise_2d(dir.x * 500.0, dir.y * 500.0)
			var p: Vector2 = dir * radius * (1.0 + noise_val * amp)
			blob_pts.append(p)
	
	for p in blob_pts:
		center += p
	
	# Контур игровой зоны должен быть CCW, чтобы корректно вырезать его из внешней плиты.
	if Geometry2D.is_polygon_clockwise(blob_pts):
		blob_pts.reverse()
	center /= float(max(1, blob_pts.size()))
	
	for i in range(blob_pts.size()):
		var p0: Vector2 = blob_pts[i]
		var p1: Vector2 = blob_pts[(i + 1) % blob_pts.size()]
		var edge: Vector2 = p1 - p0
		if edge.length_squared() <= 0.001:
			continue
		
		var tangent: Vector2 = edge.normalized()
		var outward: Vector2 = Vector2(edge.y, -edge.x).normalized()
		var mid: Vector2 = (p0 + p1) * 0.5
		if outward.dot(mid - center) < 0.0:
			outward = -outward
		
		# Удлиняем сегменты вдоль касательной и слегка перекрываем соседние,
		# чтобы не было щелей между отдельными кусками стены.
		var ext_p0: Vector2 = p0 - tangent * segment_overlap
		var ext_p1: Vector2 = p1 + tangent * segment_overlap
		var coll_inner_p0: Vector2 = p0 - outward * collision_inset - tangent * segment_overlap
		var coll_inner_p1: Vector2 = p1 - outward * collision_inset + tangent * segment_overlap
		
		var visual_poly_pts: PackedVector2Array = PackedVector2Array([
			ext_p0,
			ext_p1,
			ext_p1 + outward * visual_thickness,
			ext_p0 + outward * visual_thickness,
		])
		var visual_poly: Polygon2D = Polygon2D.new()
		visual_poly.polygon = visual_poly_pts
		visual_poly.color = outer_wall_color
		visual_poly.z_index = -5
		border_node.add_child(visual_poly)
		
		var coll_poly_pts: PackedVector2Array = PackedVector2Array([
			coll_inner_p0,
			coll_inner_p1,
			ext_p1 + outward * collision_thickness,
			ext_p0 + outward * collision_thickness,
		])
		var coll: CollisionPolygon2D = CollisionPolygon2D.new()
		coll.polygon = coll_poly_pts
		border_node.add_child(coll)
	
	var line_loop: PackedVector2Array = blob_pts.duplicate()
	line_loop.append(line_loop[0])
	
	var line: Line2D = Line2D.new()
	line.name = "OrganicBorderVisual"
	line.points = line_loop
	line.width = outer_line_width
	line.default_color = outer_edge_color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = -3
	border_node.add_child(line)
	
	var hl: Line2D = Line2D.new()
	hl.points = line_loop
	hl.width = outer_highlight_width
	hl.default_color = outer_highlight_color
	hl.joint_mode = Line2D.LINE_JOINT_ROUND
	hl.z_index = -2
	border_node.add_child(hl)
	
	if bool(level_data.get("has_islands", false)):
		_generate_organic_islands(
			border_node,
			level_data,
			center,
			radius,
			island_wall_color,
			island_edge_color,
			island_highlight_color,
			island_line_width,
			island_highlight_width
		)
	
	return blob_pts

func _get_level_palette(level_data: Dictionary) -> Dictionary:
	var chapter: int = int(level_data.get("chapter", 1))
	var default_palette := {
		"outer_wall_color": Color(0.08, 0.19, 0.22, 1.0),
		"outer_edge_color": Color(0.33, 0.82, 0.88, 0.95),
		"outer_highlight_color": Color(0.82, 0.97, 1.0, 0.34),
		"island_wall_color": Color(0.09, 0.22, 0.25, 1.0),
		"island_edge_color": Color(0.26, 0.72, 0.78, 0.92),
		"island_highlight_color": Color(0.78, 0.95, 1.0, 0.26),
	}

	match chapter:
		2:
			return CHAPTER_2_PALETTE
		3:
			return CHAPTER_3_PALETTE
		4:
			return CHAPTER_4_PALETTE
		5:
			return CHAPTER_5_PALETTE
		6:
			return CHAPTER_6_PALETTE
		_:
			return default_palette

func _generate_organic_islands(border_node: StaticBody2D, level_data: Dictionary, center: Vector2, outer_radius: float, wall_color: Color, edge_color: Color, highlight_color: Color, line_width: float, highlight_width: float) -> void:
	island_collision_polygons.clear()
	var island_count: int = int(level_data.get("island_count", 4))
	var island_radius: float = float(level_data.get("island_radius", 620.0))
	var island_noise_freq: float = float(level_data.get("island_noise_freq", 0.0025))
	var island_noise_amp: float = float(level_data.get("island_noise_amp", 0.2))
	var island_specs: Array = level_data.get("island_specs", [])
	
	for i in range(island_count):
		var spec: Dictionary = island_specs[i] if i < island_specs.size() else {}
		var center_ratio: Vector2 = spec.get("center_ratio", Vector2.ZERO)
		var island_center: Vector2 = center + center_ratio * outer_radius
		var island_radius_x: float = float(spec.get("radius_x", island_radius))
		var island_radius_y: float = float(spec.get("radius_y", island_radius * 0.65))
		var island_rotation: float = float(spec.get("rotation", 0.0))
		var island_segments: int = max(12, int(spec.get("segments", int(level_data.get("island_segments", DEFAULT_ISLAND_SEGMENTS)))))
		var island_local_amp: float = float(spec.get("noise_amp", island_noise_amp))
		var island_pts: PackedVector2Array = _build_organic_blob_polygon(
			island_center,
			island_radius_x,
			island_radius_y,
			island_rotation,
			island_segments,
			int(level_data.get("seed", 0)) + 1000 + i * 97,
			island_noise_freq,
			island_local_amp
		)
		_add_organic_island(border_node, island_pts, wall_color, edge_color, highlight_color, line_width, highlight_width)

func _build_rounded_box_polygon(center: Vector2, size: Vector2, shape_power: float, segments: int, noise_seed: int, noise_freq: float, noise_amp: float) -> PackedVector2Array:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_freq
	
	var pts: PackedVector2Array = PackedVector2Array()
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var exponent: float = maxf(0.1, 2.0 / maxf(0.1, shape_power))
	for i in range(segments):
		var angle: float = (TAU / float(segments)) * float(i)
		var c: float = cos(angle)
		var s: float = sin(angle)
		var base: Vector2 = Vector2(
			signf(c) * pow(absf(c), exponent) * hx,
			signf(s) * pow(absf(s), exponent) * hy
		)
		var noise_val: float = noise.get_noise_2d(base.x * 0.35, base.y * 0.35)
		pts.append(center + base * (1.0 + noise_val * noise_amp))
	if Geometry2D.is_polygon_clockwise(pts):
		pts.reverse()
	return pts

func _build_organic_blob_polygon(center: Vector2, radius_x: float, radius_y: float, rotation: float, segments: int, noise_seed: int, noise_freq: float, noise_amp: float) -> PackedVector2Array:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_freq
	
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var angle: float = (TAU / float(segments)) * float(i)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var local: Vector2 = Vector2(dir.x * radius_x, dir.y * radius_y).rotated(rotation)
		var noise_val: float = noise.get_noise_2d(dir.x * 400.0, dir.y * 400.0)
		var p: Vector2 = center + local * (1.0 + noise_val * noise_amp)
		pts.append(p)
	
	if Geometry2D.is_polygon_clockwise(pts):
		pts.reverse()
	return pts

func _add_organic_island(border_node: StaticBody2D, island_pts: PackedVector2Array, wall_color: Color, edge_color: Color, highlight_color: Color, line_width: float, highlight_width: float) -> void:
	var fill_poly: Polygon2D = Polygon2D.new()
	fill_poly.polygon = island_pts
	fill_poly.color = wall_color
	fill_poly.z_index = -5
	border_node.add_child(fill_poly)
	
	var expanded_island_pts: PackedVector2Array = _expand_polygon_from_center(island_pts, 80.0)
	island_collision_polygons.append(expanded_island_pts)
	var coll: CollisionPolygon2D = CollisionPolygon2D.new()
	coll.polygon = expanded_island_pts
	coll.set_meta("is_island", true)
	border_node.add_child(coll)
	
	var loop_pts: PackedVector2Array = island_pts.duplicate()
	loop_pts.append(loop_pts[0])
	
	var line: Line2D = Line2D.new()
	line.points = loop_pts
	line.width = line_width
	line.default_color = edge_color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = -3
	border_node.add_child(line)
	
	var hl: Line2D = Line2D.new()
	hl.points = loop_pts
	hl.width = highlight_width
	hl.default_color = highlight_color
	hl.joint_mode = Line2D.LINE_JOINT_ROUND
	hl.z_index = -2
	border_node.add_child(hl)

func _expand_polygon_from_center(polygon: PackedVector2Array, amount: float) -> PackedVector2Array:
	if polygon.is_empty():
		return polygon
	var center: Vector2 = Vector2.ZERO
	for p in polygon:
		center += p
	center /= float(polygon.size())
	var expanded: PackedVector2Array = PackedVector2Array()
	for p in polygon:
		var dir: Vector2 = p - center
		var len: float = dir.length()
		if len <= 0.001:
			expanded.append(p)
		else:
			expanded.append(center + dir.normalized() * (len + amount))
	return expanded

func _is_inside_any_island(pos: Vector2) -> bool:
	for island_polygon in island_collision_polygons:
		if Geometry2D.is_point_in_polygon(pos, island_polygon):
			return true
	return false

func _find_safe_pos(target_pos: Vector2, polygon: PackedVector2Array) -> Vector2:
	if Geometry2D.is_point_in_polygon(target_pos, polygon) and not _is_inside_any_island(target_pos):
		return target_pos
	var current: Vector2 = target_pos
	var center: Vector2 = Vector2.ZERO
	for i in range(40):
		current = current.lerp(center, 0.18)
		if Geometry2D.is_point_in_polygon(current, polygon) and not _is_inside_any_island(current):
			return current * 0.92
	return center

func _get_polygon_bounds(pts: PackedVector2Array) -> Rect2:
	if pts.is_empty(): return Rect2(-1000, -1000, 2000, 2000)
	var min_v = pts[0]
	var max_v = pts[0]
	for p in pts:
		min_v.x = min(min_v.x, p.x)
		min_v.y = min(min_v.y, p.y)
		max_v.x = max(max_v.x, p.x)
		max_v.y = max(max_v.y, p.y)
	return Rect2(min_v, max_v - min_v)

## Применяет профиль сложности ко всем AIFactionManager в сцене.
func _apply_ai_difficulty(difficulty: String) -> void:
	var profile: Dictionary = _build_difficulty_profile(difficulty)
	var managers = get_tree().get_nodes_in_group("ai_faction_managers")
	for manager in managers:
		if manager is AIFactionManager:
			manager.apply_difficulty_profile(profile)
	print("[Level] Профиль сложности '%s' применён к %d ИИ-менеджерам" % [difficulty, managers.size()])

## Строит словарь-профиль параметров ИИ для выбранной сложности.
func _build_difficulty_profile(difficulty: String) -> Dictionary:
	match difficulty:
		"easy":
			return {
				"decision_interval": 5.5,
				"perk_delay_mult": 3.0,
				"min_energy_ratio_for_war": 0.85,
				"score_distance_scale": 900.0,
				"goal_lock_time": 8.0,
				"enemy_notice_range": 1000.0,
				"shield_hp_threshold": 0.45,
				"shield_min_max_energy": 20.0,
				"shield_player_outnumber_ratio": 1.8,
				"virus_min_enemy_count": 3,
				"rapid_fire_hp_target_threshold": 0.4,
				"speed_boost_distance_threshold": 1200.0,
			}
		"hard":
			return {
				"decision_interval": 1.2,
				"perk_delay_mult": 1.0,
				"min_energy_ratio_for_war": 0.65,
				"score_distance_scale": 3500.0,
				"goal_lock_time": 3.0,
				"enemy_notice_range": 3500.0,
				"shield_hp_threshold": 0.35,
				"shield_min_max_energy": 20.0,
				"virus_min_enemy_count": 2,
				"rapid_fire_hp_target_threshold": 0.55,
				"speed_boost_distance_threshold": 900.0,
			}
		_: # medium (по умолчанию) — текущее поведение + стартовый кулдаун перков
			return {
				"decision_interval": 2.5,
				"perk_delay_mult": 1.5,
				"min_energy_ratio_for_war": 0.55,
				"score_distance_scale": 2200.0,
				# Как на easy, но без общей "тупизны": ИИ дольше добивает выбранную цель,
				# вместо постоянного перескока между жирными нейтралками.
				"goal_lock_time": 8.0,
				"enemy_notice_range": 2000.0,
				"shield_hp_threshold": 0.45,
				"shield_min_max_energy": 20.0,
				"virus_min_enemy_count": 3,
				"rapid_fire_hp_target_threshold": 0.4,
				"speed_boost_distance_threshold": 1200.0,
			}
