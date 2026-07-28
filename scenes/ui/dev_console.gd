extends Control

const MASTER_BUS_NAME: StringName = &"Master"
const MUSIC_BUS_NAME: StringName = &"Music"
const AUDIO_MIN_VOLUME_DB: float = -40.0
const AUDIO_MAX_VOLUME_DB: float = 0.0
const AUDIO_VOLUME_STEP_DB: float = 1.0
const DEFAULT_FIRE_SOUND_1_VOLUME_DB: float = -7.0
const DEFAULT_FIRE_SOUND_2_VOLUME_DB: float = -7.0
const DEFAULT_DAMAGE_SOUND_1_VOLUME_DB: float = -4.0
const DEFAULT_DAMAGE_SOUND_2_VOLUME_DB: float = -15.0
const DEFAULT_FRIENDLY_FIRE_VOLUME_DB: float = -3.0
const DEFAULT_SHIELD_SOUND_1_VOLUME_DB: float = 0.0
const DEFAULT_SHIELD_SOUND_2_VOLUME_DB: float = 0.0
const DEFAULT_ACTIVE_PERK_SOUND_VOLUME_DB: float = -4.0

var overlay: ColorRect
var panel: PanelContainer
var options: ItemList
var help_label: Label
var selected_name_label: Label
var status_label: Label
var numeric_editor: SpinBox
var bool_editor: CheckButton
var numeric_editor_row: HBoxContainer
var bool_editor_row: HBoxContainer
var minus_button: Button
var plus_button: Button

var _is_open: bool = false
var _tween: Tween = null
var _settings: Array[Dictionary] = []
var _selected: int = 0
var _audio_files_expanded: bool = true
var _updating_editor: bool = false

func _ready() -> void:
	add_to_group("dev_console")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	options.item_selected.connect(_on_option_selected)
	options.item_activated.connect(_on_option_activated)
	_build_settings()
	_refresh_options()
	_select_index(0)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		if key_event.physical_keycode == KEY_QUOTELEFT and not key_event.echo:
			_toggle()
			get_viewport().set_input_as_handled()
			return

		if _is_open and key_event.keycode == KEY_ESCAPE:
			_toggle(false)
			get_viewport().set_input_as_handled()
			return

		if _is_open and key_event.ctrl_pressed and key_event.shift_pressed and key_event.keycode == KEY_C:
			_copy_selected_setting_to_clipboard()
			get_viewport().set_input_as_handled()
			return

		if _is_open and key_event.ctrl_pressed and key_event.keycode == KEY_C:
			_copy_all_settings_to_clipboard()
			get_viewport().set_input_as_handled()
			return

		if _is_open and not _is_numeric_editor_focused():
			_handle_key(key_event)
			get_viewport().set_input_as_handled()
			return

func _toggle(force: Variant = null) -> void:
	var target := (not _is_open) if force == null else bool(force)
	if target == _is_open:
		return
	_is_open = target
	if is_instance_valid(_tween):
		_tween.kill()
	if _is_open:
		visible = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		_refresh_audio_settings()
		_refresh_options()
		options.grab_focus()
		_select_index(_selected)
		overlay.modulate.a = 0.0
		panel.modulate.a = 0.0
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2(0.97, 0.97)
		_tween = create_tween()
		_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tween.set_parallel(true)
		_tween.tween_property(overlay, "modulate:a", 1.0, 0.16)
		_tween.tween_property(panel, "modulate:a", 1.0, 0.16)
		_tween.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tween = create_tween()
		_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tween.set_parallel(true)
		_tween.tween_property(overlay, "modulate:a", 0.0, 0.12)
		_tween.tween_property(panel, "modulate:a", 0.0, 0.12)
		_tween.chain().tween_callback(_hide_page)

func _hide_page() -> void:
	visible = false

