extends CanvasLayer
class_name PerkButtonPanel
## PerkButtonPanel - Панель управления перками (слева внизу)
## Как в Mobile Legends: круглые кнопки с джойстиком прицеливания

# --- Константы ---
const BUTTON_SIZE: float = 68.0
const BUTTON_SPACING: float = 14.0
const MARGIN_LEFT: float = 24.0
const MARGIN_BOTTOM: float = 24.0

# --- Параметры перков ---
var perk_configs: Array = [
	{"name": "shield", "color": Color(0.2, 0.8, 1.0)},
	{"name": "rapid_fire", "color": Color(1.0, 0.5, 0.1)},
	{"name": "speed", "color": Color(1.0, 0.9, 0.1)},
	{"name": "virus", "color": Color(0.9, 0.1, 0.1)}
]

# --- Кнопки ---
var buttons: Array[PerkButton] = []
var container: Control = null

func _ready() -> void:
	layer = 110  # Поверх всего
	
	# Создаём контейнер для кнопок
	container = Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(container)
	
	# Создаём кнопки перков
	_create_buttons()
	
	# Позиционируем кнопки
	_arrange_buttons()

func _create_buttons() -> void:
	## Создаёт 4 кнопки перков
	for i in range(perk_configs.size()):
		var config = perk_configs[i]
		
		var button = PerkButton.new()
		button.perk_name = config["name"]
		button.perk_color = config["color"]
		button.perk_index = i
		
		container.add_child(button)
		buttons.append(button)

func _arrange_buttons() -> void:
	## Расставляет кнопки вертикально слева внизу
	var viewport_size = get_viewport().get_visible_rect().size
	
	for i in range(buttons.size()):
		var button = buttons[i]
		
		# Позиция: слева внизу, вертикально. i=0 (Shield) - верхний.
		var x = MARGIN_LEFT
		var y = viewport_size.y - MARGIN_BOTTOM - (BUTTON_SIZE + BUTTON_SPACING) * (buttons.size() - i)
		
		button.position = Vector2(x, y)

var _cached_viewport_size: Vector2 = Vector2.ZERO

func _process(_delta: float) -> void:
	# Адаптация к изменению размера окна
	var current_size = get_viewport().get_visible_rect().size
	if current_size != _cached_viewport_size:
		_cached_viewport_size = current_size
		_arrange_buttons()
