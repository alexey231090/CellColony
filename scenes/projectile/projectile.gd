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
var was_reflected: bool = false
var original_owner_type: BaseCell.OwnerType = BaseCell.OwnerType.NEUTRAL
var trail_points: Array[Vector2] = []
var trail_timer: float = 0.0
const MAX_TRAIL_POINTS: int = 15

# Жизненный цикл снаряда
var max_lifetime: float = 5.0
var current_lifetime: float = 5.0
var fade_start_time: float = 1.0

func _ready() -> void:
	_sync_visual_direction()
	# Рисуем фигуру 1 раз при старте
	queue_redraw()

func _sync_visual_direction() -> void:
	if direction.length_squared() <= 0.0001:
		return
	direction = direction.normalized()
	rotation = direction.angle()

func _draw() -> void:
	var current_radius = 5.5
	
	# Свечение (Glow)
	var glow_color = projectile_color
	glow_color.a = 0.25
	draw_circle(Vector2.ZERO, current_radius * 2.0, glow_color)
	
	# Хвост: рисуем статичный хвост по оси -X (т.к. мы уже повернули Area2D)
	for i in range(3):
		var factor = 1.0 - (float(i) / 3.0)
		# Хвост направлен строго влево (-X), так как X — это direction
		var t_pos = Vector2(-1.0, 0) * (i * 6.0)
		var t_col = projectile_color
		t_col.a = factor * 0.7
		draw_circle(t_pos, current_radius * factor, t_col)
	
	# Голова кометы
	var final_radius = current_radius
	if is_virus:
		final_radius *= 1.4 # Вирус крупнее
		# Доп. свечение для вируса
		var v_glow = projectile_color
		v_glow.a = 0.4
		draw_circle(Vector2.ZERO, final_radius * 1.5, v_glow)
		
	draw_circle(Vector2.ZERO, final_radius, projectile_color)
	
	var core_col = Color.WHITE
	if is_virus: core_col = Color(0.1, 0.0, 0.2)
	draw_circle(Vector2.ZERO, final_radius * 0.4, core_col)
	
	# РИСУЕМ ШЛЕЙФ (если есть точки)
	if not trail_points.is_empty():
		# Шлейф рисуем вне трансформации вращения, 
		# либо учитываем, что draw_circle(Vector2.ZERO) это центр.
		# Чтобы шлейф не вращался вместе с головой при изменении направления, 
		# лучше рисовать его в глобальных координатах через DrawPolyline, 
		# предварительно переведя в локальные.
		var local_points = PackedVector2Array()
		for i in range(trail_points.size()):
			# Перевод из глобальной позиции в локальную относительно снаряда
			# Но т.к. мы внутри _draw и есть вращение, нужно отменить вращение или 
			# рисовать без draw_set_transform.
			# Проще всего: вычитать global_position и поворачивать на -rotation
			var p = (trail_points[i] - global_position).rotated(-rotation)
			local_points.append(p)
		
		# Рисуем шлейф как серию кругов или линию
		for i in range(local_points.size()):
			var p = local_points[i]
			var life_factor = 1.0 - float(i) / MAX_TRAIL_POINTS
			var t_col = projectile_color
			t_col.a = life_factor * 0.5
			draw_circle(p, final_radius * life_factor * 0.7, t_col)

func _process(delta: float) -> void:
	_sync_visual_direction()

	var motion: Vector2 = direction * speed * delta
	var next_position: Vector2 = position + motion
	var next_global_position: Vector2 = global_position + motion
	var wall_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, next_global_position)
	wall_query.exclude = [self]
	var wall_hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(wall_query)
	if not wall_hit.is_empty():
		var collider: Object = wall_hit.get("collider")
		if collider is StaticBody2D:
			_impact_wall_at(Vector2(wall_hit.get("position", global_position)))
			return

	# Используем простую физику прямого полета
	position = next_position
	
	# Уменьшаем время жизни
	current_lifetime -= delta
	
	# Плавное растворение в конце средствами GPU (modulate)
	if current_lifetime <= fade_start_time:
		var alpha = max(0.0, current_lifetime / fade_start_time)
		modulate.a = alpha # Бесплатная прозрачность на уровне рендерера
	
	# Удаление если время вышло
	if current_lifetime <= 0:
		queue_free()
	
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
	# Проверка на отскок (если у цели есть активный щит)
	if not is_virus and cell.reflect_chance > 0.0 and cell.owner_type != owner_type:
		if randf() <= cell.reflect_chance:
			_reflect(cell)
			return

	# Создаем вспышку
	_spawn_impact_effect(global_position, projectile_color)
	
	# Добавляем толчок только если это НЕ союзник
	if cell.owner_type != owner_type:
		var push_strength = 50.0
		cell.velocity += direction * push_strength
	
	# Наносим урон/лечение
	if is_virus:
		# Проверка на защиту от собственного отраженного вируса
		if was_reflected and original_owner_type == BaseCell.OwnerType.PLAYER and cell.owner_type == BaseCell.OwnerType.PLAYER:
			# Растворяемся без вреда для себя
			queue_free()
			return
		cell.infect(virus_duration, virus_outbreak_id)
	else:
		cell.take_damage(damage, owner_type)
	queue_free()

func _impact_wall_at(impact_pos: Vector2) -> void:
	_spawn_impact_effect(impact_pos + direction.normalized() * 100.0, Color(0.28, 0.86, 0.92, 0.9))
	queue_free()

func _reflect(cell: BaseCell) -> void:
	was_reflected = true
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
	var impact = impact_effect_scene.instantiate()
	get_tree().current_scene.add_child(impact)
	impact.global_position = pos
	impact.color = p_color
	impact.scale = p_scale
