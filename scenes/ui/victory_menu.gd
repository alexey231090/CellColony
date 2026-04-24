extends CanvasLayer
class_name VictoryMenu

const ACCENT_COLOR := Color(0.14, 0.9, 0.58, 1.0)
const ACCENT_BLUE := Color(0.2, 0.66, 1.0, 1.0)
const ACCENT_GOLD := Color(1.0, 0.88, 0.42, 1.0)
const PANEL_BG := Color(0.07, 0.1, 0.14, 0.92)
const PANEL_BORDER := Color(0.25, 0.95, 0.72, 0.34)
const BTN_BG := Color(0.12, 0.16, 0.22, 0.94)
const BTN_HOVER := Color(0.18, 0.24, 0.32, 0.98)
const BTN_PRESSED := Color(0.08, 0.11, 0.16, 1.0)

var overlay: ColorRect
var center_panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var stars_label: Label
var next_btn: Button
var replay_btn: Button
var menu_btn: Button

var _next_level_num: int = 0
var _has_next_level: bool = false

func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func setup(current_level: int, difficulty_stars: String, has_next_level: bool, next_level_num: int) -> void:
	_has_next_level = has_next_level
	_next_level_num = next_level_num
	stars_label.text = difficulty_stars
	subtitle_label.text = "Уровень %d завершен" % current_level
	next_btn.text = "СЛЕДУЮЩИЙ УРОВЕНЬ" if _has_next_level else "В ГЛАВНОЕ МЕНЮ"

func show_victory() -> void:
	visible = true
	overlay.visible = true
	overlay.modulate.a = 0.0
	center_panel.modulate.a = 0.0
	center_panel.scale = Vector2(0.86, 0.86)
	center_panel.pivot_offset = center_panel.size * 0.5
	stars_label.modulate.a = 0.0
	next_btn.modulate.a = 0.0
	replay_btn.modulate.a = 0.0
	menu_btn.modulate.a = 0.0

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.22)
	tween.tween_property(center_panel, "modulate:a", 1.0, 0.18)
	tween.tween_property(center_panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(stars_label, "modulate:a", 1.0, 0.16)
	tween.parallel().tween_property(next_btn, "modulate:a", 1.0, 0.14)
	tween.parallel().tween_property(replay_btn, "modulate:a", 1.0, 0.14)
	tween.parallel().tween_property(menu_btn, "modulate:a", 1.0, 0.14)

func _build_ui() -> void:
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	center_panel = PanelContainer.new()
	center_panel.custom_minimum_size = Vector2(420, 430)
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = PANEL_BG
	panel_sb.set_corner_radius_all(20)
	panel_sb.border_width_left = 2
	panel_sb.border_width_top = 2
	panel_sb.border_width_right = 2
	panel_sb.border_width_bottom = 2
	panel_sb.border_color = PANEL_BORDER
	panel_sb.shadow_size = 22
	panel_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	panel_sb.content_margin_left = 28
	panel_sb.content_margin_top = 28
	panel_sb.content_margin_right = 28
	panel_sb.content_margin_bottom = 28
	center_panel.add_theme_stylebox_override("panel", panel_sb)
	center.add_child(center_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	center_panel.add_child(vbox)

	title_label = Label.new()
	title_label.text = "ПОБЕДА"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_settings := LabelSettings.new()
	title_settings.font_size = 42
	title_settings.font_color = ACCENT_COLOR
	title_settings.outline_size = 6
	title_settings.outline_color = Color(0.0, 0.0, 0.0, 0.72)
	title_settings.shadow_size = 8
	title_settings.shadow_color = Color(0.1, 0.9, 0.58, 0.22)
	title_label.label_settings = title_settings
	vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.custom_minimum_size.x = 320.0
	var subtitle_settings := LabelSettings.new()
	subtitle_settings.font_size = 20
	subtitle_settings.font_color = Color(0.86, 0.94, 1.0, 0.95)
	subtitle_settings.outline_size = 4
	subtitle_settings.outline_color = Color(0.0, 0.0, 0.0, 0.62)
	subtitle_label.label_settings = subtitle_settings
	vbox.add_child(subtitle_label)

	stars_label = Label.new()
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stars_settings := LabelSettings.new()
	stars_settings.font_size = 34
	stars_settings.font_color = ACCENT_GOLD
	stars_settings.outline_size = 5
	stars_settings.outline_color = Color(0.26, 0.16, 0.0, 0.9)
	stars_settings.shadow_size = 10
	stars_settings.shadow_color = Color(1.0, 0.78, 0.2, 0.24)
	stars_label.label_settings = stars_settings
	vbox.add_child(stars_label)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	vbox.add_child(buttons)

	next_btn = _make_button("СЛЕДУЮЩИЙ УРОВЕНЬ", ACCENT_COLOR)
	next_btn.pressed.connect(_on_next_pressed)
	buttons.add_child(next_btn)

	replay_btn = _make_button("ПЕРЕИГРАТЬ", ACCENT_BLUE)
	replay_btn.pressed.connect(_on_replay_pressed)
	buttons.add_child(replay_btn)

	menu_btn = _make_button("В МЕНЮ", Color(1.0, 0.52, 0.42, 1.0))
	menu_btn.pressed.connect(_on_menu_pressed)
	buttons.add_child(menu_btn)

func _make_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0.0, 62.0)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", accent.lightened(0.35))

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = BTN_BG
	normal_sb.set_corner_radius_all(14)
	normal_sb.border_width_left = 2
	normal_sb.border_width_top = 2
	normal_sb.border_width_right = 2
	normal_sb.border_width_bottom = 2
	normal_sb.border_color = accent * Color(1, 1, 1, 0.46)
	normal_sb.shadow_size = 10
	normal_sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.16)
	btn.add_theme_stylebox_override("normal", normal_sb)

	var hover_sb := normal_sb.duplicate()
	hover_sb.bg_color = BTN_HOVER
	hover_sb.border_color = accent * Color(1, 1, 1, 0.9)
	hover_sb.shadow_size = 14
	hover_sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.26)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("focus", hover_sb)

	var pressed_sb := normal_sb.duplicate()
	pressed_sb.bg_color = BTN_PRESSED
	pressed_sb.border_color = accent
	btn.add_theme_stylebox_override("pressed", pressed_sb)

	return btn

func _on_next_pressed() -> void:
	var level_manager := get_node_or_null("/root/LevelManager")
	if not _has_next_level or level_manager == null:
		_on_menu_pressed()
		return

	level_manager.queue_level_selection(_next_level_num)
	if has_node("/root/LoadingManager"):
		get_node("/root/LoadingManager").transition_to_scene("res://scenes/ui/main_menu/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")

func _on_replay_pressed() -> void:
	var current_scene := get_tree().current_scene
	var scene_path := ""
	if current_scene:
		scene_path = String(current_scene.scene_file_path)
	if not scene_path.is_empty() and has_node("/root/LoadingManager"):
		get_node("/root/LoadingManager").transition_to_scene(scene_path)
	else:
		get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	if has_node("/root/LoadingManager"):
		get_node("/root/LoadingManager").transition_to_scene("res://scenes/ui/main_menu/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")
