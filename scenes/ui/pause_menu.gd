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
const TEXT_DIM := Color(0.62, 0.7, 0.78, 1.0)
const MASTER_BUS_NAME: StringName = &"Master"
const MUSIC_BUS_NAME: StringName = &"Music"
const BUTTON_HOVER_SOUND := preload("res://audio/Button_click.ogg")
const BUTTON_HOVER_VOLUME_DB: float = 0.0
const BUTTON_CLICK_SOUND := preload("res://audio/clickWhooh.ogg")
const BUTTON_CLICK_VOLUME_DB: float = -14.0
const BUTTON_CLICK_PITCH_SCALE: float = 1.8

var overlay: ColorRect
var center_panel: PanelContainer
var title_label: Label
var resume_btn: Button
var restart_btn: Button
var main_menu_btn: Button
var audio_title_label: Label
var master_caption_label: Label
var music_caption_label: Label
var lang_title_label: Label
var master_slider: HSlider
var music_slider: HSlider
var master_value_label: Label
var music_value_label: Label
var language_buttons: Dictionary = {}
var ui_hover_sfx: AudioStreamPlayer
var ui_click_sfx: AudioStreamPlayer

var is_open: bool = false

func _ready() -> void:
	layer = 120 # Поверх всего HUD
	process_mode = Node.PROCESS_MODE_ALWAYS # Работает при паузе
	
	if has_node("/root/LocalizationManager"):
		get_node("/root/LocalizationManager").language_changed.connect(_on_language_changed)

	_setup_ui_sounds()
	_build_ui()
	_update_localized_texts()
	
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
	center_panel.custom_minimum_size = Vector2(380, 640)
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
	panel_sb.content_margin_top = 28
	panel_sb.content_margin_bottom = 28
	panel_sb.content_margin_left = 28
	panel_sb.content_margin_right = 28
	center_panel.add_theme_stylebox_override("panel", panel_sb)
	center.add_child(center_panel)
	
	# 4. Внутренности
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_panel.add_child(vbox)
	
	# Заголовок
	title_label = Label.new()
	title_label.text = tr("UI_PAUSE")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", ACCENT_COLOR)
	var title_set = LabelSettings.new()
	title_set.font_size = 36
	title_set.font_color = ACCENT_COLOR
	title_set.shadow_size = 3
	title_set.shadow_offset = Vector2(0, 3)
	title_label.label_settings = title_set
	vbox.add_child(title_label)
	
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxEmpty.new())
	sep.custom_minimum_size.y = 6
	vbox.add_child(sep)
	
	# Кнопка ПРОДОЛЖИТЬ
	resume_btn = _make_button(tr("UI_RESUME"), ACCENT_COLOR)
	resume_btn.pressed.connect(toggle_pause)
	vbox.add_child(resume_btn)

	# Кнопка РЕСТАРТ
	restart_btn = _make_button(tr("UI_RESTART"), ACCENT_BLUE)
	restart_btn.pressed.connect(_on_restart_pressed)
	vbox.add_child(restart_btn)
	
	# Кнопка В ГЛАВНОЕ МЕНЮ
	main_menu_btn = _make_button(tr("UI_EXIT_TO_MENU"), ACCENT_RED)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	vbox.add_child(main_menu_btn)

	var audio_separator := HSeparator.new()
	audio_separator.custom_minimum_size.y = 4
	vbox.add_child(audio_separator)

	audio_title_label = Label.new()
	audio_title_label.text = tr("UI_AUDIO")
	audio_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	audio_title_label.add_theme_font_size_override("font_size", 18)
	audio_title_label.add_theme_color_override("font_color", ACCENT_COLOR)
	vbox.add_child(audio_title_label)

	master_slider = _add_audio_slider(vbox, "master", tr("UI_MASTER_VOLUME"), _get_bus_volume_percent(MASTER_BUS_NAME), _on_master_volume_changed)
	music_slider = _add_audio_slider(vbox, "music", tr("UI_LEVEL_MUSIC"), _get_level_music_volume_percent(), _on_music_volume_changed)

	# Селектор языков в паузе
	var lang_separator := HSeparator.new()
	lang_separator.custom_minimum_size.y = 4
	vbox.add_child(lang_separator)

	lang_title_label = Label.new()
	lang_title_label.text = tr("UI_LANGUAGE")
	lang_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lang_title_label.add_theme_font_size_override("font_size", 16)
	lang_title_label.add_theme_color_override("font_color", ACCENT_BLUE)
	vbox.add_child(lang_title_label)

	var lang_btn_row = HBoxContainer.new()
	lang_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lang_btn_row.add_theme_constant_override("separation", 6)
	vbox.add_child(lang_btn_row)

	language_buttons.clear()
	var locales: Array[String] = ["ru", "en", "tr", "fr", "it"]
	for loc in locales:
		var btn = Button.new()
		btn.text = loc.to_upper()
		btn.custom_minimum_size = Vector2(44, 32)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_size_override("font_size", 13)
		btn.mouse_entered.connect(_play_ui_hover_sound)
		btn.pressed.connect(_play_ui_click_sound)
		btn.pressed.connect(_on_language_button_pressed.bind(loc))
		lang_btn_row.add_child(btn)
		language_buttons[loc] = btn
	_update_language_buttons()

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
	btn.mouse_entered.connect(_play_ui_hover_sound)
	btn.pressed.connect(_play_ui_click_sound)
	return btn

