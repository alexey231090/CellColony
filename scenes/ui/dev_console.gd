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
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.physical_keycode == KEY_QUOTELEFT:
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
	_settings.append({
		"id": "spectator",
		"name": "Свободная камера",
		"type": "bool",
		"value": false,
		"desc": "WASD + колесо. Enter/←→ — переключить.",
		"apply": Callable(self, "_apply_spectator")
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
	
func _refresh_options() -> void:
	options.clear()
	for i in range(_settings.size()):
		options.add_item(_format_line(i))
	if options.get_item_count() > 0:
		options.select(_selected)

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
		_adjust_selected(dir)
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

func _adjust_selected(dir: int) -> void:
	var s := _settings[_selected]
	var type := String(s.get("type", ""))
	if type == "bool":
		_set_value(_selected, not bool(s.get("value")))
		return
	
	if type == "int" or type == "float":
		var step := float(s.get("step", 1.0))
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

func _apply_spectator(enabled: bool) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	if camera.has_method("set_forced_spectator"):
		camera.call("set_forced_spectator", enabled)
		if enabled and ("min_zoom" in camera):
			camera.zoom = Vector2(camera.min_zoom, camera.min_zoom)
			camera.global_position = Vector2.ZERO

func _apply_time_scale(v: float) -> void:
	Engine.time_scale = v

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

func _apply_ai_prop_recursive(n: Node, prop: StringName, v: float) -> void:
	if prop in n:
		n.set(prop, v)
	for c in n.get_children():
		_apply_ai_prop_recursive(c, prop, v)
