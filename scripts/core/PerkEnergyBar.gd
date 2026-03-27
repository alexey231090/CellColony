extends Control
class_name PerkEnergyBar
## PerkEnergyBar - Обновлённый, стильный бар энергии перков
## Использует StyleBoxFlat для скруглений и теней без текстур

# --- Константы ---
const BAR_WIDTH: float = 240.0
const BAR_HEIGHT: float = 24.0
const ICON_SIZE: float = 28.0
const PADDING: float = 8.0

# --- Цвета ---
const ENERGY_COLOR: Color = Color(0.0, 0.8, 1.0)  # Ярко-голубой
const ENERGY_COLOR_FULL: Color = Color(0.0, 1.0, 0.7)  # Бирюзовый
const BG_COLOR: Color = Color(0.05, 0.05, 0.1, 0.7)  # Тёмно-синий прозрачный
const OUTLINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.2)  # Тонкая светлая обводка

# --- Состояние ---
var current_energy: float = 0.0
var max_energy: float = 100.0
var display_energy: float = 0.0
var selection_manager: Node = null
var pulse_time: float = 0.0

# --- StyleBoxes (для оптимизации создаем один раз) ---
var bg_style = StyleBoxFlat.new()
var fill_style = StyleBoxFlat.new()

func _ready() -> void:
	custom_minimum_size = Vector2(BAR_WIDTH + PADDING * 4, BAR_HEIGHT + PADDING * 2)
	
	# Конфигурация фона
	bg_style.bg_color = BG_COLOR
	bg_style.set_corner_radius_all(12)
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = OUTLINE_COLOR
	bg_style.shadow_color = Color(0, 0, 0, 0.3)
	bg_style.shadow_size = 6
	bg_style.shadow_offset = Vector2(0, 3)
	
	# Конфигурация заливки
	fill_style.set_corner_radius_all(10)
	
	# Позиционирование
	anchor_left = 0.5
	anchor_top = 0.0
	anchor_right = 0.5
	anchor_bottom = 0.0
	offset_left = -custom_minimum_size.x / 2.0
	offset_top = 20.0
	offset_right = custom_minimum_size.x / 2.0
	offset_bottom = custom_minimum_size.y + 20.0

func _process(delta: float) -> void:
	if not selection_manager:
		selection_manager = get_tree().get_first_node_in_group("selection_manager")
	
	if selection_manager:
		current_energy = selection_manager.perk_energy
		max_energy = selection_manager.MAX_PERK_ENERGY
	
	if max_energy <= 0.0: max_energy = 1.0 # Защита от деления на 0
	
	var prev_display = display_energy
	display_energy = lerp(display_energy, current_energy, delta * 8.0)
	
	if current_energy >= max_energy:
		pulse_time += delta * 4.0
	else:
		pulse_time = 0.0
	
	# Перерисовка только при изменении значения или пульсации
	if abs(prev_display - display_energy) > 0.1 or pulse_time > 0.0:
		queue_redraw()

func _draw() -> void:
	var bar_rect = Rect2(Vector2(PADDING * 2, PADDING), Vector2(BAR_WIDTH, BAR_HEIGHT))
	
	# 1. Отрисовка фона через StyleBox
	draw_style_box(bg_style, bar_rect)
	
	# 2. Отрисовка заливки энергии
	var fill_ratio = clamp(display_energy / max_energy, 0.0, 1.0)
	if fill_ratio > 0.01:
		var fill_width = BAR_WIDTH * fill_ratio
		var fill_rect = Rect2(bar_rect.position, Vector2(fill_width, BAR_HEIGHT))
		
		var energy_color = ENERGY_COLOR
		if current_energy >= max_energy:
			var pulse = (sin(pulse_time) + 1.0) * 0.5
			energy_color = ENERGY_COLOR.lerp(ENERGY_COLOR_FULL, pulse)
		
		fill_style.bg_color = energy_color
		# Добавляем внутренний градиент через StyleBox (светлая полоса сверху)
		draw_style_box(fill_style, fill_rect)
		
		# Дополнительный блик сверху для объема
		var glass_rect = Rect2(fill_rect.position, Vector2(fill_width, BAR_HEIGHT * 0.4))
		draw_rect(glass_rect, Color(1, 1, 1, 0.15), true)
	
	# 3. Иконка молнии слева
	var icon_pos = bar_rect.position + Vector2(-ICON_SIZE - 12, BAR_HEIGHT / 2.0)
	_draw_lightning_icon(icon_pos, ICON_SIZE)
	
	# 4. Текст (процент или число)
	var text = "%d%%" % [int((current_energy / max_energy) * 100)]
	if current_energy >= max_energy: text = "READY"
	
	var font = ThemeDB.fallback_font
	var font_size = 14
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = bar_rect.position + Vector2(BAR_WIDTH / 2.0 - text_size.x / 2.0, BAR_HEIGHT / 2.0 + 5)
	
	# Тень текста для читаемости
	draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.8))
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _draw_lightning_icon(center: Vector2, size: float) -> void:
	var s = size * 0.45
	var color = ENERGY_COLOR
	
	if current_energy >= max_energy:
		var pulse = (sin(pulse_time) + 1.0) * 0.5
		color = ENERGY_COLOR.lerp(ENERGY_COLOR_FULL, pulse)
		# Свечение иконки
		draw_circle(center, size * 0.7, Color(color.r, color.g, color.b, 0.2 + pulse * 0.2))

	# Рисуем классическую молнию из двух полигонов
	# Тень иконки
	var shadow_offset = Vector2(1, 2)
	_draw_bolt_shape(center + shadow_offset, s, Color(0, 0, 0, 0.5))
	# Сама иконка
	_draw_bolt_shape(center, s, color)

func _draw_bolt_shape(center: Vector2, s: float, col: Color) -> void:
	# Верхний сегмент
	var pts1 = PackedVector2Array([
		center + Vector2(s * 0.2, -s * 1.1),
		center + Vector2(-s * 0.6, s * 0.1),
		center + Vector2(s * 0.1, s * 0.1)
	])
	draw_colored_polygon(pts1, col)
	
	# Нижний сегмент
	var pts2 = PackedVector2Array([
		center + Vector2(-s * 0.1, -s * 0.1),
		center + Vector2(s * 0.6, -s * 0.1),
		center + Vector2(-s * 0.2, s * 1.1)
	])
	draw_colored_polygon(pts2, col)