func _add_audio_slider(parent: VBoxContainer, slider_type: String, caption: String, initial_value: float, changed_callback: Callable) -> HSlider:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var header := HBoxContainer.new()
	row.add_child(header)

	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption_label.add_theme_font_size_override("font_size", 14)
	caption_label.add_theme_color_override("font_color", TEXT_DIM)
	header.add_child(caption_label)

	var value_label := Label.new()
	value_label.text = "%d%%" % roundi(initial_value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 54
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", TEXT_COLOR)
	header.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = clampf(initial_value, slider.min_value, slider.max_value)
	slider.custom_minimum_size.y = 24
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	slider.value_changed.connect(changed_callback.bind(value_label))

	if slider_type == "master":
		master_caption_label = caption_label
		master_value_label = value_label
	else:
		music_caption_label = caption_label
		music_value_label = value_label
	return slider

func _setup_ui_sounds() -> void:
	ui_hover_sfx = AudioStreamPlayer.new()
	ui_hover_sfx.name = "UiHoverSfx"
	ui_hover_sfx.stream = BUTTON_HOVER_SOUND
	ui_hover_sfx.bus = MASTER_BUS_NAME
	ui_hover_sfx.volume_db = BUTTON_HOVER_VOLUME_DB
	ui_hover_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_hover_sfx)

	ui_click_sfx = AudioStreamPlayer.new()
	ui_click_sfx.name = "UiClickSfx"
	ui_click_sfx.stream = BUTTON_CLICK_SOUND
	ui_click_sfx.bus = MASTER_BUS_NAME
	ui_click_sfx.volume_db = BUTTON_CLICK_VOLUME_DB
	ui_click_sfx.pitch_scale = BUTTON_CLICK_PITCH_SCALE
	ui_click_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_click_sfx)

func _play_ui_hover_sound() -> void:
	if not is_open or ui_hover_sfx == null:
		return
	ui_hover_sfx.stop()
	ui_hover_sfx.play()

func _play_ui_click_sound() -> void:
	if not is_open or ui_click_sfx == null:
		return
	ui_click_sfx.stop()
	ui_click_sfx.play()

func _on_master_volume_changed(value: float, value_label: Label) -> void:
	_set_bus_volume_percent(MASTER_BUS_NAME, value)
	value_label.text = "%d%%" % roundi(value)

func _on_music_volume_changed(value: float, value_label: Label) -> void:
	_set_level_music_volume_percent(value)
	value_label.text = "%d%%" % roundi(value)

func _get_level_music_player() -> AudioStreamPlayer:
	var root := get_tree().current_scene
	if root == null:
		return null
	return root.get_node_or_null(NodePath("LevelMusic")) as AudioStreamPlayer

func _get_level_music_volume_percent() -> float:
	var level_music := _get_level_music_player()
	if level_music == null:
		return 0.0
	return clampf(db_to_linear(level_music.volume_db + _get_music_bus_volume_db()) * 100.0, 0.0, 100.0)

func _set_level_music_volume_percent(value: float) -> void:
	var level_music := _get_level_music_player()
	if level_music == null:
		return
	var percent := clampf(value, 0.0, 100.0)
	var volume_db := linear_to_db(percent / 100.0) if percent > 0.0 else -80.0
	level_music.volume_db = volume_db - _get_music_bus_volume_db()
	if percent > 0.0:
		var music_bus_index := AudioServer.get_bus_index(MUSIC_BUS_NAME)
		if music_bus_index >= 0:
			AudioServer.set_bus_mute(music_bus_index, false)

func _get_music_bus_volume_db() -> float:
	var music_bus_index := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if music_bus_index < 0:
		return 0.0
	return AudioServer.get_bus_volume_db(music_bus_index)

func _get_bus_volume_percent(bus_name: StringName) -> float:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0 or AudioServer.is_bus_mute(bus_index):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0, 0.0, 100.0)

