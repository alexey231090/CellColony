extends Control

@onready var panel: Control = $Panel
@onready var title_label: Label = $Panel/VBox/Title
@onready var options: ItemList = $Panel/VBox/Options
@onready var help_label: Label = $Panel/VBox/Help

var _is_open: bool = false
var _tween: Tween = null
var _settings: Array[Dictionary] = []
var _selected: int = 0
var _is_editing: bool = false
var _edit_buffer: String = ""

func _ready() -> void:
	add_to_group("dev_console")
	
	panel.visible = true
	call_deferred("_apply_closed_position")
	
	options.item_selected.connect(_on_option_selected)
	options.item_activated.connect(_on_option_activated)
	
	_build_settings()
	_refresh_options()
	_select_index(0)
	_refresh_help()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		if key_event.physical_keycode == KEY_QUOTELEFT and not key_event.echo:
			_toggle()
			get_viewport().set_input_as_handled()
			return
		
		if _is_open:
			_handle_key(key_event)
			get_viewport().set_input_as_handled()
			return
	
	if _is_open:
		if event is InputEventMouseButton or event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()

func _toggle(force: Variant = null) -> void:
	var target := (not _is_open) if force == null else bool(force)
	if target == _is_open:
		return
	_is_open = target
	
	if is_instance_valid(_tween):
		_tween.kill()
	
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_OUT)
	
	var closed_y := -panel.size.y
	var open_y := 0.0
	var dest_y := open_y if _is_open else closed_y
	_tween.tween_property(panel, "position:y", dest_y, 0.18)
	
	if _is_open:
		options.grab_focus()
		_select_index(_selected)
		_refresh_help()
	else:
		_is_editing = false
		_edit_buffer = ""
		options.release_focus()

func _apply_closed_position() -> void:
	panel.position.y = -panel.size.y
	
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
	
func _refresh_options() -> void:
	options.clear()
	for i in range(_settings.size()):
		options.add_item(_format_line(i))
	if options.get_item_count() > 0:
		options.select(_selected)
		call_deferred("_ensure_selected_option_visible")

func _format_line(i: int) -> String:
	var s := _settings[i]
	var name := String(s.get("name", ""))
	var type := String(s.get("type", ""))
	var value_str := ""
	
	if _is_editing and i == _selected and (type == "int" or type == "float"):
		value_str = _edit_buffer
	else:
		var v: Variant = s.get("value")
		if type == "bool":
			value_str = "ON" if bool(v) else "OFF"
		elif type == "int":
			value_str = str(int(v))
		elif type == "float":
			value_str = _format_float(float(v))
		else:
			value_str = str(v)
	
	var prefix := "▶ " if i == _selected else "  "
	var suffix := "  [ввод]" if (_is_editing and i == _selected and (type == "int" or type == "float")) else ""
	return prefix + name + ": " + value_str + suffix

func _format_float(v: float) -> String:
	var scaled: float = float(round(v * 100.0)) / 100.0
	var t := str(scaled)
	if t.find(".") == -1:
		return t + ".0"
	return t

func _select_index(i: int) -> void:
	if _settings.is_empty():
		_selected = 0
		return
	_selected = clampi(i, 0, _settings.size() - 1)
	if options.get_item_count() > 0:
		options.select(_selected)
		call_deferred("_ensure_selected_option_visible")

func _ensure_selected_option_visible() -> void:
	if options == null:
		return
	if _selected < 0 or _selected >= options.get_item_count():
		return
	options.ensure_current_is_visible()

func _refresh_help() -> void:
	if _settings.is_empty():
		help_label.text = ""
		return
	
	var s := _settings[_selected]
	var desc := String(s.get("desc", ""))
	if _is_editing and (String(s.get("type", "")) == "int" or String(s.get("type", "")) == "float"):
		desc = "Введите число, Enter — применить, Backspace — удалить, Esc — отменить."
	help_label.text = desc

func _on_option_selected(index: int) -> void:
	if _is_editing:
		return
	_select_index(index)
	_refresh_options()
	_refresh_help()

func _on_option_activated(index: int) -> void:
	_select_index(index)
	_activate_selected()