func _build_ui() -> void:
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.01, 0.025, 0.05, 0.88)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 48.0
	panel.offset_top = 42.0
	panel.offset_right = -48.0
	panel.offset_bottom = -42.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 54.0
	content.add_child(header)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	var title := Label.new()
	title.text = "ПАНЕЛЬ РАЗРАБОТЧИКА"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.34, 0.95, 0.72, 1.0))
	title_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Runtime-настройки • изменения применяются сразу"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.68, 0.77, 0.88, 0.9))
	title_box.add_child(subtitle)
	var copy_button := _make_action_button("Копировать всё", Color(0.26, 0.66, 1.0, 1.0))
	copy_button.pressed.connect(_copy_all_settings_to_clipboard)
	header.add_child(copy_button)
	var close_button := _make_action_button("Закрыть  ~", Color(0.95, 0.4, 0.46, 1.0))
	close_button.pressed.connect(_close_page)
	header.add_child(close_button)

	var separator := HSeparator.new()
	content.add_child(separator)
	var body := HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.split_offset = 620
	content.add_child(body)

	var list_column := VBoxContainer.new()
	list_column.custom_minimum_size.x = 460.0
	list_column.add_theme_constant_override("separation", 8)
	body.add_child(list_column)
	var list_title := Label.new()
	list_title.text = "ВСЕ ПАРАМЕТРЫ"
	list_title.add_theme_font_size_override("font_size", 14)
	list_title.add_theme_color_override("font_color", Color(0.5, 0.78, 1.0, 1.0))
	list_column.add_child(list_title)
	options = ItemList.new()
	options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.select_mode = ItemList.SELECT_SINGLE
	options.add_theme_font_size_override("font_size", 16)
	options.add_theme_stylebox_override("panel", _make_list_style())
	list_column.add_child(options)

	var details_column := VBoxContainer.new()
	details_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_column.add_theme_constant_override("separation", 14)
	body.add_child(details_column)
	var details_title := Label.new()
	details_title.text = "РЕДАКТОР ПАРАМЕТРА"
	details_title.add_theme_font_size_override("font_size", 14)
	details_title.add_theme_color_override("font_color", Color(0.5, 0.78, 1.0, 1.0))
	details_column.add_child(details_title)
	selected_name_label = Label.new()
	selected_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_name_label.add_theme_font_size_override("font_size", 22)
	selected_name_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	details_column.add_child(selected_name_label)
	help_label = Label.new()
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.add_theme_font_size_override("font_size", 16)
	help_label.add_theme_color_override("font_color", Color(0.72, 0.8, 0.9, 1.0))
	details_column.add_child(help_label)
	var copy_selected_button := _make_action_button("Копировать параметр", Color(0.36, 0.82, 0.68, 1.0))
	copy_selected_button.pressed.connect(_copy_selected_setting_to_clipboard)
	details_column.add_child(copy_selected_button)

	numeric_editor_row = HBoxContainer.new()
	numeric_editor_row.add_theme_constant_override("separation", 10)
	details_column.add_child(numeric_editor_row)
	minus_button = _make_action_button("−", Color(0.35, 0.63, 1.0, 1.0))
	minus_button.custom_minimum_size = Vector2(58.0, 46.0)
	minus_button.pressed.connect(_decrease_selected_value)
	numeric_editor_row.add_child(minus_button)
	numeric_editor = SpinBox.new()
	numeric_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	numeric_editor.custom_minimum_size.y = 46.0
	numeric_editor.allow_greater = false
	numeric_editor.allow_lesser = false
	numeric_editor.get_line_edit().add_theme_font_size_override("font_size", 20)
	numeric_editor.value_changed.connect(_on_numeric_editor_changed)
	numeric_editor_row.add_child(numeric_editor)
	plus_button = _make_action_button("+", Color(0.35, 0.63, 1.0, 1.0))
	plus_button.custom_minimum_size = Vector2(58.0, 46.0)
	plus_button.pressed.connect(_increase_selected_value)
	numeric_editor_row.add_child(plus_button)

	bool_editor_row = HBoxContainer.new()
	details_column.add_child(bool_editor_row)
	bool_editor = CheckButton.new()
	bool_editor.text = "Включено"
	bool_editor.add_theme_font_size_override("font_size", 20)
	bool_editor.toggled.connect(_on_bool_editor_toggled)
	bool_editor_row.add_child(bool_editor)

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_column.add_child(fill)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.5, 0.96, 0.72, 1.0))
	details_column.add_child(status_label)
	var footer := Label.new()
	footer.text = "↑↓ — выбор  •  ←→ — шаг  •  Enter — редактировать  •  Ctrl+C — всё  •  Ctrl+Shift+C — параметр  •  Esc / ~ — закрыть"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 14)
	footer.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 0.9))
	content.add_child(footer)

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.09, 0.14, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.23, 0.72, 0.93, 0.62)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_size = 24
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	style.content_margin_left = 24.0
	style.content_margin_top = 18.0
	style.content_margin_right = 24.0
	style.content_margin_bottom = 18.0
	return style

func _make_list_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.08, 0.82)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.26, 0.55, 0.78, 0.46)
	return style

func _make_action_button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(130.0, 42.0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.09, 0.15, 0.22, 0.98)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = accent * Color(1.0, 1.0, 1.0, 0.7)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.13, 0.23, 0.32, 1.0)
	hover.border_color = accent
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	return button

func _close_page() -> void:
	_toggle(false)
	