func _set_bus_volume_percent(bus_name: StringName, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var percent := clampf(value, 0.0, 100.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(percent / 100.0) if percent > 0.0 else -80.0)
	AudioServer.set_bus_mute(bus_index, percent <= 0.0)

func _sync_audio_controls() -> void:
	var master_percent := _get_bus_volume_percent(MASTER_BUS_NAME)
	if master_slider != null:
		master_slider.set_value_no_signal(master_percent)
	if master_value_label != null:
		master_value_label.text = "%d%%" % roundi(master_percent)

	var music_percent := _get_level_music_volume_percent()
	if music_slider != null:
		music_slider.set_value_no_signal(music_percent)
	if music_value_label != null:
		music_value_label.text = "%d%%" % roundi(music_percent)

func toggle_pause() -> void:
	is_open = not is_open
	get_tree().paused = is_open
	
	if is_open:
		_sync_audio_controls()
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
	is_open = false
	if overlay:
		overlay.visible = false
		overlay.modulate.a = 0.0
	if center_panel:
		center_panel.scale = Vector2.ONE
	if has_node("/root/LoadingManager"):
		get_node("/root/LoadingManager").transition_to_scene("res://scenes/ui/main_menu/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")

func _on_restart_pressed() -> void:
	get_tree().paused = false
	is_open = false
	if overlay:
		overlay.visible = false
		overlay.modulate.a = 0.0
	if center_panel:
		center_panel.scale = Vector2.ONE
	var current_scene := get_tree().current_scene
	var scene_path := ""
	if current_scene:
		scene_path = String(current_scene.scene_file_path)
	if not scene_path.is_empty() and has_node("/root/LoadingManager"):
		get_node("/root/LoadingManager").transition_to_scene(scene_path)
	else:
		get_tree().reload_current_scene()

# ========== ЛОКАЛИЗАЦИЯ ==========

func _on_language_button_pressed(locale: String) -> void:
	if has_node("/root/LocalizationManager"):
		get_node("/root/LocalizationManager").set_locale(locale)
	else:
		TranslationServer.set_locale(locale)
		_on_language_changed(locale)

func _on_language_changed(_locale: String) -> void:
	_update_localized_texts()

func _update_language_buttons() -> void:
	var current_lang := "ru"
	if has_node("/root/LocalizationManager"):
		current_lang = get_node("/root/LocalizationManager").get_current_language()
	else:
		current_lang = TranslationServer.get_locale().substr(0, 2).to_lower()

	for loc in language_buttons.keys():
		var btn: Button = language_buttons[loc]
		if not is_instance_valid(btn):
			continue
		var is_current: bool = (str(loc) == current_lang)
		if is_current:
			var active_sb := StyleBoxFlat.new()
			active_sb.bg_color = ACCENT_BLUE.darkened(0.3)
			active_sb.corner_radius_top_left = 8
			active_sb.corner_radius_top_right = 8
			active_sb.corner_radius_bottom_left = 8
			active_sb.corner_radius_bottom_right = 8
			active_sb.border_width_left = 2
			active_sb.border_width_right = 2
			active_sb.border_width_top = 2
			active_sb.border_width_bottom = 2
			active_sb.border_color = ACCENT_BLUE
			active_sb.shadow_size = 6
			active_sb.shadow_color = ACCENT_BLUE * Color(1, 1, 1, 0.4)
			btn.add_theme_stylebox_override("normal", active_sb)
			btn.add_theme_stylebox_override("hover", active_sb)
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			var idle_sb := StyleBoxFlat.new()
			idle_sb.bg_color = BTN_BG
			idle_sb.corner_radius_top_left = 8
			idle_sb.corner_radius_top_right = 8
			idle_sb.corner_radius_bottom_left = 8
			idle_sb.corner_radius_bottom_right = 8
			idle_sb.border_width_left = 1
			idle_sb.border_width_right = 1
			idle_sb.border_width_top = 1
			idle_sb.border_width_bottom = 1
			idle_sb.border_color = PANEL_BORDER
			var hover_sb = idle_sb.duplicate()
			hover_sb.bg_color = BTN_HOVER
			hover_sb.border_color = ACCENT_BLUE * Color(1, 1, 1, 0.5)
			btn.add_theme_stylebox_override("normal", idle_sb)
			btn.add_theme_stylebox_override("hover", hover_sb)
			btn.add_theme_color_override("font_color", TEXT_DIM)

func _update_localized_texts() -> void:
	if title_label:
		title_label.text = tr("UI_PAUSE")
	if resume_btn:
		resume_btn.text = tr("UI_RESUME")
	if restart_btn:
		restart_btn.text = tr("UI_RESTART")
	if main_menu_btn:
		main_menu_btn.text = tr("UI_EXIT_TO_MENU")
	if audio_title_label:
		audio_title_label.text = tr("UI_AUDIO")
	if master_caption_label:
		master_caption_label.text = tr("UI_MASTER_VOLUME")
	if music_caption_label:
		music_caption_label.text = tr("UI_LEVEL_MUSIC")
	if lang_title_label:
		lang_title_label.text = tr("UI_LANGUAGE")
	_update_language_buttons()
