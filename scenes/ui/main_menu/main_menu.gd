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

# Неоново-биологическая Glassmorphism палитра экрана выбора уровней
const LEVEL_PANEL_BG := Color(0.06, 0.09, 0.13, 0.96)
const LEVEL_PANEL_BORDER := Color(0.12, 0.75, 0.65, 0.6)
const LEVEL_CHAPTER_BG := Color(0.09, 0.13, 0.18, 0.92)
const LEVEL_CARD_BG := Color(0.12, 0.17, 0.23, 0.94)
const LEVEL_CARD_HOVER := Color(0.16, 0.24, 0.32, 0.98)
const LEVEL_CARD_PRESSED := Color(0.10, 0.14, 0.19, 1.0)
const LEVEL_TEXT := Color(0.95, 0.98, 1.0, 1.0)
const LEVEL_TEXT_DIM := Color(0.62, 0.70, 0.76, 1.0)
const LEVEL_ACCENT := Color(0.14, 0.90, 0.62, 1.0)
const LEVEL_ACCENT_BLUE := Color(0.24, 0.72, 1.0, 1.0)
const LEVEL_ACCENT_GOLD := Color(1.0, 0.82, 0.24, 1.0)
const LEVEL_LOCKED_BG := Color(0.08, 0.10, 0.14, 0.8)
const LEVEL_LOCKED_TEXT := Color(0.42, 0.48, 0.54, 0.8)

const CORNER_RADIUS := 16
const BTN_CORNER := 12
const BTN_MIN_HEIGHT := 56  # Минимальная высота кнопок (удобно для пальца)
const MASTER_BUS_NAME: StringName = &"Master"
const MUSIC_BUS_NAME: StringName = &"Music"
const DEV_CONSOLE_SCENE := preload("res://scenes/ui/dev_console.tscn")
const BUTTON_HOVER_SOUND := preload("res://audio/Button_click.ogg")
const BUTTON_HOVER_VOLUME_DB: float = 0.0
const BUTTON_CLICK_SOUND := preload("res://audio/clickWhooh.ogg")
const BUTTON_CLICK_VOLUME_DB: float = -14.0
const BUTTON_CLICK_PITCH_SCALE: float = 1.8
const SHIELD_ICON := preload("res://assets/sprites/shield.png")
const RAPID_FIRE_ICON := preload("res://assets/sprites/speedfire2.png")
const SPEED_ICON := preload("res://assets/sprites/speed.png")
const LEVEL_MAP_PREVIEW_SCRIPT := preload("res://scripts/ui/level_map_preview.gd")

class MenuPerkIcon extends Control:
	var perk_id: String = ""
	var icon_texture: Texture2D = null
	var icon_color: Color = Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if icon_texture != null:
			draw_texture_rect(icon_texture, rect, false, Color.WHITE)
			return

		if perk_id == "virus":
			var center := size * 0.5
			var s := minf(size.x, size.y) * 0.32
			draw_circle(center, s * 0.68, icon_color)
			for i in range(8):
				var angle := i * PI / 4.0
				var p1 := center + Vector2(cos(angle), sin(angle)) * s * 0.5
				var p2 := center + Vector2(cos(angle), sin(angle)) * s * 1.08
				draw_line(p1, p2, icon_color, 3.4)
			return

const PERK_INFO: Array[Dictionary] = [
	{
		"id": "shield",
		"title": "ЩИТ",
		"subtitle": "Щит колонии",
		"color": Color(0.2, 0.8, 1.0, 1.0),
		"icon": SHIELD_ICON,
		"desc": "Создает защиту вокруг центра колонии и прикрывает соседние клетки. Щит отражает обычные снаряды и помогает пережить вражеский залп.",
		"cost": "50",
		"cooldown": "12с",
	},
	{
		"id": "speed",
		"title": "СПРИНТ",
		"subtitle": "Общий буст",
		"color": Color(1.0, 0.9, 0.1, 1.0),
		"icon": SPEED_ICON,
		"desc": "Временно ускоряет всю колонию. Идеален для маневров, быстрого сближения и резкого нападения, когда нужно навязать бой первым.",
		"cost": "30",
		"cooldown": "18с",
	},
	{
		"id": "rapid_fire",
		"title": "СКОРОСТРЕЛЬНОСТЬ",
		"subtitle": "Темп огня",
		"color": Color(1.0, 0.5, 0.1, 1.0),
		"icon": RAPID_FIRE_ICON,
		"desc": "Временно ускоряет стрельбу всей колонии. Лучше всего раскрывается перед добиванием вражеской группы или во время общего пуша.",
		"cost": "50",
		"cooldown": "15с",
	},
	{
		"id": "virus",
		"title": "ВИРУС",
		"subtitle": "Автоцель",
		"color": Color(1.0, 0.22, 0.26, 1.0),
		"icon": null,
		"desc": "Запускает вирус во врага. Заражение один раз передаётся соседним клеткам его фракции и проходит волной по колонии. Одна волна не заражает клетку повторно, свои клетки невосприимчивы.",
		"cost": "100",
		"cooldown": "20с",
	},
]

# ========== НОДЫ ==========
var background_underlay: TextureRect
var background: TextureRect
var safe_area: MarginContainer
var main_screen: Control
var level_panel: Control
var settings_panel: Control
var perks_panel: Control
var overlay: ColorRect
@onready var menu_music: AudioStreamPlayer = $MenuMusic
var ui_hover_sfx: AudioStreamPlayer
var ui_click_sfx: AudioStreamPlayer

# Кнопки верхней панели
var sound_btn: Button
var sound_cross: Label
var settings_btn: Button
var perks_btn: Button

# Центр
var title_label: Label
var play_button: Button
var play_pulse_tween: Tween

# Уровни
var level_list: VBoxContainer
var level_back_btn: Button
var level_panel_box: PanelContainer
var level_header_stars_label: Label
var level_close_top_btn: Button
var level_grid_columns: int = 5
var difficulty_panel: Control
var pending_level_num: int = 1
var level_ui_font: SystemFont

# Настройки
var sound_slider: HSlider
var music_slider: HSlider
var sound_value_label: Label
var music_value_label: Label
var settings_close_btn: Button
var perks_desc_title: Label
var perks_desc_body: Label
var perks_desc_meta: Label
var perk_card_buttons: Dictionary = {}
var selected_perk_id: String = "shield"

# Состояние
var is_sound_on: bool = true
var is_music_on: bool = true
var sound_volume: float = 80.0
var music_volume: float = 80.0
var total_levels: int = 4
var unlocked_levels: int = 1

func _ready() -> void:
	_sync_audio_state_from_buses()
	_setup_ui_hover_sound()
	_setup_ui_click_sound()
	if has_node("/root/LevelManager"):
		var lm: Node = get_node("/root/LevelManager")
		unlocked_levels = lm.unlocked_levels
		total_levels = lm.get_total_levels()
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
	_build_difficulty_panel()
	_build_settings_panel()
	_build_perks_panel()
	_build_dev_console()
	
	# Элементы основного экрана (начальное состояние)
	level_panel.visible = false
	difficulty_panel.visible = false
	settings_panel.visible = false
	perks_panel.visible = false
	overlay.visible = false
	call_deferred("_open_pending_level_selection")
	
	# Запускаем пульсацию СВЕЧЕНИЯ и РАЗМЕРА
	if play_button.has_meta("glow") and play_button.has_meta("wrapper"):
		var glow = play_button.get_meta("glow")
		
		var t = create_tween().set_loops().set_parallel(true)
		# Пульсация свечения
		t.tween_property(glow, "modulate:a", 0.75, 1.7).from(0.4)
		t.chain().tween_property(glow, "modulate:a", 0.4, 1.7)

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
	_attach_hover_sound(btn)
	_attach_click_sound(btn)
	
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
	background_underlay = TextureRect.new()
	background_underlay.name = "BackgroundUnderlay"
	background_underlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	background_underlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_underlay.stretch_mode = TextureRect.STRETCH_SCALE
	background_underlay.mouse_filter = MOUSE_FILTER_IGNORE
	background_underlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background_underlay.texture = load("res://assets/background/backgraund3.jpg")
	add_child(background_underlay)

	background = TextureRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	# Для меню важнее показать весь арт целиком, чем агрессивно обрезать его по высоте.
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.mouse_filter = MOUSE_FILTER_IGNORE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	
	background.texture = load("res://assets/background/cellbackgraund4.png")
	add_child(background)
	
	_build_fire_particles()

