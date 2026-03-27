extends Line2D
class_name VirusTrajectoryLine
## Визуализация траектории вируса - плавно исчезающая линия

var lifetime: float = 1.5  # Время жизни линии (увеличено)
var current_time: float = 0.0

func _ready() -> void:
	width = 4.0
	default_color = Color(0.9, 0.1, 0.9, 1.0)  # Яркий фиолетовый
	z_index = 50
	print("VirusTrajectoryLine создана, точек: ", get_point_count())

func _process(delta: float) -> void:
	current_time += delta
	
	# Плавное исчезновение
	var alpha = 1.0 - (current_time / lifetime)
	default_color.a = max(0.0, alpha)
	
	# Удаление после истечения времени
	if current_time >= lifetime:
		print("VirusTrajectoryLine удалена")
		queue_free()
