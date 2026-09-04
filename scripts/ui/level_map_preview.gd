extends Control
class_name LevelMapPreview

const SPAWN_SLOTS_NORMALIZED: Array[Vector2] = [
	Vector2(-0.68, -0.68),
	Vector2(0.68, 0.68),
	Vector2(0.68, -0.68),
	Vector2(-0.68, 0.68),
]

const DEFAULT_ENEMY_TYPES: Array[int] = [
	2, # ENEMY_RED
	3, # ENEMY_GREEN
	4, # ENEMY_YELLOW
]

const COLOR_PLAYER := Color(0.20, 0.80, 1.0, 1.0)
const COLOR_ENEMY_RED := Color(1.0, 0.32, 0.32, 1.0)
const COLOR_ENEMY_GREEN := Color(0.35, 0.95, 0.45, 1.0)
const COLOR_ENEMY_YELLOW := Color(1.0, 0.85, 0.25, 1.0)
const COLOR_NEUTRAL := Color(0.85, 0.90, 0.95, 0.45)

var level_data: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func setup(data: Dictionary) -> void:
	level_data = data
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	if level_data.is_empty():
		return

	var rect_size := size
	if rect_size.x <= 2.0 or rect_size.y <= 2.0:
		return

	var shape_size: Vector2 = level_data.get("shape_size", Vector2(7200, 5000))
	var total_world_w: float = maxf(100.0, shape_size.x)
	var total_world_h: float = maxf(100.0, shape_size.y)

	var pad: float = 3.0
	var avail_w: float = maxf(10.0, rect_size.x - pad * 2.0)
	var avail_h: float = maxf(10.0, rect_size.y - pad * 2.0)
	var scale_factor: float = minf(avail_w / total_world_w, avail_h / total_world_h)
	var center_offset: Vector2 = rect_size * 0.5

	# 1. Построение контура арены
	var segments: int = 28
	var shape_power: float = float(level_data.get("shape_power", 4.6))
	var exponent: float = maxf(0.1, 2.0 / maxf(0.1, shape_power))
	var hx: float = shape_size.x * 0.5
	var hy: float = shape_size.y * 0.5
	var arena_pts := PackedVector2Array()

	for i in range(segments):
		var angle: float = (TAU / float(segments)) * float(i)
		var c: float = cos(angle)
		var s: float = sin(angle)
		var base := Vector2(
			signf(c) * pow(absf(c), exponent) * hx,
			signf(s) * pow(absf(s), exponent) * hy
		)
		var screen_pt: Vector2 = center_offset + base * scale_factor
		arena_pts.append(screen_pt)

	var chapter: int = int(level_data.get("chapter", 1))
	var ch_colors := _get_chapter_colors(chapter)

	if arena_pts.size() >= 3:
		# Фон арены
		draw_colored_polygon(arena_pts, Color(0.06, 0.11, 0.16, 0.85))
		
		# Обводка арены с учетом палитры главы
		var arena_loop := arena_pts.duplicate()
		arena_loop.append(arena_loop[0])
		draw_polyline(arena_loop, ch_colors.border, 1.5, true)
		draw_polyline(arena_loop, ch_colors.highlight, 0.8, true)

	# 2. Отрисовка островов
	if bool(level_data.get("has_islands", false)):
		var island_specs: Array = level_data.get("island_specs", [])
		var island_count: int = int(level_data.get("island_count", island_specs.size()))
		var island_radius: float = float(level_data.get("island_radius", 300.0))
		var outer_radius: float = minf(shape_size.x, shape_size.y) * 0.5

		for i in range(island_count):
			var spec: Dictionary = island_specs[i] if i < island_specs.size() else {}
			var center_ratio: Vector2 = spec.get("center_ratio", Vector2.ZERO)
			var island_world_center: Vector2 = center_ratio * outer_radius
			var rx: float = float(spec.get("radius_x", island_radius))
			var ry: float = float(spec.get("radius_y", island_radius * 0.65))
			var rot: float = float(spec.get("rotation", 0.0))
			var isegs: int = 12
			var island_pts := PackedVector2Array()

			for s_idx in range(isegs):
				var a: float = (TAU / float(isegs)) * float(s_idx)
				var dir := Vector2(cos(a), sin(a))
				var local := Vector2(dir.x * rx, dir.y * ry).rotated(rot)
				var world_p: Vector2 = island_world_center + local
				island_pts.append(center_offset + world_p * scale_factor)

			if island_pts.size() >= 3:
				draw_colored_polygon(island_pts, Color(0.03, 0.07, 0.10, 0.95))
				var island_loop := island_pts.duplicate()
				island_loop.append(island_loop[0])
				draw_polyline(island_loop, ch_colors.island_border, 1.0, true)

	# 3. Отрисовка нейтральных клеток (рассеянные точки)
	var neutral_count: int = mini(18, int(level_data.get("num_neutrals", 40)))
	var neutral_seed: int = int(level_data.get("seed", 42)) + 555
	var rng := RandomNumberGenerator.new()
	rng.seed = neutral_seed

	for n in range(neutral_count):
		var nx: float = rng.randf_range(-hx * 0.75, hx * 0.75)
		var ny: float = rng.randf_range(-hy * 0.75, hy * 0.75)
		var n_screen: Vector2 = center_offset + Vector2(nx, ny) * scale_factor
		draw_circle(n_screen, 1.2, COLOR_NEUTRAL)

	# 4. Спавны врагов
	var num_enemies: int = int(level_data.get("num_enemies", 1))
	var enemy_spawn_slots: Array = level_data.get("enemy_spawn_slots", [1, 2, 3])
	var configured_enemy_types: Array = level_data.get("enemy_types", [])

	for i in range(1, num_enemies + 1):
		if i > DEFAULT_ENEMY_TYPES.size():
			break
		var spawn_slot_idx: int = i
		if i - 1 < enemy_spawn_slots.size():
			spawn_slot_idx = clampi(int(enemy_spawn_slots[i - 1]), 0, SPAWN_SLOTS_NORMALIZED.size() - 1)
		var raw_pos: Vector2 = SPAWN_SLOTS_NORMALIZED[spawn_slot_idx] * Vector2(hx, hy)
		var enemy_pos: Vector2 = center_offset + raw_pos * scale_factor

		var enemy_type: int = DEFAULT_ENEMY_TYPES[i - 1]
		if i - 1 < configured_enemy_types.size():
			enemy_type = int(configured_enemy_types[i - 1])
		elif i == 1:
			enemy_type = int(level_data.get("enemy_type", enemy_type))

		var enemy_color := _get_enemy_color(enemy_type)
		# Свечение врага
		draw_circle(enemy_pos, 4.0, enemy_color * Color(1, 1, 1, 0.35))
		# Ядро врага
		draw_circle(enemy_pos, 2.4, enemy_color)
		# Блик в центре
		draw_circle(enemy_pos, 1.0, Color(1.0, 1.0, 1.0, 0.9))

	# 5. Спавн игрока (голубая точка с кольцом / ореолом)
	var player_spawn_slot: int = clampi(int(level_data.get("player_spawn_slot", 0)), 0, SPAWN_SLOTS_NORMALIZED.size() - 1)
	var player_raw_pos: Vector2 = SPAWN_SLOTS_NORMALIZED[player_spawn_slot] * Vector2(hx, hy)
	var player_pos: Vector2 = center_offset + player_raw_pos * scale_factor

	# Ореол спавна игрока
	draw_arc(player_pos, 5.0, 0.0, TAU, 16, Color(COLOR_PLAYER.r, COLOR_PLAYER.g, COLOR_PLAYER.b, 0.65), 1.0, true)
	draw_circle(player_pos, 4.0, COLOR_PLAYER * Color(1, 1, 1, 0.35))
	draw_circle(player_pos, 2.6, COLOR_PLAYER)
	draw_circle(player_pos, 1.1, Color(1.0, 1.0, 1.0, 0.95))

