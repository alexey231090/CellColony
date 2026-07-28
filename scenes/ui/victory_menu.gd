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
const FIREWORK_SEQUENCE_DURATION: float = 5.0
const FIREWORK_BURST_INTERVAL: float = 0.45
const FIREWORK_BURST_LIFETIME: float = 1.6
const FIREWORK_COLORS := [
	Color(1.0, 0.88, 0.42, 1.0),
	Color(0.24, 0.86, 1.0, 1.0),
	Color(0.36, 1.0, 0.68, 1.0),
	Color(1.0, 0.54, 0.78, 1.0),
]
const DEFEAT_COLORS := [
	Color(0.82, 0.22, 0.28, 0.85),
	Color(0.48, 0.18, 0.28, 0.6),
	Color(0.24, 0.22, 0.3, 0.42),
]

var overlay: ColorRect
var center_panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var stars_label: Label
var next_btn: Button
var replay_btn: Button
var menu_btn: Button
var fireworks_layer: Control

var _next_level_num: int = 0
var _has_next_level: bool = false
var _result_mode: String = "victory"
var _defeat_fx_layer: Control = null
var _defeat_fx_time: float = 0.0
var _defeat_fx_particles: Array[Dictionary] = []

func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func setup(current_level: int, difficulty_stars: String, has_next_level: bool, next_level_num: int) -> void:
	_result_mode = "victory"
	_has_next_level = has_next_level
	_next_level_num = next_level_num
	title_label.text = "ПОБЕДА"
	title_label.label_settings.font_color = ACCENT_COLOR
	title_label.label_settings.shadow_color = Color(0.1, 0.9, 0.58, 0.22)
	subtitle_label.text = "Уровень %d завершен" % current_level
	stars_label.text = difficulty_stars
	next_btn.text = "СЛЕДУЮЩИЙ УРОВЕНЬ" if _has_next_level else "В ГЛАВНОЕ МЕНЮ"
	stars_label.visible = true
	next_btn.visible = true
	_apply_result_palette(false)

func setup_defeat(current_level: int) -> void:
	_result_mode = "defeat"
	_has_next_level = false
	_next_level_num = current_level
	title_label.text = "КОЛОНИЯ РАЗРУШЕНА"
	title_label.label_settings.font_color = Color(1.0, 0.42, 0.5, 1.0)
	title_label.label_settings.shadow_color = Color(0.92, 0.18, 0.22, 0.2)
	subtitle_label.text = "Уровень %d потерян\nСеть распалась." % current_level
	stars_label.text = ""
	stars_label.visible = false
	next_btn.visible = false
	_apply_result_palette(true)

func show_victory() -> void:
	visible = true
	_reset_victory_visuals()
	_animate_victory_panel()
	_play_fireworks_sequence()

func show_defeat() -> void:
	visible = true
	_reset_victory_visuals()
	_animate_victory_panel()
	_play_defeat_effect()

func _build_ui() -> void:
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	fireworks_layer = Control.new()
	fireworks_layer.name = "FireworksLayer"
	fireworks_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fireworks_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(fireworks_layer)

	_defeat_fx_layer = Control.new()
	_defeat_fx_layer.name = "DefeatFxLayer"
	_defeat_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_defeat_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_defeat_fx_layer.z_index = 1
	_defeat_fx_layer.draw.connect(_draw_defeat_fx)
	_defeat_fx_layer.visible = false
	overlay.add_child(_defeat_fx_layer)

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

func _apply_result_palette(is_defeat: bool) -> void:
	var panel_style := center_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style != null:
		panel_style = panel_style.duplicate()
		if is_defeat:
			panel_style.bg_color = Color(0.11, 0.08, 0.12, 0.94)
			panel_style.border_color = Color(0.92, 0.3, 0.42, 0.34)
		else:
			panel_style.bg_color = PANEL_BG
			panel_style.border_color = PANEL_BORDER
		center_panel.add_theme_stylebox_override("panel", panel_style)

	if is_defeat:
		overlay.color = Color(0.0, 0.0, 0.0, 0.8)
		replay_btn.text = "ПОВТОРИТЬ ПОПЫТКУ"
		menu_btn.text = "ОТСТУПИТЬ В МЕНЮ"
	else:
		overlay.color = Color(0.0, 0.0, 0.0, 0.72)
		replay_btn.text = "ПЕРЕИГРАТЬ"
		menu_btn.text = "В МЕНЮ"

func _reset_victory_visuals() -> void:
	overlay.visible = true
	overlay.modulate.a = 0.0
	center_panel.modulate.a = 0.0
	center_panel.scale = Vector2(0.82, 0.82)
	center_panel.pivot_offset = center_panel.size * 0.5
	center_panel.position = Vector2.ZERO
	stars_label.modulate.a = 0.0
	next_btn.modulate.a = 0.0 if next_btn.visible else 1.0
	replay_btn.modulate.a = 0.0
	menu_btn.modulate.a = 0.0
	_clear_fireworks()
	_reset_defeat_fx()