func _build_settings() -> void:
	_settings.clear()
	var level_manager := get_node_or_null("/root/LevelManager")
	var unlock_all_enabled := false
	if level_manager != null:
		if level_manager.has_method("are_all_levels_unlocked"):
			unlock_all_enabled = bool(level_manager.are_all_levels_unlocked())
		else:
			unlock_all_enabled = int(level_manager.unlocked_levels) >= int(level_manager.get_total_levels())

	_settings.append({
		"id": "camera_mode",
		"name": "Режим Камеры",
		"type": "int",
		"value": 1,
		"min": 1,
		"max": 2,
		"desc": "1 - Игрок, 2 - Свободная (WASD). Enter — ввод.",
		"apply": Callable(self, "_apply_camera_mode")
	})
	_settings.append({
		"id": "show_fps",
		"name": "Показывать FPS",
		"type": "bool",
		"value": true,
		"desc": "Enter/←→ — переключить.",
		"apply": Callable(self, "_apply_show_fps")
	})
	_settings.append({
		"id": "audio_master_volume_db",
		"name": "АУДИО: Общая громкость (дБ)",
		"type": "float",
		"value": _get_bus_volume_db(MASTER_BUS_NAME, 0.0),
		"min": AUDIO_MIN_VOLUME_DB,
		"max": AUDIO_MAX_VOLUME_DB,
		"step": AUDIO_VOLUME_STEP_DB,
		"desc": "0 дБ — исходная громкость, отрицательные значения тише. Регулирует всё аудио.",
		"apply": Callable(self, "_apply_audio_master_volume")
	})
	_settings.append({
		"id": "audio_music_volume_db",
		"name": "АУДИО: Музыка (дБ)",
		"type": "float",
		"value": _get_bus_volume_db(MUSIC_BUS_NAME, 0.0),
		"min": AUDIO_MIN_VOLUME_DB,
		"max": AUDIO_MAX_VOLUME_DB,
		"step": AUDIO_VOLUME_STEP_DB,
		"desc": "Громкость музыки меню и уровней. 0 дБ — исходная громкость.",
		"apply": Callable(self, "_apply_audio_music_volume")
	})
	_settings.append({
		"id": "audio_files_expanded",
		"name": "АУДИО: отдельные файлы",
		"type": "bool",
		"value": _audio_files_expanded,
		"desc": "ON — раскрыть точные настройки громкости каждого аудиофайла.",
		"apply": Callable(self, "_apply_audio_files_expanded")
	})
	if _audio_files_expanded:
		_append_current_music_setting("audio_menu_music_volume_db", "   └ Музыка меню: Cell_ColloniyMusic_2 (дБ)", NodePath("MenuMusic"))
		_append_current_music_setting("audio_level_music_volume_db", "   └ Музыка уровня: Cell_ColloniyMusic1_2 (дБ)", NodePath("LevelMusic"))
		_append_sfx_audio_setting("audio_fire_cell_1_volume_db", "   └ Выстрел: FireCell_1 (дБ)", &"fire_cell_1", DEFAULT_FIRE_SOUND_1_VOLUME_DB)
		_append_sfx_audio_setting("audio_fire_cell_2_volume_db", "   └ Выстрел: FireCell_2 (дБ)", &"fire_cell_2", DEFAULT_FIRE_SOUND_2_VOLUME_DB)
		_append_sfx_audio_setting("audio_damage_cell_1_volume_db", "   └ Урон: DemageCell (дБ)", &"damage_cell_1", DEFAULT_DAMAGE_SOUND_1_VOLUME_DB)
		_append_sfx_audio_setting("audio_damage_cell_2_volume_db", "   └ Урон: cell_demage_2 (дБ)", &"damage_cell_2", DEFAULT_DAMAGE_SOUND_2_VOLUME_DB)
		_append_sfx_audio_setting("audio_friendly_fire_volume_db", "   └ Лечение: frendly_fire (дБ)", &"friendly_fire", DEFAULT_FRIENDLY_FIRE_VOLUME_DB)
		_append_sfx_audio_setting("audio_shield_1_volume_db", "   └ Щит: shot_shield (дБ)", &"shield_1", DEFAULT_SHIELD_SOUND_1_VOLUME_DB)
		_append_sfx_audio_setting("audio_shield_2_volume_db", "   └ Щит: shot_shield_1 (дБ)", &"shield_2", DEFAULT_SHIELD_SOUND_2_VOLUME_DB)
		_append_sfx_audio_setting("audio_active_perk_volume_db", "   └ Активация перка: active_perk (дБ)", &"active_perk", DEFAULT_ACTIVE_PERK_SOUND_VOLUME_DB)
	_settings.append({
		"id": "audio_print_settings",
		"name": "АУДИО: вывести настройки в лог",
		"type": "bool",
		"value": false,
		"desc": "ON — печатает текущие значения громкости готовым списком для передачи разработчику.",
		"apply": Callable(self, "_apply_audio_print_settings")
	})
	_settings.append({
		"id": "unlock_all_levels",
		"name": "Разблокировать все уровни",
		"type": "bool",
		"value": unlock_all_enabled,
		"desc": "ON — открыть все уровни. OFF — вернуть только 1 уровень.",
		"apply": Callable(self, "_apply_unlock_all_levels")
	})
	var total_stars := 0
	var current_level_stars := 0
	var current_level_num := 1
	if level_manager != null:
		total_stars = int(level_manager.get_total_stars())
		current_level_num = int(level_manager.current_level)
		current_level_stars = int(level_manager.get_level_best_stars(current_level_num))
	_settings.append({
		"id": "total_stars_info",
		"name": "Всего звезд",
		"type": "int",
		"value": total_stars,
		"min": 0,
		"max": 999,
		"desc": "Только для чтения. Общая сумма лучших звезд по уровням.",
		"apply": Callable(self, "_apply_total_stars_info")
	})
	_settings.append({
		"id": "current_level_stars",
		"name": "Звезды текущего уровня",
		"type": "int",
		"value": current_level_stars,
		"min": 0,
		"max": 3,
		"desc": "Enter — ввод. Меняет лучшие звезды для текущего уровня прямо из Dev Panel.",
		"apply": Callable(self, "_apply_current_level_stars")
	})
	_settings.append({
		"id": "clear_all_stars",
		"name": "Сбросить все звезды",
		"type": "bool",
		"value": false,
		"desc": "Временный триггер. ON — очистить весь runtime-звездный прогресс.",
		"apply": Callable(self, "_apply_clear_all_stars")
	})
	_settings.append({
		"id": "fill_easy_stars",
		"name": "Открытые уровни: easy",
		"type": "bool",
		"value": false,
		"desc": "Временный триггер. Выставляет 1 звезду всем открытым уровням, кроме tutorial-уровня 1 (он остается на 3).",
		"apply": Callable(self, "_apply_fill_easy_stars")
	})
	_settings.append({
		"id": "fill_medium_stars",
		"name": "Открытые уровни: medium",
		"type": "bool",
		"value": false,
		"desc": "Временный триггер. Выставляет 2 звезды всем открытым уровням, кроме tutorial-уровня 1 (он остается на 3).",
		"apply": Callable(self, "_apply_fill_medium_stars")
	})
	_settings.append({
		"id": "fill_hard_stars",
		"name": "Открытые уровни: hard",
		"type": "bool",
		"value": false,
		"desc": "Временный триггер. Выставляет 3 звезды всем открытым уровням.",
		"apply": Callable(self, "_apply_fill_hard_stars")
	})
	_settings.append({
		"id": "time_scale",
		"name": "Скорость времени",
		"type": "float",
		"value": Engine.time_scale,
		"min": 0.1,
		"max": 3.0,
		"step": 0.1,
		"desc": "Enter — ввод числа. ←→ — шаг 0.1.",
		"apply": Callable(self, "_apply_time_scale")
	})
	_settings.append({
		"id": "cell_speed",
		"name": "Множитель Скорости",
		"type": "float",
		"value": 1.0,
		"min": 1.0,
		"max": 20.0,
		"step": 1.0,
		"desc": "Enter — ввод числа. ←→ — шаг 1.0. Умножает скорость клеток.",
		"apply": Callable(self, "_apply_cell_speed")
	})
	_settings.append({
		"id": "ai_decision_interval",
		"name": "ИИ: интервал решений",
		"type": "float",
		"value": 2.5,
		"min": 0.2,
		"max": 8.0,
		"step": 0.1,
		"desc": "Влияет на все AIFactionManager. Enter — ввод. ←→ — шаг 0.1.",
		"apply": Callable(self, "_apply_ai_decision_interval")
	})
	_settings.append({
		"id": "tutorial_calibration_step",
		"name": "Tutorial: шаг",
		"type": "int",
		"value": 1,
		"min": 1,
		"max": 4,
		"desc": "1 - своя колония, 2 - bar энергии, 3 - кнопка speed, 4 - move. ←→ меняет активный шаг калибровки.",
		"apply": Callable(self, "_apply_tutorial_calibration_step")
	})
	_settings.append({
		"id": "tutorial_hand_x",
		"name": "Tutorial: hand X",
		"type": "float",
		"value": 0.0,
		"step": 1.0,
		"desc": "Смещение руки по X в пикселях. Enter — ввод. ←→ — шаг 1, удержание ускоряет.",
		"apply": Callable(self, "_apply_tutorial_hand_x")
	})
	_settings.append({
		"id": "tutorial_hand_y",
		"name": "Tutorial: hand Y",
		"type": "float",
		"value": 0.0,
		"step": 1.0,
		"desc": "Смещение руки по Y в пикселях. Enter — ввод. ←→ — шаг 1, удержание ускоряет.",
		"apply": Callable(self, "_apply_tutorial_hand_y")
	})
	_settings.append({
		"id": "tutorial_pulse_x",
		"name": "Tutorial: pulse X",
		"type": "float",
		"value": 0.0,
		"step": 1.0,
		"desc": "Смещение круга/пульса по X в пикселях. Enter — ввод. ←→ — шаг 1, удержание ускоряет.",
		"apply": Callable(self, "_apply_tutorial_pulse_x")
	})
	_settings.append({
		"id": "tutorial_pulse_y",
		"name": "Tutorial: pulse Y",
		"type": "float",
		"value": 0.0,
		"step": 1.0,
		"desc": "Смещение круга/пульса по Y в пикселях. Enter — ввод. ←→ — шаг 1, удержание ускоряет.",
		"apply": Callable(self, "_apply_tutorial_pulse_y")
	})
	_settings.append({
		"id": "tutorial_print_calibration",
		"name": "Tutorial: вывести в лог",
		"type": "bool",
		"value": false,
		"desc": "Печатает текущую калибровку tutorial pointer готовым блоком для копирования.",
		"apply": Callable(self, "_apply_tutorial_print_calibration")
	})
	_refresh_tutorial_calibration_settings_from_manager()
	