func _get_enemy_color(enemy_type: int) -> Color:
	match enemy_type:
		2: # ENEMY_RED
			return COLOR_ENEMY_RED
		3: # ENEMY_GREEN
			return COLOR_ENEMY_GREEN
		4: # ENEMY_YELLOW
			return COLOR_ENEMY_YELLOW
		_:
			return COLOR_ENEMY_RED

func _get_chapter_colors(chapter: int) -> Dictionary:
	match chapter:
		2:
			return {
				"border": Color(0.55, 0.90, 0.30, 0.70),
				"highlight": Color(0.75, 1.0, 0.50, 0.30),
				"island_border": Color(0.40, 0.75, 0.25, 0.55)
			}
		3:
			return {
				"border": Color(0.95, 0.65, 0.18, 0.70),
				"highlight": Color(1.0, 0.85, 0.45, 0.30),
				"island_border": Color(0.75, 0.50, 0.15, 0.55)
			}
		4:
			return {
				"border": Color(0.78, 0.36, 0.96, 0.70),
				"highlight": Color(0.90, 0.65, 1.0, 0.30),
				"island_border": Color(0.60, 0.28, 0.75, 0.55)
			}
		5:
			return {
				"border": Color(0.95, 0.45, 0.40, 0.70),
				"highlight": Color(1.0, 0.70, 0.65, 0.30),
				"island_border": Color(0.75, 0.32, 0.30, 0.55)
			}
		6:
			return {
				"border": Color(0.32, 0.65, 1.0, 0.70),
				"highlight": Color(0.65, 0.85, 1.0, 0.30),
				"island_border": Color(0.25, 0.52, 0.80, 0.55)
			}
		_:
			return {
				"border": Color(0.22, 0.58, 0.70, 0.65),
				"highlight": Color(0.40, 0.82, 0.95, 0.25),
				"island_border": Color(0.18, 0.42, 0.50, 0.55)
			}

