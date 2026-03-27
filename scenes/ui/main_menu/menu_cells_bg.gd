extends Node2D
class_name MenuCellsBackground
## Процедурный анимированный фон меню — плавающие клетки.
## Рисует на заднем плане полупрозрачные "живые" клетки
## с желейной физикой, создавая атмосферу биологии.

const CELL_COUNT := 18
const MIN_RADIUS := 20.0
const MAX_RADIUS := 55.0
const MIN_SPEED := 15.0
const MAX_SPEED := 40.0
const JELLY_AMPLITUDE := 0.08
const JELLY_SPEED := 2.5
const SEGMENT_COUNT := 24

# Цвета фракций (приглушенные для фона)
const CELL_COLORS: Array[Color] = [
	Color(0.15, 0.55, 1.0, 0.15),   # Синий (игрок)
	Color(1.0, 0.25, 0.25, 0.12),   # Красный
	Color(0.15, 0.85, 0.35, 0.13),  # Зелёный
	Color(1.0, 0.8, 0.15, 0.11),    # Жёлтый
	Color(0.5, 0.5, 0.6, 0.08),     # Нейтральный (серый)
]

class FloatingCell:
	var pos: Vector2
	var velocity: Vector2
	var radius: float
	var color: Color
	var outline_color: Color
	var phase: float  # Фаза для желе-анимации
	var jelly_speed: float

var cells: Array[FloatingCell] = []
var viewport_size: Vector2 = Vector2(1152, 648)

func _ready() -> void:
	z_index = -10
	viewport_size = get_viewport().get_visible_rect().size
	_spawn_cells()

func _spawn_cells() -> void:
	cells.clear()
	for i in range(CELL_COUNT):
		var cell = FloatingCell.new()
		cell.radius = randf_range(MIN_RADIUS, MAX_RADIUS)
		cell.pos = Vector2(
			randf_range(cell.radius, viewport_size.x - cell.radius),
			randf_range(cell.radius, viewport_size.y - cell.radius)
		)
		var angle = randf_range(0, TAU)
		var speed = randf_range(MIN_SPEED, MAX_SPEED)
		cell.velocity = Vector2(cos(angle), sin(angle)) * speed
		cell.color = CELL_COLORS[i % CELL_COLORS.size()]
		cell.outline_color = Color(cell.color.r, cell.color.g, cell.color.b, cell.color.a * 2.5)
		cell.phase = randf_range(0, TAU)
		cell.jelly_speed = randf_range(JELLY_SPEED * 0.7, JELLY_SPEED * 1.3)
		cells.append(cell)

func _process(delta: float) -> void:
	viewport_size = get_viewport().get_visible_rect().size
	
	for cell in cells:
		cell.pos += cell.velocity * delta
		cell.phase += delta * cell.jelly_speed
		
		# Отражение от стен
		if cell.pos.x < cell.radius or cell.pos.x > viewport_size.x - cell.radius:
			cell.velocity.x *= -1
			cell.pos.x = clampf(cell.pos.x, cell.radius, viewport_size.x - cell.radius)
		if cell.pos.y < cell.radius or cell.pos.y > viewport_size.y - cell.radius:
			cell.velocity.y *= -1
			cell.pos.y = clampf(cell.pos.y, cell.radius, viewport_size.y - cell.radius)
	
	queue_redraw()

func _draw() -> void:
	for cell in cells:
		var points = PackedVector2Array()
		for i in range(SEGMENT_COUNT):
			var angle = (TAU / SEGMENT_COUNT) * i
			var jelly = 1.0 + sin(cell.phase + angle * 3.0) * JELLY_AMPLITUDE
			var r = cell.radius * jelly
			points.append(cell.pos + Vector2(cos(angle), sin(angle)) * r)
		
		# Замыкаем полигон
		points.append(points[0])
		
		# Тело
		draw_colored_polygon(points, cell.color)
		# Мембрана
		draw_polyline(points, cell.outline_color, 1.5, true)
		
		# Ядро (маленький кружок внутри)
		var nucleus_pos = cell.pos + Vector2(
			cos(cell.phase * 0.7) * cell.radius * 0.15,
			sin(cell.phase * 0.9) * cell.radius * 0.15
		)
		var nucleus_color = Color(cell.color.r, cell.color.g, cell.color.b, cell.color.a * 1.8)
		draw_circle(nucleus_pos, cell.radius * 0.25, nucleus_color)
