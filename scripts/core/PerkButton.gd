extends Control
class_name PerkButton
## PerkButton - Круглая кнопка перка (упрощённая версия)
## Только тап, без джойстиков

# --- Константы ---
const BUTTON_SIZE: float = 64.0
const ICON_SIZE: float = 28.0

# --- Параметры перка ---
var perk_name: String = ""
var perk_color: Color = Color.WHITE
var perk_index: int = 0

# --- Ссылки ---
var selection_manager: Node = null

func _ready() -> void:
	custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

func _process(delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center = Vector2(BUTTON_SIZE / 2.0, BUTTON_SIZE / 2.0)
	var radius = BUTTON_SIZE / 2.0 - 2.0
	
	# Получаем состояние перка
	if not selection_manager:
		selection_manager = get_tree().get_first_node_in_group("selection_manager")
	
	var is_ready = false
	var cooldown_ratio = 0.0
	
	if selection_manager:
		is_ready = selection_manager._is_perk_ready(perk_name)
		cooldown_ratio = selection_manager.get_perk_cooldown_ratio(perk_name)
	
	# 1. Фон кнопки
	var bg_color = perk_color if is_ready else Color(0.3, 0.3, 0.3)
	draw_circle(center, radius, bg_color)
	
	# 2. Обводка
	var outline_color = perk_color if is_ready else Color(0.5, 0.5, 0.5)
	draw_arc(center, radius, 0, TAU, 32, outline_color, 3.0)
	
	# 3. Индикатор кулдауна (радиальный)
	if cooldown_ratio > 0.0:
		var cd_color = Color(0.8, 0.8, 0.8, 0.7)
		draw_arc(center, radius - 4.0, -PI/2.0, -PI/2.0 + TAU * cooldown_ratio, 32, cd_color, 4.0)
	
	# 4. Иконка перка
	_draw_perk_icon(center)
	
	# 5. Пульсация при готовности
	if is_ready:
		var pulse = (sin(Time.get_ticks_msec() / 200.0) + 1.0) * 0.5
		var glow_color = perk_color
		glow_color.a = 0.2 + pulse * 0.2
		draw_circle(center, radius + 2.0, glow_color)

func _draw_perk_icon(center: Vector2) -> void:
	var size = ICON_SIZE
	var col = Color.WHITE
	
	if perk_name == "shield":
		var pts = PackedVector2Array([
			center + Vector2(-size, -size*0.85), center + Vector2(size, -size*0.85),
			center + Vector2(size, size*0.25), center + Vector2(0, size), center + Vector2(-size, size*0.25)
		])
		draw_colored_polygon(pts, col)
	elif perk_name == "virus":
		# Череп
		draw_circle(center + Vector2(0, -size*0.2), size*0.7, col)
		var jaw = PackedVector2Array([
			center + Vector2(-size*0.4, size*0.2), center + Vector2(size*0.4, size*0.2),
			center + Vector2(size*0.3, size*0.8), center + Vector2(-size*0.3, size*0.8)
		])
		draw_colored_polygon(jaw, col)
		var bg = Color(0, 0, 0, 0.4)
		draw_circle(center + Vector2(-size*0.3, -size*0.2), size*0.15, bg)
		draw_circle(center + Vector2(size*0.3, -size*0.2), size*0.15, bg)
	elif perk_name == "rapid_fire":
		# Три стрелки
		for offset in [-size*0.6, 0, size*0.6]:
			var pts = PackedVector2Array([
				center + Vector2(offset, -size*0.8), 
				center + Vector2(offset + size*0.3, size*0.2), 
				center + Vector2(offset - size*0.3, size*0.2)
			])
			draw_colored_polygon(pts, col)
		draw_rect(Rect2(center.x - size*0.8, center.y + size*0.3, size*1.6, size*0.2), col)
	else:  # speed
		# Молния
		var pts = PackedVector2Array([
			center + Vector2(size*0.3, -size),
			center + Vector2(-size*0.5, size*0.2),
			center + Vector2(size*0.1, size*0.2),
			center + Vector2(-size*0.3, size),
			center + Vector2(size*0.5, -size*0.2),
			center + Vector2(-size*0.1, -size*0.2)
		])
		draw_colored_polygon(pts, col)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		
		if mb.pressed:
			_on_tap()
			get_viewport().set_input_as_handled()
	
	elif event is InputEventScreenTouch:
		if event.pressed:
			_on_tap()
			get_viewport().set_input_as_handled()

func _on_tap() -> void:
	## Простое нажатие кнопки
	if not selection_manager:
		selection_manager = get_tree().get_first_node_in_group("selection_manager")
	
	if not selection_manager:
		return
	
	# Активируем перк
	selection_manager.activate_perk(perk_name)