func _append_current_music_setting(setting_id: String, setting_name: String, node_path: NodePath) -> void:
	var player := _get_current_scene_audio_player(node_path)
	if player == null:
		return
	_settings.append({
		"id": setting_id,
		"name": setting_name,
		"type": "float",
		"value": player.volume_db,
		"min": AUDIO_MIN_VOLUME_DB,
		"max": AUDIO_MAX_VOLUME_DB,
		"step": AUDIO_VOLUME_STEP_DB,
		"desc": "Громкость только этого музыкального файла в текущей сцене.",
		"apply": Callable(self, "_apply_music_player_volume").bind(node_path)
	})

func _append_sfx_audio_setting(setting_id: String, setting_name: String, sound_id: StringName, fallback: float) -> void:
	_settings.append({
		"id": setting_id,
		"name": setting_name,
		"type": "float",
		"value": _get_level_sfx_sound_volume(sound_id, fallback),
		"min": AUDIO_MIN_VOLUME_DB,
		"max": AUDIO_MAX_VOLUME_DB,
		"step": AUDIO_VOLUME_STEP_DB,
		"desc": "Громкость только этого файла. Доступно на игровом уровне.",
		"apply": Callable(self, "_apply_sfx_sound_volume").bind(sound_id)
	})

func _refresh_options() -> void:
	options.clear()
	for i in range(_settings.size()):
		options.add_item(_format_line(i))
	if options.get_item_count() > 0:
		_selected = clampi(_selected, 0, options.get_item_count() - 1)
		options.select(_selected)
		call_deferred("_ensure_selected_option_visible")
	_sync_editor()

