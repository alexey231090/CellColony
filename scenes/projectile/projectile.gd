extends Area2D
class_name Projectile

var speed: float = 400.0
var damage: float = 10.0
var direction: Vector2 = Vector2.ZERO
var projectile_color: Color = Color.WHITE
var owner_type: BaseCell.OwnerType = BaseCell.OwnerType.NEUTRAL
var target_node: Node2D = null

var is_virus: bool = false
var virus_duration: float = 0.0
var virus_outbreak_id: int = 0
var original_owner_type: BaseCell.OwnerType = BaseCell.OwnerType.NEUTRAL
var trail_points: Array[Vector2] = []
var trail_timer: float = 0.0
const MAX_TRAIL_POINTS: int = 15

# Жизненный цикл снаряда
var max_lifetime: float = 1.1
var current_lifetime: float = 1.1
var fade_start_time: float = 0.25

func _ready() -> void:
	_sync_visual_direction()
	queue_redraw()

func _sync_visual_direction() -> void:
	if direction.length_squared() <= 0.0001:
		return
	direction = direction.normalized()
	rotation = direction.angle()

func _draw() -> void:
	var current_radius = 5.5
	var fade_alpha := clampf(current_lifetime / fade_start_time, 0.0, 1.0) if current_lifetime <= fade_start_time else 1.0
	var base_col := projectile_color
	base_col.a *= fade_alpha
	
	# Свечение (Glow)
	var glow_color = base_col
	glow_color.a = 0.22 * fade_alpha
	draw_circle(Vector2.ZERO, current_radius * 1.8, glow_color)
	
	# Компактный кометный хвост (1 легкая точка вместо цикла из 3)
	var tail_col = base_col
	tail_col.a = 0.45 * fade_alpha
	draw_circle(Vector2(-7.0, 0), current_radius * 0.65, tail_col)
	
	# Голова кометы
	var final_radius = current_radius
	if is_virus:
		final_radius *= 1.4 # Вирус крупнее
		var v_glow = base_col
		v_glow.a = 0.35 * fade_alpha
		draw_circle(Vector2.ZERO, final_radius * 1.4, v_glow)
		
	draw_circle(Vector2.ZERO, final_radius, base_col)
	
	var core_col = Color.WHITE
	if is_virus: core_col = Color(0.1, 0.0, 0.2)
	core_col.a *= fade_alpha
	draw_circle(Vector2.ZERO, final_radius * 0.42, core_col)
	
	# Шлейф вируса (только если активен вирус)
	if not trail_points.is_empty():
		for i in range(trail_points.size()):
			var p = (trail_points[i] - global_position).rotated(-rotation)
			var life_factor = 1.0 - float(i) / MAX_TRAIL_POINTS
			var t_col = base_col
			t_col.a = life_factor * 0.4 * fade_alpha
			draw_circle(p, final_radius * life_factor * 0.6, t_col)

func _process(delta: float) -> void:
	_sync_visual_direction()

	# Прямой полёт снаряда
	position += direction * speed * delta
	
	# Уменьшаем время жизни
	current_lifetime -= delta
	
	# Удаление если время вышло
	if current_lifetime <= 0.0:
		queue_free()
		return
	
	# Быстрое отсечение при отдалении от экрана
	if current_lifetime < (max_lifetime - 0.3) and not _is_pos_on_screen(global_position):
		queue_free()
		return
	
	if current_lifetime <= fade_start_time:
		queue_redraw()
	
	# Обновление шлейфа (только для вируса, троттлинг ~30fps)
	if is_virus:
		trail_timer += delta
		if trail_timer >= 0.033:
			trail_timer = 0.0
			trail_points.push_front(global_position)
			if trail_points.size() > MAX_TRAIL_POINTS:
				trail_points.pop_back()
			queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if is_queued_for_deletion():
		return

	if body is StaticBody2D:
		_impact_wall_at(global_position)
		return
	
	# Теперь body — это сама клетка (CharacterBody2D)
	var cell = body as BaseCell
	if not cell: 
		# На всякий случай проверяем родителя (старый формат)
		cell = body.get_parent() as BaseCell
		
	if not cell: return

	# 1. Если это наша конкретная ЦЕЛЬ — попадаем всегда
	if cell == target_node:
		_impact(cell)
		return
	
	# 2. Если это ВРАГ или НЕЙТРАЛ (но не цель) — всё равно попадаем (преграда)
	if cell.owner_type != owner_type:
		_impact(cell)
		return
		
	# 3. Если это СОЮЗНИК на пути (и не цель) — пролетаем мимо
	return

@export var impact_effect_scene: PackedScene = preload("res://scenes/projectile/impact_effect.tscn")

