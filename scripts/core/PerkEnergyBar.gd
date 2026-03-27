extends Control
class_name PerkEnergyBar
## PerkEnergyBar - Красивый бар энергии перков (верхний центр экрана)
## Минималистичный дизайн с плавными анимациями

# --- Константы ---
const BAR_WIDTH: float = 200.0
const BAR_HEIGHT: float = 30.0
const ICON_SIZE: float = 24.0
const PADDING: float = 10.0

# --- Цвета ---
const ENERGY_COLOR: Color = Color(0.2, 0.8, 1.0)  # Синий
const ENERGY_COLOR_FULL: Color = Color(0.0, 1.0, 0.8)  # Бирюзовый при полной
const BG_COLOR: Color = Color(0.1, 0.1, 0.15, 0.8)  # Тёмный фон
const OUTLINE_COLOR: Color = Color(0.4, 0.4, 0.5, 1.0)  # Обводка

# --- Состояние ---
var current_energy: float = 0.0
var max_energy: float = 100.0
var display_energy: float = 0.0  # Для плавной анимации
var selection_manager: Node = null

# --- Анимация ---
var pulse_time: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(BAR_WIDTH + PADDING * 2, BAR_HEIGHT + PADDING * 2)
	
	# Позиционирование в верхнем центре
	anchor_left = 0.5
	anchor_top = 0.0
	anchor_right = 0.5
	anchor_bottom = 0.0
	offset_left = -(BAR_WIDTH + PADDING * 2) / 2.0
	offset_top = 10.0
	offset_right = (BAR_WIDTH + PADDING * 2) / 2.0
	offset_bottom = BAR_HEIGHT + PADDING * 2 + 10.0

func _process(delta: float) -> void:
	# Получаем энергию из SelectionManager
	if not selection_manager:
		selection_manager = get_tree().get_first_node_in_group("selection_manager")
	
	if selection_manager:
		current_energy = selection_manager.perk_energy
		max_energy = selection_manager.MAX_PERK_ENERGY
	
	# Плавная анимация изменения энергии
	display_energy = lerp(display_energy, current_energy, delta * 10.0)
	
	# Пульсация при полной энергии
	if current_energy >= max_energy:
		pulse_time += delta * 3.0
	else:
		pulse_time = 0.0
	
	queue_redraw()

func _draw() -> void:
	var center = size / 2.0
	var bar_pos = Vector2(PADDING, PADDING)
	var bar_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	
	# 1. Фон бара
	draw_rect(Rect2(bar_pos, bar_size), BG_COLOR, true)
	
	# 2. Заполненная часть (энергия)
	var fill_width = (display_energy / max_energy) * BAR_WIDTH
	if fill_width > 0:
		var energy_color = ENERGY_COLOR
		
		# Меняем цвет при полной энергии
		if current_energy >= max_energy:
			var pulse = (sin(pulse_time) + 1.0) * 0.5
			energy_color = ENERGY_COLOR.lerp(ENERGY_COLOR_FULL, pulse)
		
		# Градиент (светлее сверху, темнее снизу)
		var gradient_top = energy_color.lightened(0.2)
		var gradient_bottom = energy_color.darkened(0.1)
		
		var points = PackedVector2Array([
			bar_pos,
			bar_pos + Vector2(fill_width, 0),
			bar_pos + Vector2(fill_width, BAR_HEIGHT),
			bar_pos + Vector2(0, BAR_HEIGHT)
		])
		var colors = PackedColorArray([gradient_top, gradient_top, gradient_bottom, gradient_bottom])
		draw_polygon(points, colors)
	
	# 3. Обводка бара
	draw_rect(Rect2(bar_pos, bar_size), OUTLINE_COLOR, false, 2.0)
	
	# 4. Иконка молнии (⚡)
	var icon_pos = bar_pos + Vector2(-ICON_SIZE - 5, BAR_HEIGHT / 2.0 - ICON_SIZE / 2.0)
	_draw_lightning_icon(icon_pos, ICON_SIZE)
	
	# 5. Текст энергии
	var text = "%d / %d" % [int(current_energy), int(max_energy)]
	var font = ThemeDB.fallback_font
	var font_size = 16
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = bar_pos + Vector2(BAR_WIDTH / 2.0 - text_size.x / 2.0, BAR_HEIGHT / 2.0 + font_size / 2.0 - 2)
	
	# Тень текста
	draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.7))
	# Основной текст
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _draw_lightning_icon(pos: Vector2, size: float) -> void:
	## Рисует иконку молнии (упрощённая версия без самопересечений)
	var s = size * 0.5
	
	# Верхняя часть молнии
	var pts1 = PackedVector2Array([
		pos + Vector2(s*0.3, 0),
		pos + Vector2(-s*0.5, s*0.4),
		pos + Vector2(s*0.1, s*0.4)
	])
	draw_colored_polygon(pts1, ENERGY_COLOR)
	
	# Нижняя часть молнии
	var pts2 = PackedVector2Array([
		pos + Vector2(-s*0.1, s*0.2),
		pos + Vector2(s*0.5, s*0.2),
		pos + Vector2(-s*0.3, s)
	])
	draw_colored_polygon(pts2, ENERGY_COLOR)
	
	# Свечение
	if current_energy >= max_energy:
		var pulse = (sin(pulse_time) + 1.0) * 0.5
		var glow_color = ENERGY_COLOR_FULL
		glow_color.a = 0.3 + pulse * 0.3
		draw_circle(pos + Vector2(0, s*0.5), size * 0.8, glow_color)
