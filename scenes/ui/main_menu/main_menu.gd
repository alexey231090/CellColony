extends Control
class_name MainMenu
## Главное Меню игры CellColony.
## Адаптивный дизайн для ПК и мобильных (Яндекс Игры).
## Всё построено процедурно через StyleBoxFlat — без текстур.

# ========== КОНСТАНТЫ ДИЗАЙНА ==========
const ACCENT_COLOR := Color(0.1, 0.85, 0.55, 1.0)     # Неоново-зелёный (основной)
const ACCENT_BLUE := Color(0.15, 0.6, 1.0, 1.0)        # Неоново-синий
const ACCENT_RED := Color(1.0, 0.3, 0.35, 1.0)          # Красный для замочков
const PANEL_BG := Color(0.08, 0.1, 0.14, 0.85)          # Тёмный полупрозрачный фон
const PANEL_BORDER := Color(0.2, 0.9, 0.5, 0.3)         # Зелёная рамка
const BTN_BG := Color(0.12, 0.15, 0.2, 0.9)             # Фон кнопок
const BTN_HOVER := Color(0.15, 0.2, 0.28, 0.95)         # Hover кнопок
const BTN_PRESSED := Color(0.08, 0.1, 0.14, 1.0)        # Pressed кнопок
const LOCKED_COLOR := Color(0.4, 0.4, 0.5, 0.6)         # Серый заблокированный
const TEXT_COLOR := Color(0.9, 0.95, 1.0, 1.0)           # Белый текст
const TEXT_DIM := Color(0.5, 0.55, 0.6, 1.0)             # Приглушённый текст
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.5)

const CORNER_RADIUS := 16
const BTN_CORNER := 12
const BTN_MIN_HEIGHT := 56  # Минимальная высота кнопок (удобно для пальца)

# ========== НОДЫ ==========
var background: TextureRect
var safe_area: MarginContainer
var main_screen: Control
var level_panel: Control
var settings_panel: Control
var overlay: ColorRect

# Кнопки верхней панели
var sound_btn: Button
var music_btn: Button
var settings_btn: Button

# Центр
var title_label: Label
var play_button: Button
var play_pulse_tween: Tween

# Уровни
var level_grid: GridContainer
var level_back_btn: Button

# Настройки
var sound_slider: HSlider
var music_slider: HSlider
var sound_value_label: Label
var music_value_label: Label
var settings_close_btn: Button

# Состояние
var is_sound_on: bool = true
var is_music_on: bool = true
var sound_volume: float = 80.0
var music_volume: float = 80.0
var unlocked_levels: int = 1
var total_levels: int = 12

func _ready() -> void:
	# Полный экран
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	
	# Тёмный базовый фон (заглушка)
	var dark_bg = ColorRect.new()
	dark_bg.name = "DarkBG"
	dark_bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dark_bg.color = Color(0.04, 0.05, 0.08, 1.0)
	dark_bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(dark_bg)
	
	_build_background()
	
	# Анимированный фон с плавающими клетками
	var cells_bg = preload("res://scenes/ui/main_menu/menu_cells_bg.gd").new()
	cells_bg.name = "CellsBG"
	add_child(cells_bg)
	
	_build_overlay()
	_build_safe_area()
	_build_main_screen()
	_build_level_panel()
	_build_settings_panel()
	
	# Элементы основного экрана (начальное состояние)
	level_panel.visible = false
	settings_panel.visible = false
	overlay.visible = false
	
	# Запускаем пульсацию СВЕЧЕНИЯ
	if play_button.has_meta("glow"):
		var glow = play_button.get_meta("glow")
		var t = create_tween().set_loops()
		t.tween_property(glow, "modulate:a", 1.0, 1.2).from(0.3)
		t.tween_property(glow, "modulate:a", 0.3, 1.2)

# ========== ФАБРИКА ЭЛЕМЕНТОВ ==========