func _format_line(i: int) -> String:
	var s := _settings[i]
	var name := String(s.get("name", ""))
	var type := String(s.get("type", ""))
	var value: Variant = s.get("value")
	var value_str := ""
	if type == "bool":
		value_str = "ON" if bool(value) else "OFF"
	elif type == "int":
		value_str = str(int(value))
	elif type == "float":
		value_str = _format_float(float(value))
	else:
		value_str = str(value)
	return name + "   " + value_str

func _format_float(v: float) -> String:
	var scaled: float = float(round(v * 100.0)) / 100.0
	var t := str(scaled)
	if t.find(".") == -1:
		return t + ".0"
	return t

func _select_index(i: int) -> void:
	if _settings.is_empty():
		_selected = 0
		_sync_editor()
		return
	_selected = clampi(i, 0, _settings.size() - 1)
	if options.get_item_count() > 0:
		options.select(_selected)
		call_deferred("_ensure_selected_option_visible")
	_sync_editor()

func _ensure_selected_option_visible() -> void:
	if options == null:
		return
	if _selected < 0 or _selected >= options.get_item_count():
		return
	options.ensure_current_is_visible()

func _on_option_selected(index: int) -> void:
	_select_index(index)

func _on_option_activated(index: int) -> void:
	_select_index(index)
	_activate_selected()

func _handle_key(e: InputEventKey) -> void:
	if _settings.is_empty():
		return
	
	if e.keycode == KEY_UP:
		_select_index(_selected - 1)
		return
	
	if e.keycode == KEY_DOWN:
		_select_index(_selected + 1)
		return
	
	if e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
		_activate_selected()
		return
	
	if e.keycode == KEY_LEFT or e.keycode == KEY_RIGHT:
		var dir := -1 if e.keycode == KEY_LEFT else 1
		_adjust_selected(dir, e.echo)

func _activate_selected() -> void:
	if _settings.is_empty():
		return
	
	var s := _settings[_selected]
	var type := String(s.get("type", ""))
	if type == "bool":
		_set_value(_selected, not bool(s.get("value")))
		return
	
	if type == "int" or type == "float":
		numeric_editor.get_line_edit().grab_focus()
		numeric_editor.get_line_edit().select_all()

func _adjust_selected(dir: int, fast_repeat: bool = false) -> void:
	var s := _settings[_selected]
	var type := String(s.get("type", ""))
	if type == "bool":
		_set_value(_selected, not bool(s.get("value")))
		return
	
	if type == "int" or type == "float":
		var step := float(s.get("step", 1.0))
		if fast_repeat:
			step *= 5.0
		var min_v := float(s.get("min", -INF))
		var max_v := float(s.get("max", INF))
		var new_v := float(s.get("value", 0.0)) + step * float(dir)
		new_v = clampf(new_v, min_v, max_v)
		if type == "int":
			_set_value(_selected, int(round(new_v)))
		else:
			_set_value(_selected, new_v)

func _set_value(index: int, value: Variant) -> void:
	_settings[index]["value"] = value
	_apply_setting(index)
	_refresh_options()

func _apply_setting(index: int) -> void:
	var s := _settings[index]
	var apply: Variant = s.get("apply")
	if apply is Callable:
		var c: Callable = apply as Callable
		c.call(s.get("value"))

func _sync_editor() -> void:
	if _settings.is_empty():
		selected_name_label.text = "Нет доступных параметров"
		help_label.text = ""
		numeric_editor_row.visible = false
		bool_editor_row.visible = false
		return
	var setting := _settings[_selected]
	var setting_type := String(setting.get("type", ""))
	selected_name_label.text = String(setting.get("name", ""))
	help_label.text = String(setting.get("desc", ""))
	_updating_editor = true
	numeric_editor_row.visible = setting_type == "int" or setting_type == "float"
	bool_editor_row.visible = setting_type == "bool"
	if numeric_editor_row.visible:
		numeric_editor.min_value = float(setting.get("min", -1000000.0))
		numeric_editor.max_value = float(setting.get("max", 1000000.0))
		numeric_editor.step = float(setting.get("step", 1.0))
		numeric_editor.rounded = setting_type == "int"
		numeric_editor.value = float(setting.get("value", 0.0))
	if bool_editor_row.visible:
		bool_editor.button_pressed = bool(setting.get("value", false))
	_updating_editor = false

func _on_numeric_editor_changed(value: float) -> void:
	if _updating_editor or _settings.is_empty():
		return
	var setting_type := String(_settings[_selected].get("type", ""))
	if setting_type == "int":
		_set_value(_selected, int(roundi(value)))
	else:
		_set_value(_selected, value)

func _on_bool_editor_toggled(enabled: bool) -> void:
	if _updating_editor or _settings.is_empty():
		return
	_set_value(_selected, enabled)

func _decrease_selected_value() -> void:
	_adjust_selected(-1)

func _increase_selected_value() -> void:
	_adjust_selected(1)

func _is_numeric_editor_focused() -> bool:
	return numeric_editor != null and numeric_editor.get_line_edit().has_focus()

func _copy_all_settings_to_clipboard() -> void:
	_commit_pending_numeric_value()
	var lines: PackedStringArray = PackedStringArray([
		"CellColony — настройки Developer Page",
		""
	])
	for setting in _settings:
		var name := String(setting.get("name", ""))
		var setting_type := String(setting.get("type", ""))
		var value: Variant = setting.get("value")
		var value_text := ""
		if setting_type == "bool":
			value_text = "ON" if bool(value) else "OFF"
		elif setting_type == "float":
			value_text = _format_float(float(value))
		else:
			value_text = str(value)
		lines.append(name + " = " + value_text)
	DisplayServer.clipboard_set("\n".join(lines))
	status_label.text = "Все текущие значения скопированы в буфер обмена."

