extends CanvasLayer
class_name PauseMenu
## Внутриигровое меню паузы (работает на ESC и по кнопке на мобилках).
## Останавливает время через get_tree().paused и использует независимую от паузы обработку (MODE_ALWAYS).

const ACCENT_COLOR := Color(0.1, 0.85, 0.55, 1.0)
const ACCENT_BLUE := Color(0.15, 0.6, 1.0, 1.0)
const ACCENT_RED := Color(1.0, 0.3, 0.35, 1.0)
const PANEL_BG := Color(0.08, 0.1, 0.14, 0.9)
const PANEL_BORDER := Color(0.2, 0.9, 0.5, 0.3)
const BTN_BG := Color(0.12, 0.15, 0.2, 0.9)
const BTN_HOVER := Color(0.15, 0.2, 0.28, 0.95)
const BTN_PRESSED := Color(0.08, 0.1, 0.14, 1.0)
const TEXT_COLOR := Color(0.9, 0.95, 1.0, 1.0)

var overlay: ColorRect
var center_panel: PanelContainer
var resume_btn: Button
var restart_btn: Button
var main_menu_btn: Button

var is_open: bool = false

func _ready() -> void:
	layer = 120 # Поверх всего HUD
	process_mode = Node.PROCESS_MODE_ALWAYS # Работает при паузе
	
	_build_ui()
	
	# Скрыто по умолчанию
	overlay.visible = false
	overlay.modulate.a = 0.0

func _build_ui() -> void:
	# 1. Затемняющий фон
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	add_child(overlay)
	# 2. Контейнер по центру
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	# 3. Сама плашка паузы с glassmorphism
	center_panel = PanelContainer.new()
	center_panel.custom_minimum_size = Vector2(360, 400)
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = PANEL_BG
	panel_sb.corner_radius_top_left = 16
	panel_sb.corner_radius_top_right = 16
	panel_sb.corner_radius_bottom_left = 16
	panel_sb.corner_radius_bottom_right = 16
	panel_sb.border_width_left = 2
	panel_sb.border_width_right = 2
	panel_sb.border_width_top = 2
	panel_sb.border_width_bottom = 2
	panel_sb.border_color = PANEL_BORDER
	panel_sb.shadow_size = 16
	panel_sb.shadow_color = Color(0, 0, 0, 0.6)
	panel_sb.content_margin_top = 32
	panel_sb.content_margin_bottom = 32
	panel_sb.content_margin_left = 32
	panel_sb.content_margin_right = 32
	center_panel.add_theme_stylebox_override("panel", panel_sb)
	center.add_child(center_panel)
	
	# 4. Внутренности
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_panel.add_child(vbox)
	
	# Заголовок
	var title = Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	var title_set = LabelSettings.new()
	title_set.font_size = 36
	title_set.font_color = ACCENT_COLOR
	title_set.shadow_size = 3
	title_set.shadow_offset = Vector2(0, 3)
	title.label_settings = title_set
	vbox.add_child(title)
	
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxEmpty.new())
	sep.custom_minimum_size.y = 8
	vbox.add_child(sep)
	
	# Кнопка ПРОДОЛЖИТЬ
	resume_btn = _make_button("Продолжить", ACCENT_COLOR)
	resume_btn.pressed.connect(toggle_pause)
	vbox.add_child(resume_btn)

	# Кнопка РЕСТАРТ
	restart_btn = _make_button("Рестарт", ACCENT_BLUE)
	restart_btn.pressed.connect(_on_restart_pressed)
	vbox.add_child(restart_btn)
	
	# Кнопка В ГЛАВНОЕ МЕНЮ
	main_menu_btn = _make_button("Выйти в меню", ACCENT_RED)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	vbox.add_child(main_menu_btn)

func _make_button(text: String, accent: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 64)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 24)
	
	# Normal
	var normal_sb = StyleBoxFlat.new()
	normal_sb.bg_color = BTN_BG
	normal_sb.corner_radius_top_left = 12
	normal_sb.corner_radius_top_right = 12
	normal_sb.corner_radius_bottom_left = 12
	normal_sb.corner_radius_bottom_right = 12
	normal_sb.border_width_left = 2
	normal_sb.border_width_right = 2
	normal_sb.border_width_top = 2
	normal_sb.border_width_bottom = 2
	normal_sb.border_color = accent * Color(1,1,1,0.4)
	btn.add_theme_stylebox_override("normal", normal_sb)
	
	# Hover
	var hover_sb = normal_sb.duplicate()
	hover_sb.bg_color = BTN_HOVER
	hover_sb.border_color = accent * Color(1,1,1,0.8)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("focus", hover_sb)
	
	# Pressed
	var pressed_sb = normal_sb.duplicate()
	pressed_sb.bg_color = BTN_PRESSED
	pressed_sb.border_color = accent
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	
	return btn

func toggle_pause() -> void:
	is_open = not is_open
	get_tree().paused = is_open
	
	if is_open:
		overlay.visible = true
		var tween = create_tween().set_parallel()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.2)
		center_panel.scale = Vector2(0.9, 0.9)
		center_panel.pivot_offset = center_panel.size / 2.0
		tween.tween_property(center_panel, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		var tween = create_tween().set_parallel()
		tween.tween_property(overlay, "modulate:a", 0.0, 0.15)
		tween.tween_property(center_panel, "scale", Vector2(0.95, 0.95), 0.15)
		tween.chain().tween_callback(func(): overlay.visible = false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			# Если консоль разработчика открыта, не реагируем на ESC
			var dev = get_tree().get_first_node_in_group("dev_console")
			if dev and dev._is_open: return
			
			toggle_pause()
			get_viewport().set_input_as_handled()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false # Снимаем паузу перед переходом
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")

func _on_restart_pressed() -> void:
	get_tree().paused = false
	is_open = false
	if overlay:
		overlay.visible = false
		overlay.modulate.a = 0.0
	if center_panel:
		center_panel.scale = Vector2.ONE
	get_tree().reload_current_scene()
