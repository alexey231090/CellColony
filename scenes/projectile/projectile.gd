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

# Жизненный цикл снаряда
var max_lifetime: float = 5.0   # Максимальное время жизни в секундах
var current_lifetime: float = 5.0
var fade_start_time: float = 1.0 # За какое время до конца начинать исчезать
var _fade_alpha: float = 1.0     # Текущая прозрачность (0..1)

func _ready() -> void:
	rotation = direction.angle()
	# Рисуем фигуру 1 раз при старте
	queue_redraw()

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
	draw_circle(Vector2.ZERO, current_radius, projectile_color)
	
	var core_col = Color.WHITE
	if is_virus: core_col = Color(0.3, 0.0, 0.5)
	draw_circle(Vector2.ZERO, current_radius * 0.45, core_col)

func _process(delta: float) -> void:
	# Используем простую физику прямого полета
	position += direction * speed * delta
	
	# Уменьшаем время жизни
	current_lifetime -= delta
	
	# Плавное растворение в конце средствами GPU (modulate)
	if current_lifetime <= fade_start_time:
		var alpha = max(0.0, current_lifetime / fade_start_time)
		modulate.a = alpha # Бесплатная прозрачность на уровне рендерера
	
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
	if is_virus:
		cell.infect(virus_duration, virus_outbreak_id)
	else:
		cell.take_damage(damage, owner_type)
	queue_free()

func _reflect(cell: BaseCell) -> void:
	# Меняем направление (чуть с разбросом для красоты)
	direction = -direction.rotated(randf_range(-0.2, 0.2))
	rotation = direction.angle() # Обновляем поворот хвоста
	# Скорость немного возрастает при отскоке!
	speed *= 1.2
	# Снаряд теперь принадлежит отражающему!
	owner_type = cell.owner_type
	projectile_color = cell._get_cell_color()
	target_node = null # Сбрасываем цель, пусть летит прямо
	queue_redraw() # Перерисовываем цветом нового владельца

	# Эффект отскока
	var impact = impact_effect_scene.instantiate()
	get_tree().current_scene.add_child(impact)
	impact.global_position = global_position
	impact.color = Color.WHITE # Яркая вспышка
	impact.scale = Vector2(1.5, 1.5)