func _build_fire_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.name = "FireParticles"
	
	# Настройка спавнера по низу экрана
	var vp_size = get_viewport_rect().size
	particles.position = Vector2(vp_size.x / 2.0, vp_size.y)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(vp_size.x / 2.0, 20.0)
	
	# Настройки физики (искры взлетают вверх)
	particles.amount = 80
	particles.lifetime = 2.5
	particles.randomness = 0.5
	particles.direction = Vector2(0, -1)
	particles.spread = 20.0
	particles.gravity = Vector2(0, -80)
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 250.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 6.0
	
	# Градиент цвета от ярко-желтого к прозрачно-красному
	var c_grad = Gradient.new()
	c_grad.set_color(0, Color(1.0, 0.9, 0.4, 1.0))
	c_grad.set_color(1, Color(1.0, 0.2, 0.0, 0.0))
	particles.color_ramp = c_grad
	
	background.add_child(particles)
	
	# Чтобы искры корректно обновлялись при ресайзе окна
	get_tree().root.size_changed.connect(func():
		particles.position = Vector2(get_viewport_rect().size.x / 2.0, get_viewport_rect().size.y)
		particles.emission_rect_extents = Vector2(get_viewport_rect().size.x / 2.0, 20.0)
	)

func _build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	add_child(overlay)

func _build_dev_console() -> void:
	if DEV_CONSOLE_SCENE == null:
		return
	var dev_console := DEV_CONSOLE_SCENE.instantiate()
	dev_console.name = "DevConsole"
	add_child(dev_console)

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
	
	# === ЦЕНТР: Логотип + Кнопка ===
	var center_spacer_top = Control.new()
	center_spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_spacer_top.size_flags_stretch_ratio = 1.35 # Опускаем главный блок еще ниже
	main_screen.add_child(center_spacer_top)
	
	var center_box = VBoxContainer.new()
	center_box.name = "CenterBox"
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 32)
	center_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_screen.add_child(center_box)

	var buttons_offset = Control.new()
	buttons_offset.custom_minimum_size = Vector2(0, 200)
	center_box.add_child(buttons_offset)
	
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

	var play_membrane = preload("res://scripts/ui/play_button_membrane.gd").new()
	play_membrane.name = "PlayMembrane"
	play_membrane.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	play_membrane.offset_left = -18.0
	play_membrane.offset_top = -14.0
	play_membrane.offset_right = 18.0
	play_membrane.offset_bottom = 14.0
	play_membrane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_wrapper.add_child(play_membrane)
	
	# Сама кнопка (прозрачная с рамкой и тенью)
	play_button = Button.new()
	play_button.text = "▶  ИГРАТЬ"
	play_button.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	play_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var play_normal = _make_stylebox(Color(0,0,0,0), 24)
	play_normal.shadow_size = 12
	play_normal.shadow_color = Color(0.1, 0.85, 0.55, 0.35)
	play_button.add_theme_stylebox_override("normal", play_normal)
	
	var play_hover = _make_stylebox(Color(0.2,0.85,0.55,0.12), 24)
	play_hover.shadow_size = 20
	play_hover.shadow_color = Color(0.1, 0.85, 0.55, 0.6)
	play_button.add_theme_stylebox_override("hover", play_hover)
	play_button.add_theme_stylebox_override("focus", play_hover.duplicate())
	
	var play_pressed = _make_stylebox(Color(0,0,0,0.5), 24)
	play_pressed.shadow_size = 10
	play_pressed.shadow_color = Color(0.1, 0.85, 0.55, 0.2)
	play_button.add_theme_stylebox_override("pressed", play_pressed)
	
	play_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	play_button.add_theme_color_override("font_hover_color", Color.WHITE)
	play_button.add_theme_color_override("font_pressed_color", ACCENT_COLOR.lightened(0.5))
	play_button.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.08, 0.96))
	play_button.add_theme_constant_override("outline_size", 9)
	play_button.add_theme_font_size_override("font_size", 32)
	
	play_button.pressed.connect(_on_play_pressed)
	_attach_hover_sound(play_button)
	_attach_click_sound(play_button)
	play_button.mouse_entered.connect(func(): play_membrane.set_hovered(true))
	play_button.mouse_exited.connect(func(): play_membrane.set_hovered(false))
	play_button.set_meta("glow", play_glow)
	play_button.set_meta("wrapper", play_wrapper)
	play_wrapper.add_child(play_button)
	
	# Кнопка настроек под игрой
	var settings_container = CenterContainer.new()
	settings_container.custom_minimum_size = Vector2(280, 82)
	center_box.add_child(settings_container)

	var settings_wrapper = Control.new()
	settings_wrapper.custom_minimum_size = Vector2(240, 60)
	settings_wrapper.pivot_offset = Vector2(120, 30)
	settings_container.add_child(settings_wrapper)

	var settings_membrane = preload("res://scripts/ui/play_button_membrane.gd").new()
	settings_membrane.name = "SettingsMembrane"
	settings_membrane.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	settings_membrane.offset_left = -10.0
	settings_membrane.offset_top = -8.0
	settings_membrane.offset_right = 10.0
	settings_membrane.offset_bottom = 8.0
	settings_membrane.thickness_scale = 0.58
	settings_membrane.outer_glow_color = Color(0.08, 0.34, 0.62, 0.12)
	settings_membrane.flesh_color = Color(0.05, 0.16, 0.32, 0.82)
	settings_membrane.edge_color = Color(0.22, 0.62, 1.0, 0.72)
	settings_membrane.highlight_color = Color(0.76, 0.9, 1.0, 0.28)
	settings_membrane.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var settings_bg = Panel.new()
	settings_bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	settings_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_bg.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	settings_wrapper.add_child(settings_bg)

	var settings_mask_sb = StyleBoxFlat.new()
	settings_mask_sb.bg_color = Color(1, 1, 1, 1)
	settings_mask_sb.corner_radius_top_left = 20
	settings_mask_sb.corner_radius_top_right = 20
	settings_mask_sb.corner_radius_bottom_left = 20
	settings_mask_sb.corner_radius_bottom_right = 20
	settings_bg.add_theme_stylebox_override("panel", settings_mask_sb)

	var settings_grad = Gradient.new()
	settings_grad.set_color(0, Color(0.06, 0.22, 0.34, 1.0))
	settings_grad.set_color(1, Color(0.08, 0.36, 0.68, 1.0))
	var settings_grad_tex = GradientTexture2D.new()
	settings_grad_tex.gradient = settings_grad
	settings_grad_tex.fill = GradientTexture2D.FILL_LINEAR
	settings_grad_tex.fill_from = Vector2(0, 0)
	settings_grad_tex.fill_to = Vector2(1, 1)

	var settings_tex = TextureRect.new()
	settings_tex.texture = settings_grad_tex
	settings_tex.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	settings_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_bg.add_child(settings_tex)

	settings_wrapper.add_child(settings_membrane)

	settings_btn = _make_button("⚙  НАСТРОЙКИ", ACCENT_BLUE)
	settings_btn.custom_minimum_size = Vector2(240, 60)
	settings_btn.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var settings_normal = _make_stylebox(Color(0.0, 0.0, 0.0, 0.0), 20)
	settings_normal.shadow_size = 8
	settings_normal.shadow_color = Color(0.08, 0.34, 0.62, 0.16)
	settings_btn.add_theme_stylebox_override("normal", settings_normal)

	var settings_hover = _make_stylebox(Color(0.16, 0.5, 0.9, 0.1), 20)
	settings_hover.shadow_size = 12
	settings_hover.shadow_color = Color(0.14, 0.52, 1.0, 0.24)
	settings_btn.add_theme_stylebox_override("hover", settings_hover)
	settings_btn.add_theme_stylebox_override("focus", settings_hover.duplicate())

	var settings_pressed = _make_stylebox(Color(0.0, 0.08, 0.18, 0.28), 20)
	settings_pressed.shadow_size = 6
	settings_pressed.shadow_color = Color(0.08, 0.34, 0.62, 0.2)
	settings_btn.add_theme_stylebox_override("pressed", settings_pressed)

	settings_btn.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	settings_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	settings_btn.add_theme_color_override("font_pressed_color", ACCENT_BLUE.lightened(0.45))
	settings_btn.pressed.connect(_on_settings_open)
	settings_btn.mouse_entered.connect(func(): settings_membrane.set_hovered(true))
	settings_btn.mouse_exited.connect(func(): settings_membrane.set_hovered(false))
	settings_wrapper.add_child(settings_btn)

	var perks_container = CenterContainer.new()
	perks_container.custom_minimum_size = Vector2(220, 74)
	center_box.add_child(perks_container)

	perks_btn = _make_button("✦  ПЕРКИ", Color(0.92, 0.78, 0.28, 1.0))
	perks_btn.custom_minimum_size = Vector2(220, 56)
	perks_btn.pressed.connect(_on_perks_open)
	perks_container.add_child(perks_btn)

	var sound_container = CenterContainer.new()
	sound_container.custom_minimum_size = Vector2(120, 96)
	center_box.add_child(sound_container)

	sound_btn = _make_icon_button("🔊", 72)
	sound_btn.tooltip_text = "Все звуки и музыка вкл/выкл"
	sound_btn.pressed.connect(_on_sound_toggle)
	sound_container.add_child(sound_btn)

	sound_cross = _make_label("✕", 44, Color(1.0, 0.3, 0.35, 1.0))
	sound_cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sound_cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sound_cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sound_cross.add_theme_constant_override("outline_size", 8)
	sound_cross.add_theme_color_override("font_outline_color", Color.BLACK)
	sound_cross.mouse_filter = MOUSE_FILTER_IGNORE
	sound_cross.visible = not is_sound_on
	sound_btn.add_child(sound_cross)

	
	var center_spacer_bottom = Control.new()
	center_spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_spacer_bottom.size_flags_stretch_ratio = 1.1
	main_screen.add_child(center_spacer_bottom)
	
	# Версия
	var version_label = _make_label("v1.0", 24, Color(0.4, 0.45, 0.5, 0.8))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_screen.add_child(version_label)

