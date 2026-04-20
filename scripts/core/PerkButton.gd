extends Control
class_name PerkButton
## PerkButton - Стильная круглая кнопка перка
## Поддерживает эффекты объема, тени и анимацию нажатия

# --- Константы ---
const BUTTON_SIZE: float = 68.0
const ICON_SIZE: float = 24.0
const SHIELD_ICON_HALF_SIZE: float = 30.0
const SHIELD_ICON := preload("res://assets/sprites/ChatGPT Image 20 апр. 2026 г., 23_34_05.png")

# --- Параметры перка ---
var perk_name: String = ""
var perk_color: Color = Color.WHITE
var perk_index: int = 0

# --- Состояние анимации ---
var visual_scale: float = 1.0
var target_scale: float = 1.0

# --- Ссылки ---
var selection_manager: Node = null

# --- StyleBoxes ---
var style_circle = StyleBoxFlat.new()

func _ready() -> void:
	custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	pivot_offset = Vector2(BUTTON_SIZE/2.0, BUTTON_SIZE/2.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	
	# Общая настройка круглой формы
	style_circle.set_corner_radius_all(BUTTON_SIZE / 2.0)
	style_circle.shadow_color = Color(0, 0, 0, 0.4)
	style_circle.shadow_size = 4
	style_circle.shadow_offset = Vector2(0, 3)

var _last_is_ready: bool = false
var _last_cooldown: float = 0.0

func _process(delta: float) -> void:
	var prev_scale = visual_scale
	visual_scale = lerp(visual_scale, target_scale, delta * 15.0)
	scale = Vector2(visual_scale, visual_scale)
	
	if not selection_manager:
		selection_manager = get_tree().get_first_node_in_group("selection_manager")
		
	var needs_redraw = false
	if abs(prev_scale - visual_scale) > 0.001:
		needs_redraw = true
		
	if selection_manager:
		var is_ready = selection_manager._is_perk_ready(perk_name)
		var cd = selection_manager.get_perk_cooldown_ratio(perk_name)
		
		# Перерисовывать, если состояние энергии изменилось:
		if is_ready != _last_is_ready:
			needs_redraw = true
		# Перерисовывать, если кд поменялся
		elif abs(cd - _last_cooldown) > 0.01:
			needs_redraw = true
		# Перерисовывать всё время пока есть кулдаун или если кнопка готова (для эффекта пульсации)
		elif is_ready or cd > 0.0:
			needs_redraw = true
			
		_last_is_ready = is_ready
		_last_cooldown = cd
		
	if needs_redraw:
		queue_redraw()


func _draw() -> void:
	var center = Vector2(BUTTON_SIZE / 2.0, BUTTON_SIZE / 2.0)
	var radius = BUTTON_SIZE / 2.0 - 4.0
	
	if not selection_manager:
		selection_manager = get_tree().get_first_node_in_group("selection_manager")
	
	var is_ready = false
	var cooldown_ratio = 0.0
	
	if selection_manager:
		is_ready = selection_manager._is_perk_ready(perk_name)
		cooldown_ratio = selection_manager.get_perk_cooldown_ratio(perk_name)
	
	# 1. Основной фон кнопки (StyleBox)
	var main_color = perk_color if is_ready else Color(0.2, 0.2, 0.25)
	var rect = Rect2(Vector2.ZERO, size)
	
	style_circle.bg_color = main_color
	style_circle.border_width_left = 2
	style_circle.border_width_top = 2
	style_circle.border_width_right = 2
	style_circle.border_width_bottom = 2
	style_circle.border_color = Color(1, 1, 1, 0.3) if is_ready else Color(1, 1, 1, 0.1)
	
	draw_style_box(style_circle, rect)
	
	# 2. Эффект объема (внутренний градиент/блик)
	if is_ready:
		draw_circle(center - Vector2(radius*0.2, radius*0.2), radius * 0.8, Color(1, 1, 1, 0.15))
	
	# 3. Индикатор кулдауна (затемнение)
	if cooldown_ratio > 0.0:
		var start_angle = -PI/2.0
		var end_angle = start_angle + TAU * cooldown_ratio
		draw_arc(center, radius, start_angle, end_angle, 32, Color.WHITE, 4.0, true)
		# Затемняющий слой
		draw_circle(center, radius, Color(0, 0, 0, 0.4))
	
	# 4. Иконка с тенью
	_draw_perk_icon_with_shadow(center)
	
	# 5. Свечение готовности
	if is_ready:
		var pulse = (sin(Time.get_ticks_msec() / 250.0) + 1.0) * 0.5
		draw_arc(center, radius + 4.0 + pulse * 4.0, 0, TAU, 32, Color(perk_color.r, perk_color.g, perk_color.b, 0.3 - pulse * 0.3), 2.0)

func _draw_perk_icon_with_shadow(center: Vector2) -> void:
	# Тень иконки
	_draw_perk_icon(center + Vector2(1, 2), Color(0, 0, 0, 0.5))
	# Сама иконка
	_draw_perk_icon(center, Color.WHITE)

func _draw_perk_icon(center: Vector2, col: Color) -> void:
	var s = ICON_SIZE
	
	if perk_name == "pause_test":
		# Иконка паузы
		var bar_w = s * 0.25
		var gap = s * 0.4
		draw_rect(Rect2(center.x - gap/2.0 - bar_w, center.y - s*0.6, bar_w, s*1.2), col)
		draw_rect(Rect2(center.x + gap/2.0, center.y - s*0.6, bar_w, s*1.2), col)
	elif perk_name == "shield":
		if SHIELD_ICON != null:
			var icon_rect := Rect2(center - Vector2(SHIELD_ICON_HALF_SIZE, SHIELD_ICON_HALF_SIZE), Vector2(SHIELD_ICON_HALF_SIZE * 2.0, SHIELD_ICON_HALF_SIZE * 2.0))
			draw_texture_rect(SHIELD_ICON, icon_rect, false, col)
	elif perk_name == "virus":
		# Стилизованный вирус (круг с шипами)
		draw_circle(center, s * 0.6, col)
		for i in range(8):
			var angle = i * PI/4.0
			var p1 = center + Vector2(cos(angle), sin(angle)) * s * 0.5
			var p2 = center + Vector2(cos(angle), sin(angle)) * s * 1.0
			draw_line(p1, p2, col, 3.0)
	elif perk_name == "rapid_fire":
		# Три пули/молнии вверх
		for ox in [-s*0.5, 0, s*0.5]:
			var pts = PackedVector2Array([
				center + Vector2(ox, -s), center + Vector2(ox + s*0.25, s*0.2), center + Vector2(ox - s*0.25, s*0.2)
			])
			draw_colored_polygon(pts, col)
	else: # speed
		# Крыло или шевроны
		for oy in [-s*0.4, 0, s*0.4]:
			var pts = PackedVector2Array([
				center + Vector2(-s*0.8, oy - s*0.3), center + Vector2(s*0.2, oy), center + Vector2(-s*0.8, oy + s*0.3)
			])
			draw_colored_polygon(pts, col)
			var pts2 = PackedVector2Array([
				center + Vector2(-s*0.3, oy - s*0.3), center + Vector2(s*0.7, oy), center + Vector2(-s*0.3, oy + s*0.3)
			])
			draw_colored_polygon(pts2, col)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT: return
		
		if mb.pressed:
			target_scale = 0.9
			_on_tap()
		else:
			target_scale = 1.0
		get_viewport().set_input_as_handled()
	
	elif event is InputEventScreenTouch:
		if event.pressed:
			target_scale = 0.9
			_on_tap()
		else:
			target_scale = 1.0
		get_viewport().set_input_as_handled()

func _on_tap() -> void:
	if perk_name == "pause_test":
		var p_menu = get_tree().root.find_child("PauseMenu", true, false)
		if p_menu and p_menu.has_method("toggle_pause"):
			p_menu.toggle_pause()
		return
		
	if not selection_manager:
		selection_manager = get_tree().get_first_node_in_group("selection_manager")
	if selection_manager:
		selection_manager.activate_perk(perk_name)
