extends Area2D
class_name Projectile

var speed: float = 400.0
var damage: float = 10.0
var direction: Vector2 = Vector2.ZERO
var projectile_color: Color = Color.WHITE
var owner_type: BaseCell.OwnerType = BaseCell.OwnerType.NEUTRAL
var target_node: Node2D = null

# Жизненный цикл снаряда
var max_lifetime: float = 5.0   # Максимальное время жизни в секундах
var current_lifetime: float = 5.0
var fade_start_time: float = 1.0 # За какое время до конца начинать исчезать
var _fade_alpha: float = 1.0     # Текущая прозрачность (0..1)

func _draw() -> void:
	# Направление хвоста (противоположно движению)
	var trail_dir = -direction.normalized() if direction != Vector2.ZERO else Vector2.ZERO
	var time = Time.get_ticks_msec() / 1000.0
	var current_radius = 5.5
	
	# Свечение (Glow)
	var glow_color = projectile_color
	glow_color.a = 0.25 * _fade_alpha
	draw_circle(Vector2.ZERO, current_radius * 2.0 * _fade_alpha, glow_color)
	
	# Каплевидный хвост (оптимизированный до 3 кругов)
	for i in range(3):
		var factor = 1.0 - (float(i) / 3.0)
		var tail_wobble = trail_dir.rotated(PI/2) * sin(time * 30.0 - i) * 1.5
		var t_pos = trail_dir * (i * 5.0) + tail_wobble
		var t_col = projectile_color
		t_col.a = factor * 0.7 * _fade_alpha
		draw_circle(t_pos, current_radius * factor * _fade_alpha, t_col)
	
	# Голова кометы
	var head_col = projectile_color
	head_col.a = _fade_alpha
	draw_circle(Vector2.ZERO, current_radius * _fade_alpha, head_col)
	
	var core_col = Color.WHITE
	core_col.a = _fade_alpha
	draw_circle(Vector2.ZERO, current_radius * 0.45 * _fade_alpha, core_col)

var _proj_redraw_timer: float = 0.0

func _process(delta: float) -> void:
	position += direction * speed * delta
	
	# Уменьшаем время жизни
	current_lifetime -= delta
	
	# Плавное растворение в конце
	if current_lifetime <= fade_start_time:
		_fade_alpha = max(0.0, current_lifetime / fade_start_time)
	
	# Оптимизация: перерисовка снарядов ~30fps
	_proj_redraw_timer += delta
	if _proj_redraw_timer >= 0.033:
		_proj_redraw_timer = 0.0
		queue_redraw()
	
	# Удаление если время вышло
	if current_lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
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
	if cell.reflect_chance > 0.0 and cell.owner_type != owner_type:
		if randf() <= cell.reflect_chance:
			_reflect(cell)
			return

	# Создаем вспышку
	var impact = impact_effect_scene.instantiate()
	get_tree().current_scene.add_child(impact)
	impact.global_position = global_position
	impact.color = projectile_color # Цвет вспышки совпадает с цветом снаряда
	
	# Добавляем толчок только если это НЕ союзник
	if cell.owner_type != owner_type:
		var push_strength = 50.0
		cell.velocity += direction * push_strength
	
	# Наносим урон/лечение
	cell.take_damage(damage, owner_type)
	queue_free()

func _reflect(cell: BaseCell) -> void:
	# Меняем направление (чуть с разбросом для красоты)
	direction = -direction.rotated(randf_range(-0.2, 0.2))
	# Скорость немного возрастает при отскоке!
	speed *= 1.2
	# Снаряд теперь принадлежит отражающему!
	owner_type = cell.owner_type
	projectile_color = cell._get_cell_color()
	target_node = null # Сбрасываем цель, пусть летит прямо

	# Эффект отскока
	var impact = impact_effect_scene.instantiate()
	get_tree().current_scene.add_child(impact)
	impact.global_position = global_position
	impact.color = Color.WHITE # Яркая вспышка
	impact.scale = Vector2(1.5, 1.5)
