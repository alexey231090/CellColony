extends Node2D

var max_radius: float = 350.0
var current_radius: float = 0.0
var duration: float = 1.0 # Время распространения волны
var buff_duration: float = 15.0 # Сколько висит щит
var _affected_cells: Array[Node2D] = []

func _ready() -> void:
	z_index = -5 # Под клетками (или поверх, если 15)
	var tween = create_tween()
	tween.tween_property(self, "current_radius", max_radius, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.5) # Потом пропадает
	tween.tween_callback(queue_free)

func _process(_delta: float) -> void:
	queue_redraw()
	
	# Проверяем кто попал в радиус
	var player_cells = get_tree().get_nodes_in_group("player_cells")
	for cell in player_cells:
		if cell is BaseCell and not _affected_cells.has(cell):
			var dist = global_position.distance_to(cell.global_position)
			if dist <= current_radius:
				_affected_cells.append(cell)
				# Применяем бафф
				cell.reflect_chance = 0.5
				cell.reflect_timer = buff_duration
				cell.queue_redraw()

func _draw() -> void:
	# Рисуем расширяющуюся зеленую волну
	var ring_col = Color(0.1, 0.9, 0.3, 0.6)
	var fill_col = Color(0.1, 0.9, 0.3, 0.15)
	
	draw_circle(Vector2.ZERO, current_radius, fill_col)
	draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, ring_col, 4.0, true)
