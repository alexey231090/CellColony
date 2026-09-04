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
const MASTER_BUS_NAME: StringName = &"Master"
const MUSIC_BUS_NAME: StringName = &"Music"
const BUTTON_HOVER_SOUND := preload("res://audio/Button_click.ogg")
const BUTTON_HOVER_VOLUME_DB: float = 0.0
const BUTTON_CLICK_SOUND := preload("res://audio/clickWhooh.ogg")
const BUTTON_CLICK_VOLUME_DB: float = -14.0
const BUTTON_CLICK_PITCH_SCALE: float = 1.8
const WON_MUSIC := preload("res://audio/won_music.wav")
const LOSE_MUSIC := preload("res://audio/lose_music_0.ogg")
const ONE_STAR_BANNER := preload("res://assets/sprites/oneStar.png")
const TWO_STAR_BANNER := preload("res://assets/sprites/twoStars.png")
const THREE_STAR_BANNER := preload("res://assets/sprites/freeStars.png")
const DEFEAT_BANNER := preload("res://assets/sprites/lose.png")
const FIREWORK_SOUNDS := [
	preload("res://audio/Single_crisp_firewor_#1.wav"),
	preload("res://audio/Single_crisp_firewor_#2.wav"),
	preload("res://audio/Single_crisp_firewor_#3.wav"),
	preload("res://audio/Single_crisp_firewor_#4.wav"),
]
const FIREWORK_CRACK_SOUND := preload("res://audio/Sharp_firework_crack_#1.wav")
const FIREWORK_SOUND_POOL_SIZE: int = 4
const FIREWORK_SEQUENCE_DURATION: float = 5.0
const FIREWORK_BURST_INTERVAL: float = 0.45
const FIREWORK_BURST_LIFETIME: float = 1.6
const SILENT_FIREWORK_INTERVAL: float = 2.0
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
var result_root: Control
var result_banner: TextureRect
var center_panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var next_btn: Button
var replay_btn: Button
var menu_btn: Button
var fireworks_layer: Control
var ui_hover_sfx: AudioStreamPlayer
var ui_click_sfx: AudioStreamPlayer
var won_music: AudioStreamPlayer
var lose_music: AudioStreamPlayer
var firework_crack_sfx: AudioStreamPlayer
var _firework_sound_players: Array[AudioStreamPlayer] = []
var _firework_sound_player_index: int = 0
var _firework_burst_count: int = 0
var _firework_rng := RandomNumberGenerator.new()
var _initial_fireworks_finished: bool = false
var _silent_fireworks_active: bool = false
var _firework_sequence_tween: Tween = null
var _silent_firework_tween: Tween = null
var _title_tween: Tween = null

var _next_level_num: int = 0
var _has_next_level: bool = false
var _result_mode: String = "victory"
var _defeat_fx_layer: Control = null
var _defeat_fx_time: float = 0.0
var _defeat_fx_particles: Array[Dictionary] = []

func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	_firework_rng.randomize()
	_setup_audio_players()
	_build_ui()
	visible = false

func setup(current_level: int, difficulty_stars: String, has_next_level: bool, next_level_num: int) -> void:
	_result_mode = "victory"
	_has_next_level = has_next_level
	_next_level_num = next_level_num
	title_label.text = "ПОБЕДА"
	title_label.label_settings.font_color = ACCENT_COLOR
	title_label.label_settings.shadow_color = Color(0.1, 0.9, 0.58, 0.22)
	subtitle_label.text = ""
	subtitle_label.visible = false
	next_btn.text = "СЛЕДУЮЩИЙ УРОВЕНЬ" if _has_next_level else "В ГЛАВНОЕ МЕНЮ"
	next_btn.visible = true
	_set_result_banner(difficulty_stars)
	_apply_result_palette(false)

func setup_defeat(current_level: int) -> void:
	_result_mode = "defeat"
	_has_next_level = false
	_next_level_num = current_level
	title_label.text = "ПОРАЖЕНИЕ"
	title_label.label_settings.font_color = Color(1.0, 0.42, 0.5, 1.0)
	title_label.label_settings.shadow_color = Color(0.92, 0.18, 0.22, 0.2)
	subtitle_label.text = ""
	subtitle_label.visible = false
	result_banner.texture = DEFEAT_BANNER
	result_banner.material = null
	result_banner.visible = true
	next_btn.visible = false
	_apply_result_palette(true)