func _make_stylebox(bg_color: Color, corner: int = CORNER_RADIUS, border_width: int = 0, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.corner_radius_top_left = corner
	sb.corner_radius_top_right = corner
	sb.corner_radius_bottom_left = corner
	sb.corner_radius_bottom_right = corner
	if border_width > 0:
		sb.border_width_left = border_width
		sb.border_width_right = border_width
		sb.border_width_top = border_width
		sb.border_width_bottom = border_width
		sb.border_color = border_color
	sb.shadow_color = SHADOW_COLOR
	sb.shadow_size = 4
	return sb

func _make_button(text: String, accent: Color = ACCENT_COLOR, min_h: int = BTN_MIN_HEIGHT) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size.y = min_h
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Normal
	var normal_sb = _make_stylebox(BTN_BG, BTN_CORNER, 2, accent * Color(1,1,1, 0.4))
	normal_sb.content_margin_left = 24
	normal_sb.content_margin_right = 24
	normal_sb.content_margin_top = 12
	normal_sb.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", normal_sb)
	
	# Hover
	var hover_sb = _make_stylebox(BTN_HOVER, BTN_CORNER, 2, accent * Color(1,1,1, 0.8))
	hover_sb.content_margin_left = 24
	hover_sb.content_margin_right = 24
	hover_sb.content_margin_top = 12
	hover_sb.content_margin_bottom = 12
	btn.add_theme_stylebox_override("hover", hover_sb)
	
	# Pressed
	var pressed_sb = _make_stylebox(BTN_PRESSED, BTN_CORNER, 2, accent)
	pressed_sb.content_margin_left = 24
	pressed_sb.content_margin_right = 24
	pressed_sb.content_margin_top = 12
	pressed_sb.content_margin_bottom = 12
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	
	# Focus (такой же как hover)
	btn.add_theme_stylebox_override("focus", hover_sb.duplicate())
	
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_color_override("font_hover_color", accent)
	btn.add_theme_color_override("font_pressed_color", accent.lightened(0.2))
	btn.add_theme_font_size_override("font_size", 20)
	
	return btn

func _make_icon_button(icon_text: String, size_px: int = 48) -> Button:
	var btn = _make_button(icon_text, ACCENT_COLOR, size_px)
	btn.custom_minimum_size = Vector2(size_px, size_px)
	btn.add_theme_font_size_override("font_size", 22)
	return btn

func _make_label(text: String, font_size: int = 20, color: Color = TEXT_COLOR) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _make_slider(min_val: float, max_val: float, value: float) -> HSlider:
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = value
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(200, 32)
	
	# Стилизация слайдера
	var grabber_sb = _make_stylebox(ACCENT_COLOR, 8)
	grabber_sb.content_margin_left = 12
	grabber_sb.content_margin_right = 12
	grabber_sb.content_margin_top = 12
	grabber_sb.content_margin_bottom = 12
	slider.add_theme_stylebox_override("grabber_area", _make_stylebox(ACCENT_COLOR.darkened(0.3), 4))
	slider.add_theme_stylebox_override("grabber_area_highlight", _make_stylebox(ACCENT_COLOR.darkened(0.1), 4))
	slider.add_theme_stylebox_override("slider", _make_stylebox(BTN_BG, 4, 1, PANEL_BORDER))
	
	return slider

# ========== ПОСТРОЕНИЕ UI ==========

func _build_background() -> void:
	background = TextureRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = MOUSE_FILTER_IGNORE
	# Заглушка: тёмный фон (замените на свою текстуру)
	add_child(background)

func _build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	add_child(overlay)

func _build_safe_area() -> void:
	safe_area = MarginContainer.new()
	safe_area.name = "SafeArea"
	safe_area.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", 24)
	safe_area.add_theme_constant_override("margin_right", 24)
	safe_area.add_theme_constant_override("margin_top", 16)
	safe_area.add_theme_constant_override("margin_bottom", 16)
	add_child(safe_area)

func _build_main_screen() -> void:
	main_screen = VBoxContainer.new()
	main_screen.name = "MainScreen"
	main_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe_area.add_child(main_screen)
	
	# === TOP BAR ===
	var top_bar = HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.add_theme_constant_override("separation", 8)
	main_screen.add_child(top_bar)
	
	sound_btn = _make_icon_button("🔊", 48)
	sound_btn.tooltip_text = "Звуки вкл/выкл"
	sound_btn.pressed.connect(_on_sound_toggle)
	top_bar.add_child(sound_btn)
	
	music_btn = _make_icon_button("🎵", 48)
	music_btn.tooltip_text = "Музыка вкл/выкл"
	music_btn.pressed.connect(_on_music_toggle)
	top_bar.add_child(music_btn)
	
	# Спейсер — толкает шестерёнку вправо
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	
	settings_btn = _make_icon_button("⚙", 48)
	settings_btn.tooltip_text = "Настройки"
	settings_btn.pressed.connect(_on_settings_open)
	top_bar.add_child(settings_btn)
	
	# === ЦЕНТР: Логотип + Кнопка ===
	var center_spacer_top = Control.new()
	center_spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_spacer_top.size_flags_stretch_ratio = 0.5 # Сдвигаем центр выше
	main_screen.add_child(center_spacer_top)
	
	var center_box = VBoxContainer.new()
	center_box.name = "CenterBox"
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 32)
	center_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_screen.add_child(center_box)
	
	# Заголовок
	title_label = Label.new()
	title_label.text = "CELLCOLONY"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 52)
	title_label.add_theme_color_override("font_color", ACCENT_COLOR)
	# Тень/обводка заголовка
	var title_settings = LabelSettings.new()
	title_settings.font_size = 52
	title_settings.font_color = ACCENT_COLOR
	title_settings.outline_size = 3
	title_settings.outline_color = Color(0, 0, 0, 0.7)
	title_settings.shadow_color = Color(0.1, 0.85, 0.55, 0.3)
	title_settings.shadow_size = 3
	title_settings.shadow_offset = Vector2(0, 3)
	title_label.label_settings = title_settings
	center_box.add_child(title_label)
	
	# Подзаголовок
	var subtitle = _make_label("Стратегия клеточных колоний", 18, TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_box.add_child(subtitle)
	# Обертка-контейнер, которая статична и не дает VBox дёргаться
	var play_container = CenterContainer.new()
	play_container.custom_minimum_size = Vector2(320, 100)
	center_box.add_child(play_container)
	
	# Обёртка для кнопки "ИГРАТЬ", чтобы масштабирование было ТОЧНО из центра и не влияло на VBox
	var play_wrapper = Control.new()
	play_wrapper.custom_minimum_size = Vector2(280, 72)
	play_wrapper.pivot_offset = Vector2(140, 36) # Точный центр для scale
	play_container.add_child(play_wrapper)
	
	# === ВНЕШНЕЕ ПУЛЬСИРУЮЩЕЕ СВЕЧЕНИЕ (Glow) ===
	var play_glow = Panel.new()
	play_glow.name = "PlayGlow"
	play_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_glow.layout_mode = 1
	play_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var glow_sb = StyleBoxFlat.new()
	glow_sb.bg_color = Color(0, 0, 0, 0) # Прозрачный фон, только тень/свечение
	glow_sb.corner_radius_top_left = 24
	glow_sb.corner_radius_top_right = 24
	glow_sb.corner_radius_bottom_left = 24
	glow_sb.corner_radius_bottom_right = 24
	glow_sb.shadow_color = Color(0.1, 0.85, 0.55, 0.6) # Бирюзовое свечение
	glow_sb.shadow_size = 20
	glow_sb.shadow_offset = Vector2(0, 0)
	play_glow.add_theme_stylebox_override("panel", glow_sb)
	play_wrapper.add_child(play_glow)
	
	# Сохраняем в метаданные для анимации
	
	# Градиентный фон (Panel с clip_children для скругления текстуры)
	var play_bg = Panel.new()
	play_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_bg.clip_children = CanvasItem.CLIP_CHILDREN_ONLY # Оставляем только то, что внутри маски
	play_wrapper.add_child(play_bg)
	
	# Маска-рамка (чтобы задать форму для clip_children)
	var mask_sb = StyleBoxFlat.new()
	mask_sb.bg_color = Color(1, 1, 1, 1) # Белый для маски
	mask_sb.corner_radius_top_left = 24
	mask_sb.corner_radius_top_right = 24
	mask_sb.corner_radius_bottom_left = 24
	mask_sb.corner_radius_bottom_right = 24
	play_bg.add_theme_stylebox_override("panel", mask_sb)
	
	# Сама градиентная текстура
	var grad = Gradient.new()
	grad.set_color(0, Color(0.08, 0.45, 0.35, 1.0)) # Темно-бирюзовый
	grad.set_color(1, Color(0.1, 0.45, 0.85, 1.0)) # Неоновый синий
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_LINEAR
	grad_tex.fill_from = Vector2(0, 0)
	grad_tex.fill_to = Vector2(1, 1)
	
	var play_tex = TextureRect.new()
	play_tex.texture = grad_tex
	play_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_bg.add_child(play_tex)
	
	# Сама кнопка (прозрачная с рамкой и тенью)
	play_button = Button.new()
	play_button.text = "▶  ИГРАТЬ"
	play_button.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	play_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var play_normal = _make_stylebox(Color(0,0,0,0), 24, 2, ACCENT_COLOR) # Прозрачная внутри, зелёная рамка
	play_normal.shadow_size = 12
	play_normal.shadow_color = Color(0.1, 0.85, 0.55, 0.35)
	play_button.add_theme_stylebox_override("normal", play_normal)
	
	var play_hover = _make_stylebox(Color(0.2,0.85,0.55,0.15), 24, 3, Color(1,1,1,1))
	play_hover.shadow_size = 20
	play_hover.shadow_color = Color(0.1, 0.85, 0.55, 0.6)
	play_button.add_theme_stylebox_override("hover", play_hover)
	play_button.add_theme_stylebox_override("focus", play_hover.duplicate())
	
	var play_pressed = _make_stylebox(Color(0,0,0,0.5), 24, 4, ACCENT_COLOR)
	play_button.add_theme_stylebox_override("pressed", play_pressed)
	
	play_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	play_button.add_theme_color_override("font_hover_color", Color.WHITE)
	play_button.add_theme_color_override("font_pressed_color", ACCENT_COLOR.lightened(0.5))
	play_button.add_theme_font_size_override("font_size", 32)
	
	play_button.pressed.connect(_on_play_pressed)
	play_button.set_meta("glow", play_glow)
	play_wrapper.add_child(play_button)
	
	var center_spacer_bottom = Control.new()
	center_spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_spacer_bottom.size_flags_stretch_ratio = 1.6 # Толкаем контент вверх
	main_screen.add_child(center_spacer_bottom)
	
	# Версия
	var version_label = _make_label("v0.1  •  Яндекс Игры", 14, Color(0.4, 0.45, 0.5, 0.6))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_screen.add_child(version_label)

# === ПАНЕЛЬ УРОВНЕЙ ===
func _build_level_panel() -> void:
	level_panel = CenterContainer.new()
	level_panel.name = "LevelPanel"
	level_panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	level_panel.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(level_panel)
	
	var panel_box = PanelContainer.new()
	panel_box.name = "LevelPanelBox"
	panel_box.custom_minimum_size = Vector2(420, 480)
	var panel_sb = _make_stylebox(PANEL_BG, CORNER_RADIUS, 2, PANEL_BORDER)
	panel_sb.shadow_size = 16
	panel_sb.shadow_color = Color(0, 0, 0, 0.6)
	panel_sb.content_margin_left = 24
	panel_sb.content_margin_right = 24
	panel_sb.content_margin_top = 20
	panel_sb.content_margin_bottom = 20
	panel_box.add_theme_stylebox_override("panel", panel_sb)
	level_panel.add_child(panel_box)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel_box.add_child(vbox)
	
	# Заголовок
	var header = _make_label("ВЫБОР УРОВНЯ", 26, ACCENT_COLOR)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)
	
	# Разделитель
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", _make_stylebox(PANEL_BORDER * Color(1,1,1,0.3), 0))
	vbox.add_child(sep)
	
	# Скролл для сетки
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	
	level_grid = GridContainer.new()
	level_grid.columns = 3
	level_grid.add_theme_constant_override("h_separation", 12)
	level_grid.add_theme_constant_override("v_separation", 12)
	level_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(level_grid)
	
	_populate_levels()
	
	# Кнопка назад
	level_back_btn = _make_button("← НАЗАД", ACCENT_BLUE)
	level_back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	level_back_btn.pressed.connect(_on_level_back)
	vbox.add_child(level_back_btn)