# === ПАНЕЛЬ УРОВНЕЙ ===
func _build_level_panel() -> void:
	level_panel = CenterContainer.new()
	level_panel.name = "LevelPanel"
	level_panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	level_panel.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(level_panel)
	
	level_panel_box = PanelContainer.new()
	level_panel_box.name = "LevelPanelBox"
	level_ui_font = SystemFont.new()
	level_ui_font.font_names = PackedStringArray(["Trebuchet MS", "Segoe UI", "Arial"])
	level_ui_font.font_weight = 600
	var level_theme := Theme.new()
	level_theme.default_font = level_ui_font
	level_panel_box.theme = level_theme

	var panel_sb = _make_stylebox(LEVEL_PANEL_BG, 24, 2, LEVEL_PANEL_BORDER)
	panel_sb.shadow_size = 32
	panel_sb.shadow_color = Color(0.04, 0.26, 0.22, 0.38) # Изумрудный био-glow
	panel_sb.content_margin_left = 24
	panel_sb.content_margin_right = 24
	panel_sb.content_margin_top = 20
	panel_sb.content_margin_bottom = 20
	level_panel_box.add_theme_stylebox_override("panel", panel_sb)
	level_panel.add_child(level_panel_box)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	level_panel_box.add_child(vbox)
	
	# Шапка окна: Заголовок + Бейдж звезд + Кнопка закрытия ✖
	var header_bar = HBoxContainer.new()
	header_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	header_bar.add_theme_constant_override("separation", 12)
	vbox.add_child(header_bar)

	var title_box = HBoxContainer.new()
	title_box.add_theme_constant_override("separation", 10)
	header_bar.add_child(title_box)

	var title_icon = _make_label("🧬", 28, LEVEL_ACCENT)
	title_box.add_child(title_icon)

	var header = _make_label("ВЫБОР УРОВНЯ", 30, LEVEL_TEXT)
	var head_set = LabelSettings.new()
	head_set.font = level_ui_font
	head_set.font_size = 30
	head_set.font_color = LEVEL_TEXT
	head_set.shadow_color = LEVEL_ACCENT * Color(1, 1, 1, 0.35)
	head_set.shadow_size = 8
	header.label_settings = head_set
	title_box.add_child(header)

	var header_spacer = Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_bar.add_child(header_spacer)

	# Звездный бейдж кампании
	var stars_badge = PanelContainer.new()
	var stars_badge_sb = _make_stylebox(Color(0.11, 0.16, 0.22, 0.92), 14, 1, LEVEL_ACCENT_GOLD * Color(1, 1, 1, 0.55))
	stars_badge_sb.content_margin_left = 14
	stars_badge_sb.content_margin_right = 14
	stars_badge_sb.content_margin_top = 6
	stars_badge_sb.content_margin_bottom = 6
	stars_badge_sb.shadow_size = 6
	stars_badge_sb.shadow_color = Color(0.85, 0.6, 0.1, 0.2)
	stars_badge.add_theme_stylebox_override("panel", stars_badge_sb)
	header_bar.add_child(stars_badge)

	level_header_stars_label = _make_label("⭐ 0 / 90", 18, LEVEL_ACCENT_GOLD)
	var badge_settings = LabelSettings.new()
	badge_settings.font = level_ui_font
	badge_settings.font_size = 18
	badge_settings.font_color = LEVEL_ACCENT_GOLD
	badge_settings.shadow_color = Color(0, 0, 0, 0.5)
	badge_settings.shadow_size = 2
	level_header_stars_label.label_settings = badge_settings
	stars_badge.add_child(level_header_stars_label)

	# Кнопка закрытия ✖ в правом верхнем углу (для мобильных и ПК)
	level_close_top_btn = Button.new()
	level_close_top_btn.text = "✖"
	level_close_top_btn.custom_minimum_size = Vector2(40, 40)
	level_close_top_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	level_close_top_btn.add_theme_font_size_override("font_size", 18)
	var close_norm_sb = _make_stylebox(Color(0.14, 0.18, 0.24, 0.9), 12, 1, Color(1, 1, 1, 0.18))
	var close_hover_sb = _make_stylebox(Color(0.35, 0.15, 0.18, 0.95), 12, 2, ACCENT_RED)
	close_hover_sb.shadow_size = 8
	close_hover_sb.shadow_color = ACCENT_RED * Color(1, 1, 1, 0.4)
	level_close_top_btn.add_theme_stylebox_override("normal", close_norm_sb)
	level_close_top_btn.add_theme_stylebox_override("hover", close_hover_sb)
	level_close_top_btn.add_theme_stylebox_override("focus", close_hover_sb.duplicate())
	level_close_top_btn.add_theme_stylebox_override("pressed", _make_stylebox(Color(0.25, 0.10, 0.12, 1.0), 12, 2, ACCENT_RED))
	_attach_hover_sound(level_close_top_btn)
	_attach_click_sound(level_close_top_btn)
	level_close_top_btn.pressed.connect(_on_level_back)
	header_bar.add_child(level_close_top_btn)

	# Разделитель
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", _make_stylebox(LEVEL_PANEL_BORDER * Color(1, 1, 1, 0.45), 0))
	vbox.add_child(sep)

	# Скролл для сетки
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_style_level_scrollbar(scroll)

	var scroll_margin = MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_left", 10)
	scroll_margin.add_theme_constant_override("margin_right", 12)
	scroll_margin.add_theme_constant_override("margin_top", 10)
	scroll_margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(scroll_margin)

	level_list = VBoxContainer.new()
	level_list.add_theme_constant_override("separation", 22)
	level_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_child(level_list)

	# Нижняя панель с кнопкой назад
	var footer_box = HBoxContainer.new()
	footer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(footer_box)

	level_back_btn = _make_button("← НАЗАД В МЕНЮ", LEVEL_ACCENT_BLUE)
	_apply_level_back_button_style(level_back_btn)
	level_back_btn.custom_minimum_size = Vector2(280, 54)
	level_back_btn.add_theme_font_size_override("font_size", 20)
	level_back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	level_back_btn.pressed.connect(_on_level_back)
	footer_box.add_child(level_back_btn)

	# Подключение к ресайзу экрана для адаптивности
	get_tree().root.size_changed.connect(_update_level_panel_responsive)
	_update_level_panel_responsive()
	_populate_levels()