func show_victory() -> void:
	_stop_silent_fireworks()
	_initial_fireworks_finished = false
	if lose_music != null:
		lose_music.stop()
	visible = true
	_reset_victory_visuals()
	_play_won_music()
	_start_title_animation()
	_animate_victory_panel()
	_play_fireworks_sequence()

func show_defeat() -> void:
	_stop_silent_fireworks()
	if won_music != null:
		won_music.stop()
	visible = true
	_reset_victory_visuals()
	_play_lose_music()
	_start_title_animation()
	_animate_victory_panel()
	_play_defeat_effect()

func _setup_audio_players() -> void:
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

	won_music = AudioStreamPlayer.new()
	won_music.name = "WonMusic"
	won_music.stream = WON_MUSIC
	won_music.bus = MUSIC_BUS_NAME
	won_music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(won_music)

	lose_music = AudioStreamPlayer.new()
	lose_music.name = "LoseMusic"
	lose_music.stream = LOSE_MUSIC
	lose_music.bus = MUSIC_BUS_NAME
	lose_music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(lose_music)

	firework_crack_sfx = AudioStreamPlayer.new()
	firework_crack_sfx.name = "FireworkCrackSfx"
	firework_crack_sfx.stream = FIREWORK_CRACK_SOUND
	firework_crack_sfx.bus = MASTER_BUS_NAME
	firework_crack_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(firework_crack_sfx)

	for player_index in range(FIREWORK_SOUND_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "FireworkSfx%d" % player_index
		player.bus = MASTER_BUS_NAME
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_firework_sound_players.append(player)

func _play_won_music() -> void:
	if won_music == null:
		return
	var level_music := _get_level_music()
	if level_music != null:
		won_music.volume_db = level_music.volume_db
		level_music.stop()
	won_music.stop()
	won_music.play()

func _play_lose_music() -> void:
	if lose_music == null:
		return
	var level_music := _get_level_music()
	if level_music != null:
		lose_music.volume_db = level_music.volume_db
		level_music.stop()
	lose_music.stop()
	lose_music.play()

func _get_level_music() -> AudioStreamPlayer:
	var root := get_tree().current_scene
	if root == null:
		return null
	return root.get_node_or_null(NodePath("LevelMusic")) as AudioStreamPlayer

func _start_title_animation() -> void:
	if _title_tween != null:
		_title_tween.kill()
	title_label.rotation_degrees = 0.0
	title_label.pivot_offset = title_label.size * 0.5
	var colors: Array[Color]
	if _result_mode == "victory":
		colors = [
			ACCENT_COLOR,
			ACCENT_GOLD,
			Color(0.32, 0.84, 1.0, 1.0),
		]
	else:
		colors = [
			Color(1.0, 0.42, 0.5, 1.0),
			Color(1.0, 0.68, 0.3, 1.0),
			Color(0.82, 0.42, 0.92, 1.0),
		]
	title_label.label_settings.font_color = colors[0]
	_title_tween = create_tween()
	_title_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_title_tween.set_loops()
	for color_index in range(1, colors.size() + 1):
		var target_rotation := 0.0
		if color_index < colors.size():
			target_rotation = -1.4 if color_index % 2 == 1 else 1.4
		if _result_mode == "defeat":
			target_rotation *= 0.7
		_title_tween.tween_property(title_label, "rotation_degrees", target_rotation, 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_title_tween.parallel().tween_property(title_label.label_settings, "font_color", colors[color_index % colors.size()], 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _play_ui_hover_sound() -> void:
	if not visible or ui_hover_sfx == null:
		return
	ui_hover_sfx.stop()
	ui_hover_sfx.play()

func _play_ui_click_sound() -> void:
	if not visible or ui_click_sfx == null:
		return
	ui_click_sfx.stop()
	ui_click_sfx.play()

func _play_firework_sound() -> void:
	if _firework_sound_players.is_empty():
		return
	var player := _firework_sound_players[_firework_sound_player_index]
	_firework_sound_player_index = (_firework_sound_player_index + 1) % _firework_sound_players.size()
	player.stream = FIREWORK_SOUNDS[_firework_rng.randi_range(0, FIREWORK_SOUNDS.size() - 1)]
	player.play()
	_firework_burst_count += 1
	if _firework_burst_count % 3 == 0 and firework_crack_sfx != null:
		firework_crack_sfx.play()

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
	_defeat_fx_layer.z_index = -100
	_defeat_fx_layer.draw.connect(_draw_defeat_fx)
	_defeat_fx_layer.visible = false
	overlay.add_child(_defeat_fx_layer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	result_root = Control.new()
	result_root.name = "ResultRoot"
	result_root.custom_minimum_size = Vector2(660, 620)
	result_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(result_root)

	result_banner = TextureRect.new()
	result_banner.name = "ResultStarBanner"
	result_banner.position = Vector2(10, -20)
	result_banner.size = Vector2(640, 427)
	result_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_banner.z_index = 3
	result_root.add_child(result_banner)

	title_label = Label.new()
	title_label.name = "ResultTitle"
	title_label.position = Vector2(20, 85)
	title_label.size = Vector2(620, 86)
	title_label.custom_minimum_size = Vector2(620, 86)
	title_label.text = "ПОБЕДА"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.z_index = 4
	var title_settings := LabelSettings.new()
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Impact", "Arial Black", "Trebuchet MS", "Arial"])
	title_font.font_weight = 800
	title_font.font_stretch = 110
	title_settings.font = title_font
	title_settings.font_size = 42
	title_settings.font_color = ACCENT_COLOR
	title_settings.outline_size = 6
	title_settings.outline_color = Color(0.0, 0.0, 0.0, 0.72)
	title_settings.shadow_size = 8
	title_settings.shadow_color = Color(0.1, 0.9, 0.58, 0.22)
	title_label.label_settings = title_settings
	result_root.add_child(title_label)

	center_panel = PanelContainer.new()
	center_panel.name = "ResultPanel"
	center_panel.position = Vector2(115, 180)
	center_panel.custom_minimum_size = Vector2(430, 430)
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
	result_root.add_child(center_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	center_panel.add_child(vbox)

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

func _set_result_banner(difficulty_stars: String) -> void:
	if result_banner == null:
		return
	var star_count := difficulty_stars.count("★")
	if star_count >= 3:
		result_banner.texture = THREE_STAR_BANNER
	elif star_count >= 2:
		result_banner.texture = TWO_STAR_BANNER
	else:
		result_banner.texture = ONE_STAR_BANNER
	result_banner.material = null
	result_banner.visible = true

func _apply_result_palette(is_defeat: bool) -> void:
	var panel_style := center_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style != null:
		panel_style = panel_style.duplicate()
		panel_style.content_margin_top = 85.0 if is_defeat else 115.0
		if is_defeat:
			panel_style.bg_color = Color(0.11, 0.08, 0.12, 0.94)
			panel_style.border_color = Color(0.92, 0.3, 0.42, 0.34)
		else:
			panel_style.bg_color = PANEL_BG
			panel_style.border_color = PANEL_BORDER
		center_panel.add_theme_stylebox_override("panel", panel_style)

	if is_defeat:
		result_banner.visible = true
		title_label.position = Vector2(20, 95)
		overlay.color = Color(0.0, 0.0, 0.0, 0.8)
		replay_btn.text = "ПОВТОРИТЬ ПОПЫТКУ"
		menu_btn.text = "ОТСТУПИТЬ В МЕНЮ"
	else:
		result_banner.visible = true
		title_label.position = Vector2(20, 85)
		overlay.color = Color(0.0, 0.0, 0.0, 0.72)
		replay_btn.text = "ПЕРЕИГРАТЬ"
		menu_btn.text = "В МЕНЮ"

func _reset_victory_visuals() -> void:
	_clear_reward_popups()
	overlay.visible = true
	overlay.modulate.a = 0.0
	center_panel.modulate.a = 0.0
	center_panel.scale = Vector2(0.82, 0.82)
	center_panel.pivot_offset = center_panel.size * 0.5
	result_banner.modulate.a = 0.0 if result_banner.visible else 1.0
	title_label.modulate.a = 0.0
	title_label.rotation_degrees = 0.0
	title_label.pivot_offset = title_label.size * 0.5
	next_btn.modulate.a = 0.0 if next_btn.visible else 1.0
	replay_btn.modulate.a = 0.0
	menu_btn.modulate.a = 0.0
	_clear_fireworks()
	_reset_defeat_fx()

func _clear_reward_popups() -> void:
	for popup_layer: Node in get_tree().get_nodes_in_group("reward_popups"):
		if not is_instance_valid(popup_layer):
			continue
		if popup_layer is CanvasLayer:
			(popup_layer as CanvasLayer).visible = false
		popup_layer.queue_free()

func _animate_victory_panel() -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3)
	tween.tween_property(center_panel, "modulate:a", 1.0, 0.24)
	tween.tween_property(center_panel, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if result_banner.visible:
		tween.parallel().tween_property(result_banner, "modulate:a", 1.0, 0.28)
	tween.parallel().tween_property(title_label, "modulate:a", 1.0, 0.22)
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
	if _firework_sequence_tween != null:
		_firework_sequence_tween.kill()
	_firework_burst_count = 0
	_initial_fireworks_finished = false
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
	var sequence_tail_duration := FIREWORK_BURST_INTERVAL * maxi(0, burst_count - 1) + FIREWORK_BURST_LIFETIME
	_firework_sequence_tween = create_tween()
	_firework_sequence_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_firework_sequence_tween.tween_interval(sequence_tail_duration)
	_firework_sequence_tween.tween_callback(_on_initial_fireworks_finished)

func _on_initial_fireworks_finished() -> void:
	_firework_sequence_tween = null
	_initial_fireworks_finished = true
	_try_start_silent_fireworks()

func _try_start_silent_fireworks() -> void:
	if _silent_fireworks_active or not visible or _result_mode != "victory":
		return
	if not _initial_fireworks_finished:
		return
	_silent_fireworks_active = true
	_schedule_silent_firework()

func _schedule_silent_firework() -> void:
	if not _silent_fireworks_active:
		return
	if _silent_firework_tween != null:
		_silent_firework_tween.kill()
	_silent_firework_tween = create_tween()
	_silent_firework_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_silent_firework_tween.tween_interval(SILENT_FIREWORK_INTERVAL)
	_silent_firework_tween.tween_callback(_spawn_silent_firework)

func _spawn_silent_firework() -> void:
	_silent_firework_tween = null
	if not _silent_fireworks_active or not visible or _result_mode != "victory":
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var burst_pos := Vector2(
		_firework_rng.randf_range(viewport_size.x * 0.14, viewport_size.x * 0.86),
		_firework_rng.randf_range(viewport_size.y * 0.12, viewport_size.y * 0.4)
	)
	var burst_color: Color = FIREWORK_COLORS[_firework_rng.randi_range(0, FIREWORK_COLORS.size() - 1)]
	_spawn_firework_burst(burst_pos, burst_color, 0.0, false)
	_schedule_silent_firework()

func _stop_silent_fireworks() -> void:
	_silent_fireworks_active = false
	if _silent_firework_tween != null:
		_silent_firework_tween.kill()
		_silent_firework_tween = null
	if _firework_sequence_tween != null:
		_firework_sequence_tween.kill()
		_firework_sequence_tween = null

func _spawn_firework_burst(position: Vector2, color: Color, delay: float, play_sound: bool = true) -> void:
	var particles := _make_firework_particles(color, FIREWORK_BURST_LIFETIME, 42)
	particles.position = position
	particles.emitting = false
	fireworks_layer.add_child(particles)
	var start_tween := create_tween()
	start_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	start_tween.tween_interval(delay)
	start_tween.tween_callback(func() -> void:
		if is_instance_valid(particles):
			if play_sound:
				_play_firework_sound()
			particles.restart()
			particles.emitting = true
	)
	start_tween.tween_interval(FIREWORK_BURST_LIFETIME + 0.2)
	start_tween.tween_callback(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
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
	btn.mouse_entered.connect(_play_ui_hover_sound)
	btn.pressed.connect(_play_ui_click_sound)

	return btn

func _on_next_pressed() -> void:
	_stop_result_animations()
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
	_stop_result_animations()
	var current_scene := get_tree().current_scene
	var scene_path := ""
	if current_scene:
		scene_path = String(current_scene.scene_file_path)
	if not scene_path.is_empty() and has_node("/root/LoadingManager"):
		get_node("/root/LoadingManager").transition_to_scene(scene_path)
	else:
		get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	_stop_result_animations()
	if has_node("/root/LoadingManager"):
		get_node("/root/LoadingManager").transition_to_scene("res://scenes/ui/main_menu/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")

func _stop_result_animations() -> void:
	_stop_silent_fireworks()
	if _title_tween != null:
		_title_tween.kill()
		_title_tween = null