func _populate_levels() -> void:
	# Очищаем
	for child in level_grid.get_children():
		child.queue_free()
	
	for i in range(total_levels):
		var level_num = i + 1
		var is_unlocked = level_num <= unlocked_levels
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(100, 100)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_unlocked else Control.CURSOR_FORBIDDEN
		
		if is_unlocked:
			btn.text = str(level_num)
			var sb = _make_stylebox(BTN_BG, BTN_CORNER, 2, ACCENT_COLOR * Color(1,1,1,0.6))
			sb.content_margin_top = 8
			sb.content_margin_bottom = 8
			btn.add_theme_stylebox_override("normal", sb)
			
			var hover_sb = _make_stylebox(BTN_HOVER, BTN_CORNER, 2, ACCENT_COLOR)
			hover_sb.shadow_size = 8
			hover_sb.shadow_color = Color(0.1, 0.85, 0.55, 0.3)
			hover_sb.content_margin_top = 8
			hover_sb.content_margin_bottom = 8
			btn.add_theme_stylebox_override("hover", hover_sb)
			
			var pressed_sb = _make_stylebox(BTN_PRESSED, BTN_CORNER, 3, ACCENT_COLOR)
			pressed_sb.content_margin_top = 8
			pressed_sb.content_margin_bottom = 8
			btn.add_theme_stylebox_override("pressed", pressed_sb)
			btn.add_theme_stylebox_override("focus", hover_sb.duplicate())
			
			btn.add_theme_color_override("font_color", ACCENT_COLOR)
			btn.add_theme_color_override("font_hover_color", ACCENT_COLOR.lightened(0.3))
			btn.add_theme_font_size_override("font_size", 28)
			btn.pressed.connect(_on_level_selected.bind(level_num))
		else:
			btn.text = "🔒"
			btn.disabled = true
			var locked_sb = _make_stylebox(Color(0.1, 0.12, 0.15, 0.6), BTN_CORNER, 1, LOCKED_COLOR * Color(1,1,1,0.3))
			locked_sb.content_margin_top = 8
			locked_sb.content_margin_bottom = 8
			btn.add_theme_stylebox_override("normal", locked_sb)
			btn.add_theme_stylebox_override("disabled", locked_sb)
			btn.add_theme_color_override("font_color", LOCKED_COLOR)
			btn.add_theme_color_override("font_disabled_color", LOCKED_COLOR)
			btn.add_theme_font_size_override("font_size", 24)
		
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		level_grid.add_child(btn)