func _update_level_panel_responsive() -> void:
	if level_panel_box == null:
		return
	var vp_size := get_viewport_rect().size
	# Адаптация под мобильные экраны и десктоп
	var target_w := clampf(vp_size.x * 0.94, 320.0, 980.0)
	var target_h := clampf(vp_size.y * 0.90, 420.0, 750.0)
	level_panel_box.custom_minimum_size = Vector2(target_w, target_h)

	var inner_w := target_w - 76.0
	var target_cols := 5
	if inner_w < 480.0:
		target_cols = 3
	elif inner_w < 680.0:
		target_cols = 4
	else:
		target_cols = 5

	if target_cols != level_grid_columns:
		level_grid_columns = target_cols
		if level_list != null and level_list.get_child_count() > 0:
			_populate_levels()

func _style_level_scrollbar(scroll: ScrollContainer) -> void:
	var scrollbar := scroll.get_v_scroll_bar()
	scrollbar.custom_minimum_size.x = 22
	var track := _make_stylebox(Color(0.08, 0.11, 0.15, 0.7), 11, 1, Color(0.2, 0.3, 0.38, 0.3))
	var grabber := _make_stylebox(LEVEL_ACCENT_BLUE * Color(1, 1, 1, 0.8), 11)
	var grabber_hover := _make_stylebox(LEVEL_ACCENT_BLUE, 11)
	var grabber_pressed := _make_stylebox(LEVEL_ACCENT, 11)
	scrollbar.add_theme_stylebox_override("scroll", track)
	scrollbar.add_theme_stylebox_override("scroll_focus", track.duplicate())
	scrollbar.add_theme_stylebox_override("grabber", grabber)
	scrollbar.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	scrollbar.add_theme_stylebox_override("grabber_pressed", grabber_pressed)

func _apply_level_back_button_style(button: Button) -> void:
	button.add_theme_color_override("font_color", LEVEL_TEXT)
	button.add_theme_color_override("font_hover_color", LEVEL_TEXT)
	button.add_theme_color_override("font_pressed_color", LEVEL_TEXT)
	var normal := _make_stylebox(LEVEL_CARD_BG, 18, 1, LEVEL_PANEL_BORDER * Color(1, 1, 1, 0.5))
	normal.shadow_size = 8
	normal.shadow_color = Color(0.04, 0.08, 0.12, 0.25)
	var hover := _make_stylebox(LEVEL_CARD_HOVER, 18, 2, LEVEL_ACCENT_BLUE)
	hover.shadow_size = 14
	hover.shadow_color = LEVEL_ACCENT_BLUE * Color(1, 1, 1, 0.3)
	var pressed := _make_stylebox(LEVEL_CARD_PRESSED, 18, 2, LEVEL_ACCENT_BLUE)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover.duplicate())
	button.add_theme_stylebox_override("pressed", pressed)

func _populate_levels() -> void:
	if level_list == null:
		return
	for child in level_list.get_children():
		child.queue_free()

	var level_manager := get_node_or_null("/root/LevelManager")
	var total_stars_now := 0
	if level_manager != null:
		total_stars_now = int(level_manager.get_total_stars())
	var max_stars := total_levels * 3
	if level_header_stars_label != null:
		level_header_stars_label.text = "⭐ %d / %d" % [total_stars_now, max_stars]

	var chapters := int(ceili(float(total_levels) / 5.0))
	for chapter_index in range(1, chapters + 1):
		var chapter_panel := PanelContainer.new()
		chapter_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var chapter_sb := _make_stylebox(LEVEL_CHAPTER_BG, 18, 1, LEVEL_PANEL_BORDER * Color(1, 1, 1, 0.4))
		chapter_sb.content_margin_left = 16
		chapter_sb.content_margin_right = 16
		chapter_sb.content_margin_top = 14
		chapter_sb.content_margin_bottom = 16
		chapter_sb.shadow_size = 10
		chapter_sb.shadow_color = Color(0.04, 0.08, 0.12, 0.35)
		chapter_panel.add_theme_stylebox_override("panel", chapter_sb)
		level_list.add_child(chapter_panel)

		var chapter_box := VBoxContainer.new()
		chapter_box.add_theme_constant_override("separation", 12)
		chapter_panel.add_child(chapter_box)

		var chapter_unlocked := true
		var required_stars := 0
		if level_manager != null:
			chapter_unlocked = bool(level_manager.is_chapter_unlocked(chapter_index))
			required_stars = int(level_manager.get_required_stars_for_chapter(chapter_index))

		var start_level := (chapter_index - 1) * 5 + 1
		var end_level := mini(chapter_index * 5, total_levels)

		# Подсчет звезд в данной главе
		var chapter_stars := 0
		for lvl in range(start_level, end_level + 1):
			if level_manager != null:
				chapter_stars += int(level_manager.get_level_best_stars(lvl))
		var chapter_max_stars := (end_level - start_level + 1) * 3

		# Шапка главы: Название слева, прогресс справа
		var ch_head_row := HBoxContainer.new()
		ch_head_row.alignment = BoxContainer.ALIGNMENT_CENTER
		chapter_box.add_child(ch_head_row)

		var ch_left_box := VBoxContainer.new()
		ch_left_box.add_theme_constant_override("separation", 2)
		ch_head_row.add_child(ch_left_box)

		var chapter_title_color := LEVEL_ACCENT_BLUE if chapter_unlocked else LEVEL_LOCKED_TEXT
		var chapter_title = _make_label("ГЛАВА %d" % chapter_index, 22, chapter_title_color)
		chapter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		ch_left_box.add_child(chapter_title)

		var subtitle_text := "Уровни %d-%d" % [start_level, end_level]
		var subtitle = _make_label(subtitle_text, 15, LEVEL_TEXT_DIM)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		ch_left_box.add_child(subtitle)

		var ch_spacer := Control.new()
		ch_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ch_head_row.add_child(ch_spacer)

		# Звездный чип главы
		var ch_stars_chip := PanelContainer.new()
		var chip_border := (LEVEL_ACCENT_GOLD if chapter_unlocked else LEVEL_LOCKED_TEXT) * Color(1, 1, 1, 0.4)
		var chip_sb := _make_stylebox(Color(0.06, 0.10, 0.14, 0.8), 10, 1, chip_border)
		chip_sb.content_margin_left = 10
		chip_sb.content_margin_right = 10
		chip_sb.content_margin_top = 4
		chip_sb.content_margin_bottom = 4
		ch_stars_chip.add_theme_stylebox_override("panel", chip_sb)
		ch_head_row.add_child(ch_stars_chip)

		var chip_color := LEVEL_ACCENT_GOLD if chapter_unlocked else LEVEL_LOCKED_TEXT
		var chip_text := "⭐ %d / %d" % [chapter_stars, chapter_max_stars]
		var chip_lbl := _make_label(chip_text, 15, chip_color)
		ch_stars_chip.add_child(chip_lbl)

		if not chapter_unlocked:
			var locked_panel := PanelContainer.new()
			var lock_sb := _make_stylebox(Color(0.24, 0.08, 0.10, 0.6), 10, 1, Color(1.0, 0.35, 0.35, 0.45))
			lock_sb.content_margin_left = 12
			lock_sb.content_margin_right = 12
			lock_sb.content_margin_top = 6
			lock_sb.content_margin_bottom = 6
			locked_panel.add_theme_stylebox_override("panel", lock_sb)
			chapter_box.add_child(locked_panel)

			var lock_text := "🔒 Глава откроется при достижении %d ⭐ (нужно еще %d)" % [required_stars, max(0, required_stars - total_stars_now)]
			var locked_hint = _make_label(lock_text, 15, Color(1.0, 0.65, 0.65, 0.95))
			locked_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			locked_panel.add_child(locked_hint)

		var chapter_grid = GridContainer.new()
		chapter_grid.columns = level_grid_columns
		chapter_grid.add_theme_constant_override("h_separation", 14)
		chapter_grid.add_theme_constant_override("v_separation", 14)
		chapter_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chapter_box.add_child(chapter_grid)

		for level_num in range(start_level, end_level + 1):
			var is_available := level_num <= unlocked_levels
			if level_manager != null:
				is_available = bool(level_manager.is_level_available(level_num))
			chapter_grid.add_child(_build_level_button(level_num, is_available))