func _copy_selected_setting_to_clipboard() -> void:
	if _settings.is_empty():
		return
	_commit_pending_numeric_value()
	var setting := _settings[_selected]
	var setting_type := String(setting.get("type", ""))
	var value: Variant = setting.get("value")
	var value_text := ""
	if setting_type == "bool":
		value_text = "ON" if bool(value) else "OFF"
	elif setting_type == "float":
		value_text = _format_float(float(value))
	else:
		value_text = str(value)
	var copied_text := String(setting.get("name", "")) + " = " + value_text
	DisplayServer.clipboard_set(copied_text)
	status_label.text = "Скопировано: " + copied_text

func _commit_pending_numeric_value() -> void:
	if _settings.is_empty() or not numeric_editor_row.visible:
		return
	var setting := _settings[_selected]
	var setting_type := String(setting.get("type", ""))
	if setting_type != "int" and setting_type != "float":
		return
	var input_text := numeric_editor.get_line_edit().text.strip_edges()
	if not input_text.is_valid_float():
		return
	var min_value := float(setting.get("min", -1000000.0))
	var max_value := float(setting.get("max", 1000000.0))
	var parsed_value := clampf(float(input_text), min_value, max_value)
	var final_value: Variant = int(roundi(parsed_value)) if setting_type == "int" else parsed_value
	if setting.get("value") == final_value:
		return
	_set_value(_selected, final_value)

func _apply_camera_mode(value: int) -> void:
	var main = get_tree().current_scene
	if main and main.has_method("_toggle_free_camera"):
		var dev_cam = main.get_node_or_null("DevFreeCamera")
		var cam_follow = main.get_node_or_null("Camera2D")
		
		if value == 1: # Игрок
			if cam_follow: cam_follow.enabled = true
			if dev_cam: dev_cam.enabled = false
			if cam_follow: cam_follow.make_current()
		else: # Свободная
			if cam_follow: cam_follow.enabled = false
			if dev_cam: dev_cam.enabled = true
			if dev_cam: dev_cam.make_current()

func _apply_time_scale(v: float) -> void:
	Engine.time_scale = v

func _apply_cell_speed(v: float) -> void:
	var main = get_tree().get_first_node_in_group("main")
	if main and "cell_speed_mult" in main:
		main.cell_speed_mult = v
		print("DEV: Множитель скорости клеток = ", v)

func _apply_show_fps(enabled: bool) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var fps := root.get_node_or_null("HUDLayer/FPSCounter")
	if fps != null and fps is CanvasItem:
		(fps as CanvasItem).visible = enabled

func _get_bus_volume_db(bus_name: StringName, fallback: float) -> float:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return fallback
	return AudioServer.get_bus_volume_db(bus_index)

func _get_level_sfx() -> Node:
	return get_tree().get_first_node_in_group("level_sfx")

func _get_level_sfx_sound_volume(sound_id: StringName, fallback: float) -> float:
	var level_sfx := _get_level_sfx()
	if level_sfx == null or not level_sfx.has_method("get_sound_volume_db"):
		return fallback
	return float(level_sfx.call("get_sound_volume_db", sound_id, fallback))

func _get_current_scene_audio_player(node_path: NodePath) -> AudioStreamPlayer:
	var root := get_tree().current_scene
	if root == null:
		return null
	return root.get_node_or_null(node_path) as AudioStreamPlayer

func _refresh_audio_settings() -> void:
	_set_setting_value_by_id("audio_master_volume_db", _get_bus_volume_db(MASTER_BUS_NAME, 0.0), false)
	_set_setting_value_by_id("audio_music_volume_db", _get_bus_volume_db(MUSIC_BUS_NAME, 0.0), false)
	var menu_music := _get_current_scene_audio_player(NodePath("MenuMusic"))
	if menu_music != null:
		_set_setting_value_by_id("audio_menu_music_volume_db", menu_music.volume_db, false)
	var level_music := _get_current_scene_audio_player(NodePath("LevelMusic"))
	if level_music != null:
		_set_setting_value_by_id("audio_level_music_volume_db", level_music.volume_db, false)
	_set_setting_value_by_id("audio_fire_cell_1_volume_db", _get_level_sfx_sound_volume(&"fire_cell_1", DEFAULT_FIRE_SOUND_1_VOLUME_DB), false)
	_set_setting_value_by_id("audio_fire_cell_2_volume_db", _get_level_sfx_sound_volume(&"fire_cell_2", DEFAULT_FIRE_SOUND_2_VOLUME_DB), false)
	_set_setting_value_by_id("audio_damage_cell_1_volume_db", _get_level_sfx_sound_volume(&"damage_cell_1", DEFAULT_DAMAGE_SOUND_1_VOLUME_DB), false)
	_set_setting_value_by_id("audio_damage_cell_2_volume_db", _get_level_sfx_sound_volume(&"damage_cell_2", DEFAULT_DAMAGE_SOUND_2_VOLUME_DB), false)
	_set_setting_value_by_id("audio_friendly_fire_volume_db", _get_level_sfx_sound_volume(&"friendly_fire", DEFAULT_FRIENDLY_FIRE_VOLUME_DB), false)
	_set_setting_value_by_id("audio_shield_1_volume_db", _get_level_sfx_sound_volume(&"shield_1", DEFAULT_SHIELD_SOUND_1_VOLUME_DB), false)
	_set_setting_value_by_id("audio_shield_2_volume_db", _get_level_sfx_sound_volume(&"shield_2", DEFAULT_SHIELD_SOUND_2_VOLUME_DB), false)
	_set_setting_value_by_id("audio_active_perk_volume_db", _get_level_sfx_sound_volume(&"active_perk", DEFAULT_ACTIVE_PERK_SOUND_VOLUME_DB), false)