func _impact(cell: BaseCell) -> void:
	var virus_source_owner: BaseCell.OwnerType = original_owner_type
	if virus_source_owner == BaseCell.OwnerType.NEUTRAL:
		virus_source_owner = owner_type

	# Пока вирус летит, цель может перейти под контроль стрелявшей фракции.
	# В таком случае собственный вирус просто растворяется и не заражает своих.
	if is_virus and cell.owner_type == virus_source_owner:
		queue_free()
		return

	var is_enemy_hit: bool = cell.owner_type != owner_type
	# Звук щита срабатывает для клетки любой стороны. Отражение ниже остаётся
	# только против вражеского снаряда, чтобы союзная цель не отбрасывала лечение.
	var hits_active_shield: bool = not is_virus and cell.reflect_chance > 0.0
	if hits_active_shield:
		_play_shield_sound(global_position)

	# Проверка на отскок (если у цели есть активный щит)
	if hits_active_shield and is_enemy_hit:
		if randf() <= cell.reflect_chance:
			_reflect(cell)
			return

	# Создаем вспышку
	_spawn_impact_effect(global_position, projectile_color)
	
	# Добавляем толчок только если это НЕ союзник
	if is_enemy_hit:
		var push_strength = 50.0
		cell.velocity += direction * push_strength
	
	# Наносим урон/лечение
	if is_virus:
		cell.infect(virus_duration, virus_outbreak_id, virus_source_owner)
	else:
		if not hits_active_shield:
			if is_enemy_hit:
				_play_damage_sound(global_position)
			else:
				_play_friendly_hit_sound(global_position)
		cell.take_damage(damage, owner_type)
	queue_free()

func _play_damage_sound(at_position: Vector2) -> void:
	var level_sfx := get_tree().get_first_node_in_group("level_sfx")
	if level_sfx and level_sfx.has_method("play_damage"):
		level_sfx.call("play_damage", at_position)

func _play_friendly_hit_sound(at_position: Vector2) -> void:
	var level_sfx := get_tree().get_first_node_in_group("level_sfx")
	if level_sfx and level_sfx.has_method("play_friendly_hit"):
		level_sfx.call("play_friendly_hit", at_position)

func _play_shield_sound(at_position: Vector2) -> void:
	var level_sfx := get_tree().get_first_node_in_group("level_sfx")
	if level_sfx and level_sfx.has_method("play_shield"):
		level_sfx.call("play_shield", at_position)

func _impact_wall_at(impact_pos: Vector2) -> void:
	_spawn_impact_effect(impact_pos + direction.normalized() * 100.0, Color(0.28, 0.86, 0.92, 0.9))
	queue_free()

func _reflect(cell: BaseCell) -> void:
	# Меняем направление (чуть с разбросом для красоты)
	direction = -direction.rotated(randf_range(-0.2, 0.2))
	_sync_visual_direction()
	# Скорость немного возрастает при отскоке!
	speed *= 1.2
	# Снаряд теперь принадлежит отражающему!
	owner_type = cell.owner_type
	projectile_color = cell._get_cell_color()
	target_node = null # Сбрасываем цель, пусть летит прямо
	queue_redraw() # Перерисовываем цветом нового владельца

	# Эффект отскока
	_spawn_impact_effect(global_position, Color.WHITE, Vector2(1.5, 1.5))

func _spawn_impact_effect(pos: Vector2, p_color: Color, p_scale: Vector2 = Vector2.ONE) -> void:
	if not _is_pos_on_screen(pos):
		return
	var impact = impact_effect_scene.instantiate()
	get_tree().current_scene.add_child(impact)
	impact.global_position = pos
	impact.color = p_color
	impact.scale = p_scale

static var _cached_camera: Camera2D = null
static var _cached_camera_frame: int = -1
static var _cached_half_w: float = 1200.0
static var _cached_half_h: float = 800.0
static var _cached_cam_pos: Vector2 = Vector2.ZERO

func _is_pos_on_screen(pos: Vector2) -> bool:
	var current_frame := Engine.get_process_frames()
	if _cached_camera_frame != current_frame:
		_cached_camera_frame = current_frame
		var vp := get_viewport()
		_cached_camera = vp.get_camera_2d() if vp else null
		if is_instance_valid(_cached_camera):
			_cached_cam_pos = _cached_camera.global_position
			var zx: float = maxf(0.1, _cached_camera.zoom.x)
			var zy: float = maxf(0.1, _cached_camera.zoom.y)
			_cached_half_w = (960.0 / zx) + 150.0
			_cached_half_h = (540.0 / zy) + 150.0
	
	if is_instance_valid(_cached_camera):
		return absf(pos.x - _cached_cam_pos.x) <= _cached_half_w and \
			   absf(pos.y - _cached_cam_pos.y) <= _cached_half_h
	
	var vp := get_viewport()
	if vp == null:
		return true
	var screen_pos: Vector2 = vp.get_canvas_transform() * pos
	var vp_rect := vp.get_visible_rect()
	var margin := 100.0
	return screen_pos.x >= -margin and screen_pos.x <= vp_rect.size.x + margin and \
		   screen_pos.y >= -margin and screen_pos.y <= vp_rect.size.y + margin