func _animate_victory_panel() -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3)
	tween.tween_property(center_panel, "modulate:a", 1.0, 0.24)
	tween.tween_property(center_panel, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if stars_label.visible:
		tween.chain().tween_property(stars_label, "modulate:a", 1.0, 0.18)
	if next_btn.visible:
		tween.parallel().tween_property(next_btn, "modulate:a", 1.0, 0.16)
	tween.parallel().tween_property(replay_btn, "modulate:a", 1.0, 0.16)
	tween.parallel().tween_property(menu_btn, "modulate:a", 1.0, 0.16)

func _clear_fireworks() -> void:
	if fireworks_layer == null:
		return
	for child in fireworks_layer.get_children():
		child.queue_free()

func _reset_defeat_fx() -> void:
	_defeat_fx_time = 0.0
	_defeat_fx_particles.clear()
	if _defeat_fx_layer != null:
		_defeat_fx_layer.visible = false
		_defeat_fx_layer.queue_redraw()


func _play_fireworks_sequence() -> void:
	if fireworks_layer == null:
		return
	_clear_fireworks()
	var viewport_size := get_viewport().get_visible_rect().size
	var firework_positions := [
		Vector2(viewport_size.x * 0.22, viewport_size.y * 0.24),
		Vector2(viewport_size.x * 0.78, viewport_size.y * 0.2),
		Vector2(viewport_size.x * 0.32, viewport_size.y * 0.38),
		Vector2(viewport_size.x * 0.7, viewport_size.y * 0.36),
		Vector2(viewport_size.x * 0.5, viewport_size.y * 0.18),
	]
	var burst_count := int(ceil(FIREWORK_SEQUENCE_DURATION / FIREWORK_BURST_INTERVAL))
	for i in range(burst_count):
		var burst_pos: Vector2 = firework_positions[i % firework_positions.size()]
		var burst_color: Color = FIREWORK_COLORS[i % FIREWORK_COLORS.size()]
		_spawn_firework_burst(burst_pos, burst_color, FIREWORK_BURST_INTERVAL * i)

func _spawn_firework_burst(position: Vector2, color: Color, delay: float) -> void:
	var particles := _make_firework_particles(color, FIREWORK_BURST_LIFETIME, 42)
	particles.position = position
	particles.emitting = false
	fireworks_layer.add_child(particles)
	var start_tween := create_tween()
	start_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	start_tween.tween_interval(delay)
	start_tween.tween_callback(func() -> void:
		if is_instance_valid(particles):
			particles.restart()
			particles.emitting = true
	)

func _make_firework_particles(color: Color, lifetime: float, amount: int) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 1.0
	particles.randomness = 0.45
	particles.local_coords = false
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 140.0
	particles.initial_velocity_max = 300.0
	particles.gravity = Vector2(0.0, 180.0)
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.6
	particles.color = color
	particles.color_ramp = _make_firework_ramp(color)
	particles.modulate = color
	return particles

func _play_defeat_effect() -> void:
	if _defeat_fx_layer == null:
		return
	_reset_defeat_fx()
	var viewport_size := get_viewport().get_visible_rect().size
	for i in range(22):
		var color: Color = DEFEAT_COLORS[i % DEFEAT_COLORS.size()]
		var x := randf_range(viewport_size.x * 0.14, viewport_size.x * 0.86)
		var y := randf_range(viewport_size.y * 0.04, viewport_size.y * 0.42)
		var length := randf_range(26.0, 84.0)
		var speed := randf_range(38.0, 96.0)
		var sway := randf_range(-18.0, 18.0)
		var width := randf_range(2.0, 5.0)
		var phase := randf_range(0.0, TAU)
		_defeat_fx_particles.append({
			"pos": Vector2(x, y),
			"length": length,
			"speed": speed,
			"sway": sway,
			"width": width,
			"phase": phase,
			"color": color,
		})
	_defeat_fx_layer.visible = true
	_defeat_fx_layer.queue_redraw()

func _process(delta: float) -> void:
	if not visible or _defeat_fx_layer == null or not _defeat_fx_layer.visible:
		return
	_defeat_fx_time += delta
	var viewport_size := get_viewport().get_visible_rect().size
	for particle in _defeat_fx_particles:
		var pos: Vector2 = particle["pos"]
		pos.y += float(particle["speed"]) * delta
		pos.x += sin(_defeat_fx_time * 1.6 + float(particle["phase"])) * float(particle["sway"]) * delta
		if pos.y - float(particle["length"]) > viewport_size.y * 0.9:
			pos.y = randf_range(-120.0, -20.0)
			pos.x = randf_range(viewport_size.x * 0.14, viewport_size.x * 0.86)
		particle["pos"] = pos
	_defeat_fx_layer.queue_redraw()

func _draw_defeat_fx() -> void:
	if _defeat_fx_layer == null or not _defeat_fx_layer.visible:
		return
	for particle in _defeat_fx_particles:
		var pos: Vector2 = particle["pos"]
		var length: float = float(particle["length"])
		var width: float = float(particle["width"])
		var color: Color = particle["color"]
		var tail := pos - Vector2(0.0, length)
		_defeat_fx_layer.draw_line(tail, pos, color, width, true)
		_defeat_fx_layer.draw_circle(pos, width * 0.55, Color(color.r, color.g, color.b, minf(1.0, color.a + 0.12)))

func _make_firework_ramp(color: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		color.lightened(0.2),
		color,
		Color(color.r, color.g, color.b, 0.0),
	])
	return gradient

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