func _build_level_button(level_num: int, is_unlocked: bool) -> Button:
	var level_manager := get_node_or_null("/root/LevelManager")
	var best_stars := 0
	if level_manager != null:
		best_stars = int(level_manager.get_level_best_stars(level_num))
	var stars_text := _stars_to_text(best_stars)

	var is_current_target := is_unlocked and (level_num == unlocked_levels)

	var btn = Button.new()
	# Увеличенная высота карточки для отличного отображения номера, карты и звезд
	btn.custom_minimum_size = Vector2(96, 144)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_unlocked else Control.CURSOR_FORBIDDEN

	# 1. Верхний бейдж номера уровня
	var num_pill := PanelContainer.new()
	num_pill.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	num_pill.position = Vector2(6, 6)
	num_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var num_pill_border := (LEVEL_ACCENT * Color(1, 1, 1, 0.8)) if is_current_target else (LEVEL_PANEL_BORDER * Color(1, 1, 1, 0.5) if is_unlocked else Color(1, 1, 1, 0.12))
	var num_pill_sb := _make_stylebox(Color(0.04, 0.08, 0.12, 0.85), 8, 1, num_pill_border)
	num_pill_sb.content_margin_left = 7
	num_pill_sb.content_margin_right = 7
	num_pill_sb.content_margin_top = 2
	num_pill_sb.content_margin_bottom = 2
	num_pill.add_theme_stylebox_override("panel", num_pill_sb)

	var num_lbl := Label.new()
	num_lbl.text = str(level_num)
	num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var num_settings := LabelSettings.new()
	num_settings.font = level_ui_font
	num_settings.font_size = 15
	num_settings.font_color = LEVEL_ACCENT if is_current_target else (LEVEL_TEXT if is_unlocked else LEVEL_LOCKED_TEXT)
	num_settings.shadow_color = Color(0, 0, 0, 0.6)
	num_settings.shadow_offset = Vector2(0, 1)
	num_lbl.label_settings = num_settings
	num_pill.add_child(num_lbl)

	# 2. Центральная иконка (полупрозрачный ▶ для текущего, 🔒 для закрытого)
	var icon_lbl := Label.new()
	icon_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_lbl.offset_top = 26
	icon_lbl.offset_bottom = -32
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 3. Нижний стеклянный трей звезд
	var stars_tray := PanelContainer.new()
	stars_tray.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	stars_tray.custom_minimum_size.y = 26
	stars_tray.offset_left = 6
	stars_tray.offset_right = -6
	stars_tray.offset_bottom = -6
	stars_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tray_border := (LEVEL_ACCENT_GOLD * Color(1, 1, 1, 0.5)) if best_stars > 0 else (LEVEL_PANEL_BORDER * Color(1, 1, 1, 0.3) if is_unlocked else Color(1, 1, 1, 0.08))
	var tray_sb := _make_stylebox(Color(0.03, 0.06, 0.10, 0.88), 9, 1, tray_border)
	tray_sb.content_margin_left = 4
	tray_sb.content_margin_right = 4
	tray_sb.content_margin_top = 2
	tray_sb.content_margin_bottom = 2
	stars_tray.add_theme_stylebox_override("panel", tray_sb)

	var stars_lbl := Label.new()
	stars_lbl.text = stars_text
	stars_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stars_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var stars_set := LabelSettings.new()
	stars_set.font = level_ui_font
	stars_set.font_size = 15
	if best_stars > 0:
		stars_set.font_color = LEVEL_ACCENT_GOLD
		stars_set.outline_size = 1
		stars_set.outline_color = Color(0.35, 0.22, 0.04, 0.9)
		stars_set.shadow_color = Color(1.0, 0.72, 0.15, 0.4)
		stars_set.shadow_size = 4
	else:
		stars_set.font_color = Color(0.48, 0.56, 0.62, 0.45)
	stars_lbl.label_settings = stars_set
	stars_tray.add_child(stars_lbl)

	if is_unlocked:
		_attach_hover_sound(btn)
		_attach_click_sound(btn)

		var preview_ctrl := LEVEL_MAP_PREVIEW_SCRIPT.new() as LevelMapPreview
		var lvl_data: Dictionary = {}
		if level_manager != null:
			lvl_data = level_manager.get_level_data(level_num)
		preview_ctrl.setup(lvl_data)
		preview_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview_ctrl.offset_left = 3
		preview_ctrl.offset_right = -3
		preview_ctrl.offset_top = 26
		preview_ctrl.offset_bottom = -30
		preview_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(preview_ctrl)

		icon_lbl.text = "▶"
		icon_lbl.add_theme_font_size_override("font_size", 36)
		icon_lbl.add_theme_color_override("font_color", LEVEL_ACCENT)

		if is_current_target:
			icon_lbl.visible = true
			icon_lbl.modulate = Color(1.0, 1.0, 1.0, 0.3)
		else:
			icon_lbl.visible = false
			icon_lbl.modulate = Color(1.0, 1.0, 1.0, 0.0)

		btn.mouse_entered.connect(func():
			btn.pivot_offset = btn.size * 0.5
			icon_lbl.visible = true
			var t = btn.create_tween()
			t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(btn, "modulate", Color(1.05, 1.05, 1.05, 1.0), 0.15)
			t.parallel().tween_property(icon_lbl, "modulate:a", 0.85, 0.15)
		)
		btn.mouse_exited.connect(func():
			btn.pivot_offset = btn.size * 0.5
			var target_alpha: float = 0.3 if is_current_target else 0.0
			var t = btn.create_tween()
			t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			t.parallel().tween_property(btn, "modulate", Color.WHITE, 0.12)
			t.parallel().tween_property(icon_lbl, "modulate:a", target_alpha, 0.12)
			if not is_current_target:
				t.tween_callback(func(): if is_instance_valid(icon_lbl) and not btn.is_hovered(): icon_lbl.visible = false)
		)
		btn.pressed.connect(_open_difficulty_panel.bind(level_num))

		if is_current_target:
			var active_sb = _make_stylebox(Color(0.09, 0.16, 0.20, 0.96), 16, 2, LEVEL_ACCENT)
			active_sb.shadow_size = 14
			active_sb.shadow_color = LEVEL_ACCENT * Color(1, 1, 1, 0.4)
			btn.add_theme_stylebox_override("normal", active_sb)

			var active_hover_sb = _make_stylebox(Color(0.12, 0.22, 0.26, 1.0), 16, 3, LEVEL_ACCENT)
			active_hover_sb.shadow_size = 18
			active_hover_sb.shadow_color = LEVEL_ACCENT * Color(1, 1, 1, 0.6)
			btn.add_theme_stylebox_override("hover", active_hover_sb)
			btn.add_theme_stylebox_override("pressed", _make_stylebox(Color(0.07, 0.12, 0.15, 1.0), 16, 3, LEVEL_ACCENT))
			btn.add_theme_stylebox_override("focus", active_hover_sb.duplicate())
		else:
			var normal_sb = _make_stylebox(LEVEL_CARD_BG, 16, 1, LEVEL_PANEL_BORDER * Color(1, 1, 1, 0.4))
			normal_sb.shadow_size = 6
			normal_sb.shadow_color = Color(0.04, 0.08, 0.12, 0.25)
			btn.add_theme_stylebox_override("normal", normal_sb)

			var hover_sb = _make_stylebox(LEVEL_CARD_HOVER, 16, 2, LEVEL_ACCENT_BLUE)
			hover_sb.shadow_size = 12
			hover_sb.shadow_color = LEVEL_ACCENT_BLUE * Color(1, 1, 1, 0.3)
			btn.add_theme_stylebox_override("hover", hover_sb)
			btn.add_theme_stylebox_override("pressed", _make_stylebox(LEVEL_CARD_PRESSED, 16, 2, LEVEL_ACCENT_BLUE))
			btn.add_theme_stylebox_override("focus", hover_sb.duplicate())
	else:
		icon_lbl.offset_top = 0
		icon_lbl.offset_bottom = 0
		icon_lbl.text = "🔒"
		icon_lbl.add_theme_font_size_override("font_size", 34)
		icon_lbl.add_theme_color_override("font_color", LEVEL_LOCKED_TEXT)
		stars_tray.visible = false
		btn.disabled = true

		var locked_sb = _make_stylebox(LEVEL_LOCKED_BG, 16, 1, Color(1, 1, 1, 0.08))
		btn.add_theme_stylebox_override("normal", locked_sb)
		btn.add_theme_stylebox_override("disabled", locked_sb)

	btn.add_child(icon_lbl)
	btn.add_child(num_pill)
	btn.add_child(stars_tray)
	return btn