func _apply_audio_master_volume(value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(MASTER_BUS_NAME)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, value)

func _apply_audio_music_volume(value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, value)

func _apply_music_player_volume(value: float, node_path: NodePath) -> void:
	var player := _get_current_scene_audio_player(node_path)
	if player != null:
		player.volume_db = value

func _apply_sfx_sound_volume(value: float, sound_id: StringName) -> void:
	var level_sfx := _get_level_sfx()
	if level_sfx == null or not level_sfx.has_method("set_sound_volume_db"):
		return
	level_sfx.call("set_sound_volume_db", sound_id, value)

func _apply_audio_files_expanded(enabled: bool) -> void:
	_audio_files_expanded = enabled
	_build_settings()
	_refresh_audio_settings()
	_refresh_options()
	_select_setting_by_id("audio_files_expanded")

func _select_setting_by_id(setting_id: String) -> void:
	for i in range(_settings.size()):
		if String(_settings[i].get("id", "")) == setting_id:
			_select_index(i)
			return

func _apply_audio_print_settings(enabled: bool) -> void:
	if not enabled:
		return
	print("[AUDIO TUNING] Передай эти значения:")
	print("master = %.1f dB" % float(_get_setting_value_by_id("audio_master_volume_db", 0.0)))
	print("music = %.1f dB" % float(_get_setting_value_by_id("audio_music_volume_db", 0.0)))
	var menu_music := _get_current_scene_audio_player(NodePath("MenuMusic"))
	if menu_music != null:
		print("menu_music = %.1f dB" % menu_music.volume_db)
	var level_music := _get_current_scene_audio_player(NodePath("LevelMusic"))
	if level_music != null:
		print("level_music = %.1f dB" % level_music.volume_db)
	print("FireCell_1 = %.1f dB" % _get_level_sfx_sound_volume(&"fire_cell_1", DEFAULT_FIRE_SOUND_1_VOLUME_DB))
	print("FireCell_2 = %.1f dB" % _get_level_sfx_sound_volume(&"fire_cell_2", DEFAULT_FIRE_SOUND_2_VOLUME_DB))
	print("DemageCell = %.1f dB" % _get_level_sfx_sound_volume(&"damage_cell_1", DEFAULT_DAMAGE_SOUND_1_VOLUME_DB))
	print("cell_demage_2 = %.1f dB" % _get_level_sfx_sound_volume(&"damage_cell_2", DEFAULT_DAMAGE_SOUND_2_VOLUME_DB))
	print("frendly_fire = %.1f dB" % _get_level_sfx_sound_volume(&"friendly_fire", DEFAULT_FRIENDLY_FIRE_VOLUME_DB))
	print("shot_shield = %.1f dB" % _get_level_sfx_sound_volume(&"shield_1", DEFAULT_SHIELD_SOUND_1_VOLUME_DB))
	print("shot_shield_1 = %.1f dB" % _get_level_sfx_sound_volume(&"shield_2", DEFAULT_SHIELD_SOUND_2_VOLUME_DB))
	print("active_perk = %.1f dB" % _get_level_sfx_sound_volume(&"active_perk", DEFAULT_ACTIVE_PERK_SOUND_VOLUME_DB))
	_set_setting_value_by_id("audio_print_settings", false)

func _apply_ai_decision_interval(v: float) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	_apply_ai_prop_recursive(root, "decision_interval", v)

func _get_tutorial_manager() -> Node:
	return get_tree().get_first_node_in_group("tutorial_manager")

func _get_selected_tutorial_step_key() -> String:
	var raw_step := int(_get_setting_value_by_id("tutorial_calibration_step", 1))
	match raw_step:
		2:
			return "energy_bar"
		3:
			return "speed_button"
		4:
			return "move_anywhere"
		_:
			return "intro_colony"

func _apply_tutorial_calibration_step(_value: int) -> void:
	_refresh_tutorial_calibration_settings_from_manager()

func _apply_tutorial_hand_x(value: float) -> void:
	_apply_tutorial_calibration_axis("hand", "x", value)

func _apply_tutorial_hand_y(value: float) -> void:
	_apply_tutorial_calibration_axis("hand", "y", value)

func _apply_tutorial_pulse_x(value: float) -> void:
	_apply_tutorial_calibration_axis("pulse", "x", value)

func _apply_tutorial_pulse_y(value: float) -> void:
	_apply_tutorial_calibration_axis("pulse", "y", value)

func _apply_tutorial_calibration_axis(target: String, axis: String, value: float) -> void:
	var tutorial_manager := _get_tutorial_manager()
	if tutorial_manager == null or not tutorial_manager.has_method("set_pointer_calibration_axis"):
		print("[TUTORIAL CALIBRATION] TutorialManager не найден. Открой tutorial-уровень 1.")
		return
	tutorial_manager.set_pointer_calibration_axis(_get_selected_tutorial_step_key(), target, axis, value)

