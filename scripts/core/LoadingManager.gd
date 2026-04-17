extends CanvasLayer

const MIN_DISPLAY_TIME: float = 0.5

var overlay: ColorRect
var panel: VBoxContainer
var spinner: OrganicLoadingSpinner
var title_label: Label
var progress_bar: ProgressBar
var percent_label: Label

var _loading_path: String = ""
var _loaded_scene: PackedScene = null
var _is_loading: bool = false
var _is_finishing: bool = false
var _min_display_elapsed: float = 0.0
var _target_progress: float = 0.0
var _display_progress: float = 0.0

func _ready() -> void:
	layer = 250
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_hide_immediately()

func transition_to_scene(scene_path: String) -> void:
	if scene_path.is_empty() or _is_loading or _is_finishing:
		return

	get_tree().paused = false
	_loading_path = scene_path
	_loaded_scene = null
	_is_loading = true
	_is_finishing = false
	_min_display_elapsed = 0.0
	_target_progress = 0.0
	_display_progress = 0.0
	_update_progress_ui(0.0)
	_show_overlay()

	var err := ResourceLoader.load_threaded_request(scene_path, "PackedScene")
	if err != OK:
		_is_loading = false
		_hide_immediately()
		get_tree().change_scene_to_file(scene_path)

func _process(delta: float) -> void:
	if not _is_loading:
		return

	_min_display_elapsed += delta
	_poll_loading_status()
	_display_progress = lerpf(_display_progress, _target_progress, minf(1.0, delta * 8.0))
	_update_progress_ui(_display_progress)

	if _loaded_scene != null and _min_display_elapsed >= MIN_DISPLAY_TIME and not _is_finishing:
		_is_finishing = true
		_is_loading = false
		_target_progress = 100.0
		_display_progress = 100.0
		_update_progress_ui(100.0)
		_finish_transition.call_deferred()

func _poll_loading_status() -> void:
	if _loaded_scene != null:
		return

	var progress := []
	var status := ResourceLoader.load_threaded_get_status(_loading_path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not progress.is_empty():
				_target_progress = clampf(float(progress[0]) * 100.0, 0.0, 99.0)
		ResourceLoader.THREAD_LOAD_LOADED:
			var loaded := ResourceLoader.load_threaded_get(_loading_path)
			if loaded is PackedScene:
				_loaded_scene = loaded
				_target_progress = 100.0
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_is_loading = false
			_hide_immediately()
			get_tree().change_scene_to_file(_loading_path)

func _finish_transition() -> void:
	var target_scene := _loaded_scene
	var target_path := _loading_path
	_loading_path = ""
	_loaded_scene = null

	if target_scene != null:
		get_tree().change_scene_to_packed(target_scene)
	else:
		get_tree().change_scene_to_file(target_path)

	await get_tree().process_frame
	await get_tree().process_frame
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.14)
	tween.tween_property(panel, "modulate:a", 0.0, 0.12)
	tween.parallel().tween_property(panel, "scale", Vector2(0.98, 0.98), 0.12)
	tween.finished.connect(func():
		overlay.visible = false
		panel.visible = false
		panel.scale = Vector2.ONE
		panel.modulate.a = 1.0
		overlay.modulate.a = 1.0
		_is_finishing = false
	)

func _build_ui() -> void:
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.03, 0.05, 1.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	panel = VBoxContainer.new()
	panel.custom_minimum_size = Vector2(420.0, 320.0)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 18)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)

	spinner = OrganicLoadingSpinner.new()
	spinner.custom_minimum_size = Vector2(180.0, 180.0)
	spinner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_child(spinner)

	title_label = Label.new()
	title_label.text = "Загрузка..."
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_settings := LabelSettings.new()
	title_settings.font_size = 22
	title_settings.font_color = Color(0.92, 0.97, 1.0, 0.96)
	title_settings.outline_size = 5
	title_settings.outline_color = Color(0.0, 0.0, 0.0, 0.75)
	title_settings.shadow_size = 3
	title_settings.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	title_label.label_settings = title_settings
	panel.add_child(title_label)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(320.0, 22.0)
	progress_bar.show_percentage = false
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.12, 0.16, 0.95)
	bg_style.set_corner_radius_all(11)
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.4, 0.7, 1.0, 0.18)
	bg_style.shadow_size = 10
	bg_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	progress_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.28, 0.74, 1.0, 0.96)
	fill_style.set_corner_radius_all(10)
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	panel.add_child(progress_bar)

	percent_label = Label.new()
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var percent_settings := LabelSettings.new()
	percent_settings.font_size = 18
	percent_settings.font_color = Color(0.74, 0.9, 1.0, 0.98)
	percent_settings.outline_size = 4
	percent_settings.outline_color = Color(0.0, 0.0, 0.0, 0.72)
	percent_label.label_settings = percent_settings
	panel.add_child(percent_label)

func _show_overlay() -> void:
	overlay.visible = true
	panel.visible = true
	overlay.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.96, 0.96)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_immediately() -> void:
	overlay.visible = false
	panel.visible = false
	overlay.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.scale = Vector2.ONE

func _update_progress_ui(progress_value: float) -> void:
	var rounded := clampi(int(round(progress_value)), 0, 100)
	progress_bar.value = progress_value
	percent_label.text = "%d%%" % rounded