func _handle_key(e: InputEventKey) -> void:
	if e.keycode == KEY_ESCAPE:
		if _is_editing:
			_is_editing = false
			_edit_buffer = ""
			_refresh_options()
			_refresh_help()
			return
		_toggle(false)
		return
	
	if _settings.is_empty():
		return
	
	if e.keycode == KEY_UP:
		if not _is_editing:
			_select_index(_selected - 1)
			_refresh_options()
			_refresh_help()
		return
	
	if e.keycode == KEY_DOWN:
		if not _is_editing:
			_select_index(_selected + 1)
			_refresh_options()
			_refresh_help()
		return
	
	if e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
		_activate_selected()
		return
	
	if e.keycode == KEY_LEFT or e.keycode == KEY_RIGHT:
		if _is_editing:
			return
		var dir := -1 if e.keycode == KEY_LEFT else 1
		_adjust_selected(dir, e.echo)
		return
	
	if _is_editing:
		_handle_edit_input(e)
		return
	
	if e.unicode > 0:
		var ch := char(e.unicode)
		if _is_numeric_setting(_settings[_selected]) and _is_numeric_char(ch):
			_start_edit_with(ch)

func _activate_selected() -> void:
	if _settings.is_empty():
		return
	
	var s := _settings[_selected]
	var type := String(s.get("type", ""))
	if type == "bool":
		_set_value(_selected, not bool(s.get("value")))
		return
	
	if type == "int" or type == "float":
		if _is_editing:
			_commit_edit()
		else:
			_start_edit_with("")

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
	_is_editing = false
	_edit_buffer = ""
	_apply_setting(index)
	_refresh_options()
	_refresh_help()

func _apply_setting(index: int) -> void:
	var s := _settings[index]
	var apply: Variant = s.get("apply")
	if apply is Callable:
		var c: Callable = apply as Callable
		c.call(s.get("value"))

func _start_edit_with(initial: String) -> void:
	_is_editing = true
	_edit_buffer = initial if not initial.is_empty() else _get_current_value_string(_settings[_selected])
	_refresh_options()
	_refresh_help()

func _get_current_value_string(s: Dictionary) -> String:
	var type := String(s.get("type", ""))
	var v = s.get("value")
	if type == "int":
		return str(int(v))
	if type == "float":
		return _format_float(float(v))
	return str(v)

func _handle_edit_input(e: InputEventKey) -> void:
	if e.keycode == KEY_BACKSPACE:
		if _edit_buffer.length() > 0:
			_edit_buffer = _edit_buffer.substr(0, _edit_buffer.length() - 1)
			_refresh_options()
		return
	
	if e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
		_commit_edit()
		return
	
	if e.unicode <= 0:
		return
	
	var ch := char(e.unicode)
	if not _is_numeric_char(ch):
		return
	
	if ch == "-" and _edit_buffer.find("-") != -1:
		return
	if ch == "." and _edit_buffer.find(".") != -1:
		return
	
	_edit_buffer += ch
	_refresh_options()

func _commit_edit() -> void:
	var s := _settings[_selected]
	var type := String(s.get("type", ""))
	var t := _edit_buffer.strip_edges()
	if t.is_empty() or t == "-" or t == ".":
		_is_editing = false
		_edit_buffer = ""
		_refresh_options()
		_refresh_help()
		return
	
	if type == "int":
		var v := int(t)
		var min_v := int(s.get("min", -2147483648))
		var max_v := int(s.get("max", 2147483647))
		v = clampi(v, min_v, max_v)
		_set_value(_selected, v)
	else:
		var v2 := float(t)
		var min_f := float(s.get("min", -INF))
		var max_f := float(s.get("max", INF))
		v2 = clampf(v2, min_f, max_f)
		_set_value(_selected, v2)

func _is_numeric_setting(s: Dictionary) -> bool:
	var type := String(s.get("type", ""))
	return type == "int" or type == "float"

func _is_numeric_char(ch: String) -> bool:
	return (ch >= "0" and ch <= "9") or ch == "." or ch == "-"

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
	_refresh_help()

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
			_refresh_help()
		return