func _setup_ui_hover_sound() -> void:
	ui_hover_sfx = AudioStreamPlayer.new()
	ui_hover_sfx.name = "UiHoverSfx"
	ui_hover_sfx.stream = BUTTON_HOVER_SOUND
	ui_hover_sfx.bus = MASTER_BUS_NAME
	ui_hover_sfx.volume_db = BUTTON_HOVER_VOLUME_DB
	add_child(ui_hover_sfx)

func _setup_ui_click_sound() -> void:
	ui_click_sfx = AudioStreamPlayer.new()
	ui_click_sfx.name = "UiClickSfx"
	ui_click_sfx.stream = BUTTON_CLICK_SOUND
	ui_click_sfx.bus = MASTER_BUS_NAME
	ui_click_sfx.volume_db = BUTTON_CLICK_VOLUME_DB
	ui_click_sfx.pitch_scale = BUTTON_CLICK_PITCH_SCALE
	add_child(ui_click_sfx)

func _attach_hover_sound(button: Button) -> void:
	button.mouse_entered.connect(_play_ui_hover_sound)

func _attach_click_sound(button: Button) -> void:
	button.pressed.connect(_play_ui_click_sound)

func _play_ui_hover_sound() -> void:
	if ui_hover_sfx == null:
		return
	ui_hover_sfx.stop()
	ui_hover_sfx.play()

func _play_ui_click_sound() -> void:
	if ui_click_sfx == null:
		return
	ui_click_sfx.stop()
	ui_click_sfx.play()

func _stars_to_text(stars: int) -> String:
	match clampi(stars, 0, 3):
		3:
			return "★ ★ ★"
		2:
			return "★ ★ ☆"
		1:
			return "★ ☆ ☆"
		_:
			return "☆ ☆ ☆"

func _open_pending_level_selection() -> void:
	var lm := get_node_or_null("/root/LevelManager")
	if lm == null:
		return
	var level_num := int(lm.consume_pending_level_selection())
	if level_num <= 0:
		return
	_open_difficulty_panel(level_num)