# === ПАНЕЛЬ НАСТРОЕК ===
func _build_settings_panel() -> void:
	settings_panel = CenterContainer.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	settings_panel.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(settings_panel)
	
	var panel_box = PanelContainer.new()
	panel_box.name = "SettingsPanelBox"
	panel_box.custom_minimum_size = Vector2(380, 320)
	var panel_sb = _make_stylebox(PANEL_BG, CORNER_RADIUS, 2, ACCENT_BLUE * Color(1,1,1,0.4))
	panel_sb.shadow_size = 16
	panel_sb.shadow_color = Color(0, 0, 0, 0.6)
	panel_sb.content_margin_left = 32
	panel_sb.content_margin_right = 32
	panel_sb.content_margin_top = 24
	panel_sb.content_margin_bottom = 24
	panel_box.add_theme_stylebox_override("panel", panel_sb)
	settings_panel.add_child(panel_box)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel_box.add_child(vbox)
	
	# Заголовок
	var header = _make_label("⚙  НАСТРОЙКИ", 26, ACCENT_BLUE)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)
	
	# Разделитель
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", _make_stylebox(ACCENT_BLUE * Color(1,1,1,0.2), 0))
	vbox.add_child(sep)
	
	# --- Звуки ---
	var sound_row = HBoxContainer.new()
	sound_row.add_theme_constant_override("separation", 12)
	vbox.add_child(sound_row)
	
	var sound_label = _make_label("🔊  Звуки", 18)
	sound_label.custom_minimum_size.x = 120
	sound_row.add_child(sound_label)
	
	sound_slider = _make_slider(0, 100, sound_volume)
	sound_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_slider.value_changed.connect(_on_sound_volume_changed)
	sound_row.add_child(sound_slider)
	
	sound_value_label = _make_label(str(int(sound_volume)) + "%", 16, TEXT_DIM)
	sound_value_label.custom_minimum_size.x = 48
	sound_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sound_row.add_child(sound_value_label)
	
	# --- Музыка ---
	var music_row = HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 12)
	vbox.add_child(music_row)
	
	var music_label = _make_label("🎵  Музыка", 18)
	music_label.custom_minimum_size.x = 120
	music_row.add_child(music_label)
	
	music_slider = _make_slider(0, 100, music_volume)
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_slider.value_changed.connect(_on_music_volume_changed)
	music_row.add_child(music_slider)
	
	music_value_label = _make_label(str(int(music_volume)) + "%", 16, TEXT_DIM)
	music_value_label.custom_minimum_size.x = 48
	music_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	music_row.add_child(music_value_label)
	
	# Кнопка закрыть
	settings_close_btn = _make_button("✓  ГОТОВО", ACCENT_BLUE)
	settings_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	settings_close_btn.pressed.connect(_on_settings_close)
	vbox.add_child(settings_close_btn)

