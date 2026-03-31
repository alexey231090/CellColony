extends Node2D

## ORGANIC LEVEL - CLEAN VERSION ##
# Этот уровень полностью отделен от классического main.tscn.
# Здесь используется только органическая генерация и шейдеры.

@export var cell_scene: PackedScene = preload("res://scenes/base_cell/cell.tscn")
@export var map_size: Vector2 = Vector2(4500, 4500)
var cell_speed_mult: float = 1.0

var playable_polygon_pts: PackedVector2Array = []
@onready var camera: Camera2D = $Camera2D
@onready var bg_rect: ColorRect = $BackgroundLayer/ColorRect

func _ready() -> void:
	add_to_group("main") # Важно для DevConsole и Mover
	
	# 0. Получаем данные (у нас они фиксированные для органики обычно)
	var level_data = {"seed": 202, "map_scale": 1.0}
	if has_node("/root/LevelManager"):
		level_data = get_node("/root/LevelManager").get_current_level_data()
	
	seed(level_data.seed)
	
	# 1. Генерация границ (ТОЛЬКО ВИЗУАЛЬНАЯ ПОКА)
	playable_polygon_pts = _generate_borders_organic()
	
	# 2. Настройка камеры
	if camera:
		var rect = _get_polygon_bounds(playable_polygon_pts)
		var margin = 1000.0
		camera.limit_left = int(rect.position.x - margin)
		camera.limit_right = int(rect.end.x + margin)
		camera.limit_top = int(rect.position.y - margin)
		camera.limit_bottom = int(rect.end.y + margin)
		camera.global_position = Vector2.ZERO
	
	# 3. Спавним игрока в ЦЕНТРЕ (0,0)
	var player_cell = _spawn_cell(Vector2.ZERO, 1, 40.0) # 1 = Player
	player_cell.assigned_perk = "speed"
	player_cell.z_index = 100
	
	# Сбрасываем камеру, чтобы она сразу прыгнула на игрока
	if camera:
		camera._is_first_frame = true
	
	# 4. Свободная камера
	_setup_dev_camera()
	
	print("--- ORGANIC LEVEL LOADED: Чистое пространство (0,0) ---")

func _process(_delta: float) -> void:
	# Обновляем смещение шейдера для параллакса
	if bg_rect and camera:
		bg_rect.material.set_shader_parameter("cam_offset", camera.global_position * 0.15)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_QUOTELEFT:
			_toggle_free_camera()

func _spawn_cell(pos: Vector2, owner_type: int, energy: float):
	var cell = cell_scene.instantiate()
	cell.position = pos
	cell.owner_type = owner_type
	
	# ВАЖНО: Добавляем в группы, чтобы SelectionManager и Camera его видели
	cell.add_to_group("cells")
	if owner_type == 1: # PLAYER
		cell.add_to_group("player_cells")
		cell.name = "PlayerCell"
	
	add_child(cell)
	
	# Настройка энергии
	if cell.has_node("Stats"):
		cell.stats.current_energy = energy
	
	return cell

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

func _generate_borders_organic() -> PackedVector2Array:
	var blob_pts = PackedVector2Array()
	var segments = 120
	var radius = min(map_size.x, map_size.y) / 2.0
	
	var fnl = FastNoiseLite.new()
	fnl.seed = randi()
	fnl.frequency = 0.0015
	
	for i in range(segments):
		var angle = (float(i) / segments) * TAU
		var p_dir = Vector2(cos(angle), sin(angle))
		var noise_val = fnl.get_noise_2dv(p_dir * 1000.0)
		var current_radius = radius * (1.0 + noise_val * 0.18)
		blob_pts.append(p_dir * current_radius)
	
	# Визуальная линия
	var line = Line2D.new()
	line.name = "OrganicBorderVisual"
	line.width = 18.0
	line.default_color = Color(0.3, 0.9, 0.4, 0.6)
	line.closed = true
	line.points = blob_pts
	add_child(line)
	
	return blob_pts

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
