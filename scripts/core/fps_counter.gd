extends Label
## FPS-счётчик. Отображает текущий FPS в углу экрана.
## Обновляется 4 раза в секунду для экономии ресурсов.

var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.25

func _ready() -> void:
	# Позиция: правый верхний угол
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -90.0
	offset_top = 8.0
	offset_right = -8.0
	offset_bottom = 30.0
	
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var settings := LabelSettings.new()
	settings.font_size = 16
	settings.font_color = Color(0.0, 1.0, 0.5, 0.8)
	settings.outline_size = 3
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.6)
	label_settings = settings

func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		text = "%d FPS" % Engine.get_frames_per_second()
