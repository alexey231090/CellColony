extends Control
class_name PerkEnergyBar
## PerkEnergyBar - Обновлённый, стильный бар энергии перков
## Использует StyleBoxFlat для скруглений и теней без текстур

# --- Константы ---
const BAR_WIDTH: float = 240.0
const BAR_HEIGHT: float = 24.0
const ICON_SIZE: float = 28.0
const PADDING: float = 8.0
const DIFFICULTY_TEXT_GAP: float = 24.0

# --- Цвета ---
const ENERGY_COLOR: Color = Color(0.0, 0.8, 1.0)  # Ярко-голубой
const ENERGY_COLOR_FULL: Color = Color(0.0, 1.0, 0.7)  # Бирюзовый
const BG_COLOR: Color = Color(0.05, 0.05, 0.1, 0.7)  # Тёмно-синий прозрачный
const OUTLINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.2)  # Тонкая светлая обводка

const STAR_TEX: Texture2D = preload("res://assets/sprites/miniStar.png")

# --- Состояние ---
var current_energy: float = 0.0
var max_energy: float = 100.0
var display_energy: float = 0.0
var selection_manager: Node = null
var pulse_time: float = 0.0
var difficulty_stars_count: int = 0
var tutorial_highlight: bool = false

# --- StyleBoxes (для оптимизации создаем один раз) ---
var bg_style = StyleBoxFlat.new()
var fill_style = StyleBoxFlat.new()

func _ready() -> void:
	custom_minimum_size = Vector2(BAR_WIDTH + PADDING * 4, BAR_HEIGHT + PADDING * 2 + DIFFICULTY_TEXT_GAP)
	
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

	var new_stars_count := _get_difficulty_stars_count()
	if difficulty_stars_count != new_stars_count:
		difficulty_stars_count = new_stars_count
		queue_redraw()
	
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
	if tutorial_highlight:
		var tutorial_pulse := (sin(Time.get_ticks_msec() / 120.0) + 1.0) * 0.5
		var highlight_rect := bar_rect.grow(8.0 + tutorial_pulse * 4.0)
		var corner_radius := 18
		var outer_glow_style := StyleBoxFlat.new()
		outer_glow_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		outer_glow_style.draw_center = false
		outer_glow_style.set_corner_radius_all(corner_radius + 2)
		outer_glow_style.border_width_left = 2
		outer_glow_style.border_width_top = 2
		outer_glow_style.border_width_right = 2
		outer_glow_style.border_width_bottom = 2
		outer_glow_style.border_color = Color(1.0, 0.9, 0.24, 0.2 + tutorial_pulse * 0.22)
		draw_style_box(outer_glow_style, bar_rect.grow(10.0 + tutorial_pulse * 4.0))
		var outline_style := StyleBoxFlat.new()
		outline_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		outline_style.draw_center = false
		outline_style.set_corner_radius_all(corner_radius)
		outline_style.border_width_left = 5
		outline_style.border_width_top = 5
		outline_style.border_width_right = 5
		outline_style.border_width_bottom = 5
		outline_style.border_color = Color(1.0, 0.9, 0.16, 0.62 + tutorial_pulse * 0.36)
		draw_style_box(outline_style, highlight_rect)
		var inner_glow_style := StyleBoxFlat.new()
		inner_glow_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		inner_glow_style.draw_center = false
		inner_glow_style.set_corner_radius_all(14)
		inner_glow_style.border_width_left = 2
		inner_glow_style.border_width_top = 2
		inner_glow_style.border_width_right = 2
		inner_glow_style.border_width_bottom = 2
		inner_glow_style.border_color = Color(1.0, 0.98, 0.78, 0.42 + tutorial_pulse * 0.3)
		draw_style_box(inner_glow_style, bar_rect.grow(2.0 + tutorial_pulse * 1.0))
	
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
	
	# 4. Текст (теперь в абсолютных единицах для прозрачности)
	var text = "%d / %d" % [int(current_energy), int(max_energy)]
	
	var font = ThemeDB.fallback_font
	var font_size = 14
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = bar_rect.position + Vector2(BAR_WIDTH / 2.0 - text_size.x / 2.0, BAR_HEIGHT / 2.0 + 5)
	
	# Тень текста для читаемости
	draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.8))
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	# 5. Звёзды сложности под полосой энергии (текстура miniStar.png)
	if difficulty_stars_count > 0:
		var star_size := 16.0
		var star_gap := 5.0
		var total_stars_w: float = float(difficulty_stars_count) * star_size + float(difficulty_stars_count - 1) * star_gap
		var start_x: float = bar_rect.position.x + (BAR_WIDTH - total_stars_w) * 0.5
		var start_y: float = bar_rect.position.y + BAR_HEIGHT + 6.0

		for i in range(difficulty_stars_count):
			var star_pos := Vector2(start_x + float(i) * (star_size + star_gap), start_y)
			var star_rect := Rect2(star_pos, Vector2(star_size, star_size))
			# Тень под звездой для отличного контраста
			draw_texture_rect(STAR_TEX, Rect2(star_pos + Vector2(0, 1), Vector2(star_size, star_size)), false, Color(0, 0, 0, 0.65))
			# Яркая золотая звезда
			draw_texture_rect(STAR_TEX, star_rect, false, Color(1.0, 0.88, 0.25, 1.0))

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

func _get_difficulty_stars_count() -> int:
	var level_manager := get_node_or_null("/root/LevelManager")
	if level_manager == null:
		return 0
	var level_data: Dictionary = level_manager.get_current_level_data()
	if bool(level_data.get("is_tutorial", false)):
		return 0

	var difficulty: String = String(level_manager.get_selected_difficulty())
	match difficulty:
		"hard":
			return 3
		"medium":
			return 2
		_:
			return 1

func set_tutorial_highlight(enabled: bool) -> void:
	if tutorial_highlight == enabled:
		return
	tutorial_highlight = enabled
	queue_redraw()