func _build_difficulty_panel() -> void:
	difficulty_panel = CenterContainer.new()
	difficulty_panel.name = "DifficultyPanel"
	difficulty_panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	difficulty_panel.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(difficulty_panel)

	var panel_box = PanelContainer.new()
	panel_box.name = "DifficultyPanelBox"
	panel_box.custom_minimum_size = Vector2(560, 480)
	var panel_sb = _make_stylebox(PANEL_BG, CORNER_RADIUS, 2, ACCENT_BLUE * Color(1, 1, 1, 0.6))
	panel_sb.shadow_size = 40
	panel_sb.shadow_color = Color(0.0, 0.2, 0.4, 0.4)
	panel_sb.content_margin_left = 36
	panel_sb.content_margin_right = 36
	panel_sb.content_margin_top = 32
	panel_sb.content_margin_bottom = 32
	panel_box.add_theme_stylebox_override("panel", panel_sb)
	difficulty_panel.add_child(panel_box)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	panel_box.add_child(vbox)

	var header = _make_label("ВЫБЕРИ СЛОЖНОСТЬ", 38, ACCENT_COLOR)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var head_set = LabelSettings.new()
	head_set.font_size = 38
	head_set.font_color = ACCENT_COLOR
	head_set.shadow_color = ACCENT_COLOR * Color(1,1,1,0.3)
	head_set.shadow_size = 10
	header.label_settings = head_set
	vbox.add_child(header)

	var subtitle = _make_label("Каждая сложность даст разное число звезд", 20, TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", _make_stylebox(PANEL_BORDER * Color(1, 1, 1, 0.3), 0))
	vbox.add_child(sep)

	vbox.add_child(_make_difficulty_button("ЛЕГКИЙ", "★ ☆ ☆", "Меньше врагов, медленная реакция ИИ", ACCENT_COLOR, "easy"))
	vbox.add_child(_make_difficulty_button("СРЕДНИЙ", "★ ★ ☆", "Стандартный сбалансированный бой", ACCENT_BLUE, "medium"))
	vbox.add_child(_make_difficulty_button("СЛОЖНЫЙ", "★ ★ ★", "Усиленный старт врага, агрессивный ИИ", Color(1.0, 0.4, 0.2, 1.0), "hard"))

	var cancel_btn = _make_button("✖ ОТМЕНА", ACCENT_RED)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.custom_minimum_size = Vector2(220, 56)
	cancel_btn.pressed.connect(_on_difficulty_cancel)
	vbox.add_child(cancel_btn)

func _make_difficulty_button(title_text: String, stars_text: String, desc_text: String, accent: Color, difficulty: String) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 88)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pivot_offset = Vector2(244, 44) # Для скейла (учитываем ширину ~488)
	_attach_hover_sound(btn)
	_attach_click_sound(btn)
	
	# Стили
	var dark_bg = Color(accent.r * 0.1, accent.g * 0.1, accent.b * 0.1, 0.8)
	var hover_bg = Color(accent.r * 0.15, accent.g * 0.15, accent.b * 0.15, 0.95)
	
	var sb = _make_stylebox(dark_bg, BTN_CORNER, 2, accent * Color(1, 1, 1, 0.4))
	btn.add_theme_stylebox_override("normal", sb)
	var hover_sb = _make_stylebox(hover_bg, BTN_CORNER, 2, accent)
	hover_sb.shadow_size = 16
	hover_sb.shadow_color = accent * Color(1,1,1, 0.4)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", _make_stylebox(dark_bg, BTN_CORNER, 3, accent))
	btn.add_theme_stylebox_override("focus", hover_sb.duplicate())
	
	btn.pressed.connect(_start_level_with_difficulty.bind(difficulty))
	
	# Анимация
	btn.mouse_entered.connect(func():
		var t = btn.create_tween()
		t.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.15).set_trans(Tween.TRANS_BACK)
		t.parallel().tween_property(btn, "modulate", Color(1.1, 1.1, 1.1, 1.0), 0.15)
	)
	btn.mouse_exited.connect(func():
		var t = btn.create_tween()
		t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
		t.parallel().tween_property(btn, "modulate", Color.WHITE, 0.1)
	)

	# Компоновка контента
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 16)
	btn.add_child(hbox)
	
	# Отступ слева
	var margin_l = Control.new()
	margin_l.custom_minimum_size.x = 12
	hbox.add_child(margin_l)

	var title_lbl = _make_label(title_text, 28, accent)
	title_lbl.custom_minimum_size.x = 160
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tset = LabelSettings.new()
	tset.font_size = 28
	tset.font_color = accent
	tset.shadow_color = Color(0,0,0,0.5)
	tset.shadow_offset = Vector2(0, 2)
	title_lbl.label_settings = tset
	hbox.add_child(title_lbl)
	
	var v_sep = VSeparator.new()
	v_sep.add_theme_stylebox_override("separator", _make_stylebox(accent * Color(1,1,1,0.2), 0))
	v_sep.custom_minimum_size.y = 50
	v_sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(v_sep)

	var text_vbox = VBoxContainer.new()
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(text_vbox)

	var stars_lbl = _make_label(stars_text, 22, Color(1.0, 0.9, 0.4, 1.0))
	var sset = LabelSettings.new()
	sset.font_size = 22
	sset.font_color = Color(1.0, 0.9, 0.4, 1.0)
	sset.shadow_color = Color(1.0, 0.5, 0.0, 0.5)
	sset.shadow_size = 4
	stars_lbl.label_settings = sset
	text_vbox.add_child(stars_lbl)

	var desc_lbl = _make_label(desc_text, 16, TEXT_DIM.lightened(0.2))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_vbox.add_child(desc_lbl)

	return btn

func _open_difficulty_panel(level_num: int) -> void:
	if _should_skip_difficulty_panel(level_num):
		_start_level(level_num, "easy")
		return

	pending_level_num = level_num
	_hide_panel(level_panel)
	var tween = create_tween()
	tween.tween_interval(0.22)
	tween.tween_callback(func():
		_show_panel(difficulty_panel)
	)

func _start_level_with_difficulty(difficulty: String) -> void:
	print("Выбран уровень: ", pending_level_num, ", сложность: ", difficulty)
	_start_level(pending_level_num, difficulty)

func _start_level(level_num: int, difficulty: String) -> void:
	var scene_path := "res://scenes/main.tscn"
	if has_node("/root/LevelManager"):
		var lm: Node = get_node("/root/LevelManager")
		lm.set_current_level(level_num)
		lm.set_selected_difficulty(difficulty)
		scene_path = lm.get_current_level_scene_path()

	_hide_panel(difficulty_panel)
	var tween = create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(func():
		if has_node("/root/LoadingManager"):
			get_node("/root/LoadingManager").transition_to_scene(scene_path)
		else:
			get_tree().change_scene_to_file(scene_path)
	)

func _should_skip_difficulty_panel(level_num: int) -> bool:
	var lm := get_node_or_null("/root/LevelManager")
	if lm == null:
		return false
	return bool(lm.get_level_data(level_num).get("skip_difficulty_select", false))

func _on_difficulty_cancel() -> void:
	_hide_panel(difficulty_panel)
	var tween = create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(func():
		refresh_unlocked_levels()
		_update_level_panel_responsive()
		_show_panel(level_panel)
	)

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

func _build_perks_panel() -> void:
	perks_panel = CenterContainer.new()
	perks_panel.name = "PerksPanel"
	perks_panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	perks_panel.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(perks_panel)

	var panel_box = PanelContainer.new()
	panel_box.name = "PerksPanelBox"
	panel_box.custom_minimum_size = Vector2(980, 560)
	var panel_sb = _make_stylebox(PANEL_BG, CORNER_RADIUS, 2, Color(0.92, 0.78, 0.28, 0.42))
	panel_sb.shadow_size = 22
	panel_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.64)
	panel_sb.content_margin_left = 28
	panel_sb.content_margin_right = 28
	panel_sb.content_margin_top = 24
	panel_sb.content_margin_bottom = 24
	panel_box.add_theme_stylebox_override("panel", panel_sb)
	perks_panel.add_child(panel_box)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel_box.add_child(vbox)

	var header = _make_label("✦  ПЕРКИ", 28, Color(0.96, 0.84, 0.34, 1.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	var subtitle = _make_label("Нажми на перк, чтобы прочитать как он работает", 18, TEXT_DIM.lightened(0.18))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var cards_row = HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 14)
	vbox.add_child(cards_row)

	perk_card_buttons.clear()
	for perk in PERK_INFO:
		var card = _build_perk_card(perk)
		cards_row.add_child(card)
		perk_card_buttons[String(perk.id)] = card

	var desc_panel = PanelContainer.new()
	desc_panel.custom_minimum_size = Vector2(920, 250)
	desc_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var desc_sb = _make_stylebox(Color(0.08, 0.11, 0.16, 0.9), CORNER_RADIUS, 1, Color(1, 1, 1, 0.08))
	desc_sb.content_margin_left = 22
	desc_sb.content_margin_right = 22
	desc_sb.content_margin_top = 20
	desc_sb.content_margin_bottom = 20
	desc_panel.add_theme_stylebox_override("panel", desc_sb)
	vbox.add_child(desc_panel)

	var desc_box = VBoxContainer.new()
	desc_box.add_theme_constant_override("separation", 12)
	desc_panel.add_child(desc_box)

	perks_desc_title = _make_label("", 26, TEXT_COLOR)
	perks_desc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_box.add_child(perks_desc_title)

	perks_desc_meta = _make_label("", 18, Color(0.96, 0.84, 0.34, 0.96))
	perks_desc_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	perks_desc_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perks_desc_meta.custom_minimum_size = Vector2(860, 28)
	desc_box.add_child(perks_desc_meta)

	perks_desc_body = _make_label("", 18, TEXT_DIM.lightened(0.28))
	perks_desc_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perks_desc_body.custom_minimum_size = Vector2(860, 190)
	desc_box.add_child(perks_desc_body)

	var close_btn = _make_button("← НАЗАД", ACCENT_BLUE)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_on_perks_close)
	vbox.add_child(close_btn)

	_select_perk_card(selected_perk_id)

