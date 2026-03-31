extends Camera2D
## Камера, которая следует за группой клеток игрока.
## Если игрок проиграл — переключается в режим наблюдателя (WASD + скролл).

@export var follow_speed: float = 3.0
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 0.1
@export var max_zoom: float = 0.7
@export var padding: float = 1200.0

## Режим наблюдателя
@export var spectator_move_speed: float = 900.0

## Настройки "заглядывания" вперед
@export var look_ahead_factor: float = 1.2
@export var look_ahead_speed: float = 1.5
@export var look_ahead_max: float = 600.0

var _spectator_mode: bool = false
var _forced_spectator: bool = false
var _spectator_label: Label = null
var _is_first_frame: bool = true
var _current_look_ahead: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Создаём уведомление для наблюдателя (CanvasLayer, чтобы не масштабировалось)
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	_spectator_label = Label.new()
	_spectator_label.text = "☠ Ты проиграл! Наблюдаешь за битвой...\nWASD — перемещение  |  Колесо мыши — зум"
	_spectator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spectator_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_spectator_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_spectator_label.position.y = 20

	var ls = LabelSettings.new()
	ls.font_size = 24
	ls.font_color = Color(1.0, 0.85, 0.3, 0.95)
	ls.outline_size = 5
	ls.outline_color = Color(0.1, 0.05, 0.0, 0.9)
	ls.shadow_size = 3
	ls.shadow_color = Color(0, 0, 0, 0.7)
	ls.shadow_offset = Vector2(1, 2)
	_spectator_label.label_settings = ls

	ui_layer.add_child(_spectator_label)
	_spectator_label.hide()

func _process(delta: float) -> void:
	var player_cells = get_tree().get_nodes_in_group("player_cells")
	var spectator_active := _forced_spectator or player_cells.is_empty()

	if not spectator_active:
		# === Режим слежения ===
		if _spectator_mode:
			_spectator_mode = false
			_spectator_label.hide()
			# Мы НЕ сбрасываем _is_first_frame здесь, 
			# чтобы при перезахвате первой клетки камера сразу прыгнула на неё

		var avg_pos = Vector2.ZERO
		var avg_vel = Vector2.ZERO
		var min_pos = player_cells[0].global_position
		var max_pos = player_cells[0].global_position

		for cell in player_cells:
			avg_pos += cell.global_position
			avg_vel += cell.velocity
			min_pos.x = min(min_pos.x, cell.global_position.x)
			min_pos.y = min(min_pos.y, cell.global_position.y)
			max_pos.x = max(max_pos.x, cell.global_position.x)
			max_pos.y = max(max_pos.y, cell.global_position.y)

		avg_pos /= player_cells.size()
		avg_vel /= player_cells.size()
		
		# Расчет смещения Look-ahead
		var target_look_ahead = avg_vel * look_ahead_factor
		if target_look_ahead.length() > look_ahead_max:
			target_look_ahead = target_look_ahead.normalized() * look_ahead_max
			
		_current_look_ahead = _current_look_ahead.lerp(target_look_ahead, look_ahead_speed * delta)
		
		var final_pos = avg_pos + _current_look_ahead
		
		# Расчет зума
		var rect_size = max_pos - min_pos + Vector2(padding, padding)
		var screen_size = get_viewport_rect().size
		var target_zoom_v = screen_size.y / rect_size.y
		var target_zoom_h = screen_size.x / rect_size.x
		var target_zoom = clamp(min(target_zoom_v, target_zoom_h), min_zoom, max_zoom)
		
		# Мгновенная привязка ПРИ ПОЯВЛЕНИИ ПЕРВЫХ КЛЕТОК
		if _is_first_frame:
			global_position = final_pos
			zoom = Vector2(target_zoom, target_zoom)
			_is_first_frame = false
		else:
			global_position = global_position.lerp(final_pos, follow_speed * delta)
			zoom = zoom.lerp(Vector2(target_zoom, target_zoom), zoom_speed * delta)
	else:
		# === Режим наблюдателя ===
		# Если мы в режиме наблюдателя, но флаг _is_first_frame еще поднят, 
		# это значит, что мы ЕЩЕ НЕ НАШЛИ ПЕРВЫХ КЛЕТОК. Не сбрасываем его.
		if not _spectator_mode:
			_spectator_mode = true
			_spectator_label.text = "DEV: свободная камера включена\nWASD — перемещение  |  Колесо мыши — зум" if _forced_spectator else "☠ Ты проиграл! Наблюдаешь за битвой...\nWASD — перемещение  |  Колесо мыши — зум"
			_spectator_label.show()

		_handle_spectator_movement(delta)

func _handle_spectator_movement(delta: float) -> void:
	var move_dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		move_dir.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		move_dir.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		move_dir.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		move_dir.y -= 1

	if move_dir != Vector2.ZERO:
		# Скорость перемещения увеличивается при сильном зуме (чтобы не ползти)
		var effective_speed = spectator_move_speed / zoom.x
		global_position += move_dir.normalized() * effective_speed * delta

func _unhandled_input(event: InputEvent) -> void:
	if not _spectator_mode: return

	# Зум колесом мыши в режиме наблюдателя
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = (zoom * 1.12).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = (zoom * 0.89).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))

func set_forced_spectator(p_enabled: bool) -> void:
	_forced_spectator = p_enabled
	if p_enabled:
		_spectator_mode = true
		_is_first_frame = false
		if _spectator_label:
			_spectator_label.text = "DEV: свободная камера включена\nWASD — перемещение  |  Колесо мыши — зум"
			_spectator_label.show()
	else:
		_spectator_mode = false
		_is_first_frame = true
		if _spectator_label:
			_spectator_label.hide()

func is_forced_spectator() -> bool:
	return _forced_spectator