func _apply_tutorial_print_calibration(enabled: bool) -> void:
	if not enabled:
		return
	var tutorial_manager := _get_tutorial_manager()
	if tutorial_manager == null or not tutorial_manager.has_method("get_pointer_calibration"):
		print("[TUTORIAL CALIBRATION] TutorialManager не найден. Открой tutorial-уровень 1.")
		_set_setting_value_by_id("tutorial_print_calibration", false)
		return
	var step_key := _get_selected_tutorial_step_key()
	var config: Dictionary = tutorial_manager.get_pointer_calibration(step_key)
	var hand: Vector2 = config.get("hand", Vector2.ZERO)
	var pulse: Vector2 = config.get("pulse", Vector2.ZERO)
	print("[TUTORIAL CALIBRATION] Скопируй этот блок в DEFAULT_POINTER_CALIBRATIONS:")
	print('"%s": {' % step_key)
	print('\t"hand": Vector2(%.1f, %.1f),' % [hand.x, hand.y])
	print('\t"pulse": Vector2(%.1f, %.1f),' % [pulse.x, pulse.y])
	print('},')
	_set_setting_value_by_id("tutorial_print_calibration", false)

func _refresh_tutorial_calibration_settings_from_manager() -> void:
	var tutorial_manager := _get_tutorial_manager()
	if tutorial_manager == null or not tutorial_manager.has_method("get_pointer_calibration"):
		help_label.text = "TutorialManager не найден. Для калибровки открой tutorial-уровень 1."
		return
	var config: Dictionary = tutorial_manager.get_pointer_calibration(_get_selected_tutorial_step_key())
	_set_setting_value_by_id("tutorial_hand_x", float(config.get("hand", Vector2.ZERO).x), false)
	_set_setting_value_by_id("tutorial_hand_y", float(config.get("hand", Vector2.ZERO).y), false)
	_set_setting_value_by_id("tutorial_pulse_x", float(config.get("pulse", Vector2.ZERO).x), false)
	_set_setting_value_by_id("tutorial_pulse_y", float(config.get("pulse", Vector2.ZERO).y), false)
	_refresh_options()

func _get_setting_value_by_id(setting_id: String, default_value: Variant = null) -> Variant:
	for i in range(_settings.size()):
		if String(_settings[i].get("id", "")) == setting_id:
			return _settings[i].get("value", default_value)
	return default_value

func _apply_ai_prop_recursive(n: Node, prop: StringName, v: float) -> void:
	if prop in n:
		n.set(prop, v)
	for c in n.get_children():
		_apply_ai_prop_recursive(c, prop, v)

func _apply_unlock_all_levels(enabled: bool) -> void:
	var level_manager := get_node_or_null("/root/LevelManager")
	if level_manager == null:
		return

	if enabled:
		level_manager.unlock_all_levels()
	else:
		level_manager.reset_level_unlocks()

	var root := get_tree().current_scene
	if root != null and root.has_method("refresh_unlocked_levels"):
		root.refresh_unlocked_levels()
	_refresh_star_settings_from_manager()

func _apply_total_stars_info(_value: int) -> void:
	_refresh_star_settings_from_manager()

func _apply_current_level_stars(value: int) -> void:
	var level_manager := get_node_or_null("/root/LevelManager")
	if level_manager == null:
		return
	level_manager.set_level_stars_for_debug(int(level_manager.current_level), value)
	_refresh_progress_views()

func _apply_clear_all_stars(enabled: bool) -> void:
	if not enabled:
		return
	var level_manager := get_node_or_null("/root/LevelManager")
	if level_manager == null:
		return
	level_manager.clear_all_stars()
	_refresh_progress_views()
	_set_setting_value_by_id("clear_all_stars", false)

func _apply_fill_easy_stars(enabled: bool) -> void:
	_apply_fill_stars_trigger(enabled, 1, "fill_easy_stars")

func _apply_fill_medium_stars(enabled: bool) -> void:
	_apply_fill_stars_trigger(enabled, 2, "fill_medium_stars")

func _apply_fill_hard_stars(enabled: bool) -> void:
	_apply_fill_stars_trigger(enabled, 3, "fill_hard_stars")

func _apply_fill_stars_trigger(enabled: bool, stars: int, setting_id: String) -> void:
	if not enabled:
		return
	var level_manager := get_node_or_null("/root/LevelManager")
	if level_manager == null:
		return
	level_manager.fill_unlocked_levels_with_stars(stars)
	_refresh_progress_views()
	_set_setting_value_by_id(setting_id, false)

func _refresh_progress_views() -> void:
	var root := get_tree().current_scene
	if root != null and root.has_method("refresh_unlocked_levels"):
		root.refresh_unlocked_levels()
	_refresh_star_settings_from_manager()

func _refresh_star_settings_from_manager() -> void:
	var level_manager := get_node_or_null("/root/LevelManager")
	if level_manager == null:
		return
	_set_setting_value_by_id("total_stars_info", int(level_manager.get_total_stars()), false)
	_set_setting_value_by_id("current_level_stars", int(level_manager.get_level_best_stars(int(level_manager.current_level))), false)

func _set_setting_value_by_id(setting_id: String, value: Variant, refresh_ui: bool = true) -> void:
	for i in range(_settings.size()):
		if String(_settings[i].get("id", "")) != setting_id:
			continue
		_settings[i]["value"] = value
		if refresh_ui:
			_refresh_options()
		return