func _build_perk_card(perk: Dictionary) -> Button:
	var accent: Color = perk.color
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 180)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_attach_hover_sound(btn)
	_attach_click_sound(btn)

	var normal_sb = _make_stylebox(Color(accent.r * 0.1, accent.g * 0.1, accent.b * 0.1, 0.82), BTN_CORNER, 2, accent * Color(1, 1, 1, 0.26))
	normal_sb.shadow_size = 10
	normal_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	btn.add_theme_stylebox_override("normal", normal_sb)

	var hover_sb = _make_stylebox(Color(accent.r * 0.16, accent.g * 0.16, accent.b * 0.16, 0.96), BTN_CORNER, 2, accent * Color(1, 1, 1, 0.85))
	hover_sb.shadow_size = 14
	hover_sb.shadow_color = accent * Color(1, 1, 1, 0.22)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("focus", hover_sb.duplicate())
	btn.add_theme_stylebox_override("pressed", _make_stylebox(Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, 0.92), BTN_CORNER, 3, accent))

	var card_box = VBoxContainer.new()
	card_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	card_box.add_theme_constant_override("separation", 8)
	btn.add_child(card_box)

	var icon_holder = CenterContainer.new()
	icon_holder.custom_minimum_size = Vector2(0, 88)
	card_box.add_child(icon_holder)

	var icon_preview := MenuPerkIcon.new()
	icon_preview.perk_id = String(perk.id)
	icon_preview.icon_texture = perk.get("icon")
	icon_preview.icon_color = accent
	icon_preview.custom_minimum_size = Vector2(72, 72)
	icon_holder.add_child(icon_preview)

	var title_lbl = _make_label(String(perk.title), 20, accent)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(title_lbl)

	var sub_lbl = _make_label(String(perk.subtitle), 15, TEXT_DIM.lightened(0.22))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(sub_lbl)

	btn.pressed.connect(_select_perk_card.bind(String(perk.id)))
	return btn

func _select_perk_card(perk_id: String) -> void:
	selected_perk_id = perk_id
	for perk in PERK_INFO:
		if String(perk.id) == perk_id:
			perks_desc_title.text = String(perk.title)
			perks_desc_meta.text = "⚡ %s   |   ⏱ %s" % [String(perk.cost), String(perk.cooldown)]
			perks_desc_body.text = String(perk.desc)
			break

	for perk in PERK_INFO:
		var card: Button = perk_card_buttons.get(String(perk.id), null)
		if card == null:
			continue
		var accent: Color = perk.color
		var is_selected := String(perk.id) == perk_id
		var normal_sb = _make_stylebox(
			Color(accent.r * (0.18 if is_selected else 0.1), accent.g * (0.18 if is_selected else 0.1), accent.b * (0.18 if is_selected else 0.1), 0.92 if is_selected else 0.82),
			BTN_CORNER,
			2 if not is_selected else 3,
			accent * Color(1, 1, 1, 1.0 if is_selected else 0.26)
		)
		normal_sb.shadow_size = 16 if is_selected else 10
		normal_sb.shadow_color = accent * Color(1, 1, 1, 0.28 if is_selected else 0.14)
		card.add_theme_stylebox_override("normal", normal_sb)

# ========== АНИМАЦИИ ==========

func _show_panel(panel: Control) -> void:
	overlay.visible = true
	overlay.modulate = Color(1, 1, 1, 0)
	panel.visible = true
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.8, 0.8)
	panel.pivot_offset = panel.size / 2.0
	
	var tween = create_tween().set_parallel()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	refresh_unlocked_levels()
	_update_level_panel_responsive()
	_show_panel(level_panel)

func _on_level_selected(level_num: int) -> void:
	_open_difficulty_panel(level_num)

func _on_level_back() -> void:
	_hide_panel(level_panel)

func _on_settings_open() -> void:
	_show_panel(settings_panel)

func _on_settings_close() -> void:
	_hide_panel(settings_panel)

func _on_perks_open() -> void:
	_show_panel(perks_panel)

func _on_perks_close() -> void:
	_hide_panel(perks_panel)

func refresh_unlocked_levels() -> void:
	if has_node("/root/LevelManager"):
		var lm: Node = get_node("/root/LevelManager")
		unlocked_levels = lm.unlocked_levels
		total_levels = lm.get_total_levels()
	if level_list:
		_populate_levels()

func _on_sound_toggle() -> void:
	is_sound_on = not is_sound_on
	if sound_cross:
		sound_cross.visible = not is_sound_on
	_apply_sound_volume()

func _on_music_toggle() -> void:
	is_music_on = not is_music_on
	_apply_music_volume()

func _on_sound_volume_changed(value: float) -> void:
	sound_volume = value
	sound_value_label.text = str(int(value)) + "%"
	is_sound_on = value > 0
	if sound_cross:
		sound_cross.visible = not is_sound_on
	_apply_sound_volume()

func _on_music_volume_changed(value: float) -> void:
	music_volume = value
	music_value_label.text = str(int(value)) + "%"
	is_music_on = value > 0
	_apply_music_volume()

func _apply_sound_volume() -> void:
	var master_bus_index: int = AudioServer.get_bus_index(MASTER_BUS_NAME)
	if master_bus_index < 0:
		return
	var effective: float = clampf(sound_volume / 100.0, 0.0, 1.0)
	AudioServer.set_bus_volume_db(
		master_bus_index,
		linear_to_db(effective) if effective > 0.0 else -80.0
	)
	AudioServer.set_bus_mute(master_bus_index, not is_sound_on)

func _apply_music_volume() -> void:
	var effective: float = music_volume if is_music_on else 0.0
	var volume_db := linear_to_db(effective / 100.0) if effective > 0.0 else -80.0
	menu_music.volume_db = volume_db - _get_music_bus_volume_db()
	if effective > 0.0:
		var music_bus_index := AudioServer.get_bus_index(MUSIC_BUS_NAME)
		if music_bus_index >= 0:
			AudioServer.set_bus_mute(music_bus_index, false)

func _get_music_bus_volume_db() -> float:
	var music_bus_index := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if music_bus_index < 0:
		return 0.0
	return AudioServer.get_bus_volume_db(music_bus_index)

func _sync_audio_state_from_buses() -> void:
	var master_bus_index: int = AudioServer.get_bus_index(MASTER_BUS_NAME)
	if master_bus_index >= 0:
		is_sound_on = not AudioServer.is_bus_mute(master_bus_index)
		sound_volume = clampf(
			db_to_linear(AudioServer.get_bus_volume_db(master_bus_index)) * 100.0,
			0.0,
			100.0
		)

	music_volume = clampf(db_to_linear(menu_music.volume_db + _get_music_bus_volume_db()) * 100.0, 0.0, 100.0)
	var music_bus_index := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	is_music_on = music_volume > 0.0 and (music_bus_index < 0 or not AudioServer.is_bus_mute(music_bus_index))

func _input(event: InputEvent) -> void:
	var dev = get_tree().get_first_node_in_group("dev_console")
	if dev and dev._is_open:
		return

	# ESC закрывает открытые панели
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if settings_panel.visible:
			_on_settings_close()
			get_viewport().set_input_as_handled()
		elif perks_panel.visible:
			_on_perks_close()
			get_viewport().set_input_as_handled()
		elif difficulty_panel.visible:
			_on_difficulty_cancel()
			get_viewport().set_input_as_handled()
		elif level_panel.visible:
			_on_level_back()
			get_viewport().set_input_as_handled()
