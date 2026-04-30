extends Control

const PANEL_SIZE := Vector2(820.0, 160.0)
const TOP_MARGIN := 92.0
const HUD_TOP_MARGIN := 136.0
const BOTTOM_MARGIN := 160.0

var label: Label = null
var anchor_mode: String = "top"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = PANEL_SIZE
	pivot_offset = size * 0.5
	modulate.a = 0.0
	visible = false
	_create_label()
	_update_layout()

func _create_label() -> void:
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(34.0, 20.0)
	label.size = PANEL_SIZE - Vector2(68.0, 40.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var settings := LabelSettings.new()
	settings.font_size = 24
	settings.font_color = Color(0.92, 0.98, 1.0, 1.0)
	settings.outline_size = 5
	settings.outline_color = Color(0.03, 0.08, 0.14, 0.85)
	settings.shadow_size = 2
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	label.label_settings = settings
	add_child(label)

func set_text_and_show(text: String) -> void:
	if label == null:
		return
	label.text = text
	_update_layout()
	_animate_show()

func hide_panel() -> void:
	if not visible and modulate.a <= 0.0:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y - 10.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(hide)

func set_top_mode() -> void:
	anchor_mode = "top"
	_update_layout()

func set_bottom_mode() -> void:
	anchor_mode = "bottom"
	_update_layout()

func set_hud_top_mode() -> void:
	anchor_mode = "hud_top"
	_update_layout()

func _animate_show() -> void:
	show()
	_update_layout()
	var target_pos := position
	position = target_pos + Vector2(0.0, -12.0)
	modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pos, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_layout() -> void:
	var viewport_size := get_viewport_rect().size
	position.x = (viewport_size.x - size.x) * 0.5
	if anchor_mode == "bottom":
		position.y = viewport_size.y - size.y - BOTTOM_MARGIN
	elif anchor_mode == "hud_top":
		position.y = HUD_TOP_MARGIN
	else:
		position.y = TOP_MARGIN
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.07, 0.14, 0.2, 0.52), true)
	draw_rect(Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)), Color(0.18, 0.34, 0.44, 0.18), true)
	draw_arc(Vector2(size.x * 0.5, size.y * 0.5), size.x * 0.46, PI, TAU, 64, Color(0.52, 0.9, 1.0, 0.12), 2.0)
	draw_line(Vector2(18.0, 18.0), Vector2(size.x - 18.0, 18.0), Color(0.72, 0.96, 1.0, 0.36), 2.0)
	draw_line(Vector2(18.0, size.y - 18.0), Vector2(size.x - 18.0, size.y - 18.0), Color(0.42, 0.78, 0.96, 0.22), 2.0)