# ========== АНИМАЦИИ ==========

func _show_panel(panel: Control) -> void:
	overlay.visible = true
	overlay.modulate = Color(1, 1, 1, 0)
	panel.visible = true
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = panel.size / 2.0
	
	var tween = create_tween().set_parallel()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_panel(panel: Control) -> void:
	var tween = create_tween().set_parallel()
	tween.tween_property(overlay, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(panel, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(panel, "scale", Vector2(0.9, 0.9), 0.2).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(func():
		panel.visible = false
		overlay.visible = false
	)

# ========== ОБРАБОТЧИКИ ==========

func _on_play_pressed() -> void:
	_show_panel(level_panel)

func _on_level_selected(level_num: int) -> void:
	print("Выбран уровень: ", level_num)
	# Заглушка: загружаем основную сцену (уровень 1 = текущая карта)
	_hide_panel(level_panel)
	# Небольшая задержка перед переходом
	var tween = create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)

func _on_level_back() -> void:
	_hide_panel(level_panel)

func _on_settings_open() -> void:
	_show_panel(settings_panel)

func _on_settings_close() -> void:
	_hide_panel(settings_panel)

func _on_sound_toggle() -> void:
	is_sound_on = not is_sound_on
	sound_btn.text = "🔊" if is_sound_on else "🔇"
	# Заглушка: управление AudioBus
	_apply_sound_volume()

func _on_music_toggle() -> void:
	is_music_on = not is_music_on
	music_btn.text = "🎵" if is_music_on else "🎵✖"
	# Заглушка: управление AudioBus
	_apply_music_volume()

func _on_sound_volume_changed(value: float) -> void:
	sound_volume = value
	sound_value_label.text = str(int(value)) + "%"
	is_sound_on = value > 0
	sound_btn.text = "🔊" if is_sound_on else "🔇"
	_apply_sound_volume()

func _on_music_volume_changed(value: float) -> void:
	music_volume = value
	music_value_label.text = str(int(value)) + "%"
	is_music_on = value > 0
	music_btn.text = "🎵" if is_music_on else "🎵✖"
	_apply_music_volume()

func _apply_sound_volume() -> void:
	# Заглушка: Здесь будет AudioServer.set_bus_volume_db(...)
	var effective = sound_volume if is_sound_on else 0.0
	var _db = linear_to_db(effective / 100.0) if effective > 0 else -80.0
	# AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db)
	pass

func _apply_music_volume() -> void:
	# Заглушка: Здесь будет AudioServer.set_bus_volume_db(...)
	var effective = music_volume if is_music_on else 0.0
	var _db = linear_to_db(effective / 100.0) if effective > 0 else -80.0
	# AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), db)
	pass

func _input(event: InputEvent) -> void:
	# ESC закрывает открытые панели
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if settings_panel.visible:
			_on_settings_close()
			get_viewport().set_input_as_handled()
		elif level_panel.visible:
			_on_level_back()
			get_viewport().set_input_as_handled()
