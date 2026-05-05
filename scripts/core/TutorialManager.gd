extends Node

const POINTER_SCRIPT = preload("res://scripts/ui/tutorial_pointer.gd")
const HINT_PANEL_SCRIPT = preload("res://scripts/ui/tutorial_hint_panel.gd")

const STEP_INTRO: int = 0
const STEP_CAPTURE_NEUTRAL: int = 1
const STEP_WAIT_CAPTURE: int = 2
const STEP_WAIT_SPEED_ENERGY: int = 3
const STEP_SPEED_PERK: int = 4
const STEP_MOVE_COMMAND: int = 5
const STEP_FREE_PLAY_CONFIRM: int = 6
const STEP_FREE_PLAY: int = 7
const STEP_DONE: int = 8

const MOVE_TARGET_RADIUS: float = 220.0
const MAX_SAFE_ENEMY_DISTANCE: float = 1100.0
const NEUTRAL_HIGHLIGHT_RADIUS: float = 4000.0
const HIGHLIGHT_REFRESH_INTERVAL: float = 0.25
const FREEZE_OVERLAY_LAYER: int = 117
const TUTORIAL_LAYER: int = 118
const PERK_PANEL_WIDTH_BLOCK: float = 150.0
const DEFAULT_POINTER_CALIBRATIONS := {
	"intro_colony": {
		"hand": Vector2(44.0, 56.0),
		"pulse": Vector2(6.0, 15.0),
	},
	"energy_bar": {
		"hand": Vector2(46.0, 86.0),
		"pulse": Vector2(0.0, 0.0),
	},
	"speed_button": {
		"hand": Vector2(49.0, 71.0),
		"pulse": Vector2(3.0, 21.0),
	},
	"move_anywhere": {
		"hand": Vector2(56.0, 282.0),
		"pulse": Vector2(15.0, 231.0),
	},
}

var selection_manager: Node = null
var level_camera: Camera2D = null
var perk_button_panel: PerkButtonPanel = null
var player_start_cell: BaseCell = null
var level_data: Dictionary = {}

var pointer_layer: CanvasLayer = null
var tutorial_pointer: Control = null
var tutorial_hint_panel: Control = null
var freeze_overlay_layer: CanvasLayer = null
var freeze_overlay: Control = null
var perk_guide_panel: Control = null
var corner_hint_label: Label = null

var current_step: int = STEP_INTRO
var recommended_neutral_cell: BaseCell = null
var selected_neutral_cell: BaseCell = null
var move_target_position: Vector2 = Vector2.ZERO
var move_target_radius: float = MOVE_TARGET_RADIUS
var pointer_calibrations: Dictionary = {}
var intro_timer: float = 0.0
var is_finished: bool = false
var pointer_auto_hide_timer: float = -1.0
var perk_guide_revisit_timer: float = -1.0
var has_shown_perk_guide_revisit: bool = false
var _highlight_refresh_timer: float = 0.0
var _highlighted_neutral_ids: Dictionary = {}

func setup(selection: Node, camera: Camera2D, perk_panel: PerkButtonPanel, player_cell: BaseCell, data: Dictionary) -> void:
	selection_manager = selection
	level_camera = camera
	perk_button_panel = perk_panel
	player_start_cell = player_cell
	level_data = data.duplicate(true)
	pointer_calibrations = DEFAULT_POINTER_CALIBRATIONS.duplicate(true)
	add_to_group("tutorial_manager")
	_set_ai_tutorial_paused(true)
	recommended_neutral_cell = _pick_target_neutral()
	move_target_position = _compute_move_target()
	_create_ui()
	_go_to_step(STEP_INTRO)

func _unhandled_input(event: InputEvent) -> void:
	if is_finished:
		return

	if current_step == STEP_INTRO:
		if _is_confirm_press(event):
			_skip_intro()
			get_viewport().set_input_as_handled()
		return

	if current_step == STEP_FREE_PLAY_CONFIRM:
		if _is_confirm_press(event):
			_go_to_step(STEP_FREE_PLAY)
			get_viewport().set_input_as_handled()
		return

	if current_step == STEP_SPEED_PERK:
		return

func can_select_cell(cell: BaseCell) -> bool:
	if is_finished or cell == null:
		return true if is_finished else false

	match current_step:
		STEP_CAPTURE_NEUTRAL:
			return cell.owner_type == BaseCell.OwnerType.NEUTRAL
		STEP_WAIT_CAPTURE:
			return false
		STEP_WAIT_SPEED_ENERGY:
			return true
		STEP_SPEED_PERK:
			return true
		STEP_MOVE_COMMAND:
			return false
		_:
			return true

func can_move_to(world_pos: Vector2) -> bool:
	if is_finished:
		return true

	match current_step:
		STEP_WAIT_SPEED_ENERGY:
			return true
		STEP_SPEED_PERK:
			return false
		STEP_MOVE_COMMAND:
			return true
		STEP_FREE_PLAY, STEP_DONE:
			return true
		_:
			return false

func can_activate_perk(perk_name: String) -> bool:
	if is_finished:
		return true

	match current_step:
		STEP_SPEED_PERK:
			return perk_name == "speed"
		STEP_WAIT_SPEED_ENERGY:
			return false
		STEP_FREE_PLAY, STEP_DONE:
			return true
		_:
			return false

func notify_cell_clicked(cell: BaseCell) -> void:
	if is_finished or cell == null:
		return

	if current_step == STEP_CAPTURE_NEUTRAL and cell.owner_type == BaseCell.OwnerType.NEUTRAL:
		selected_neutral_cell = cell
		_clear_neutral_highlights()
		_go_to_step(STEP_WAIT_CAPTURE)
		return

	if current_step == STEP_FREE_PLAY and not has_shown_perk_guide_revisit:
		if cell.owner_type != BaseCell.OwnerType.PLAYER and cell.owner_type != BaseCell.OwnerType.NEUTRAL:
			has_shown_perk_guide_revisit = true
			perk_guide_revisit_timer = 10.0
			_show_perk_guide_panel()

func notify_move_command(_world_pos: Vector2) -> void:
	if is_finished:
		return

	if current_step == STEP_MOVE_COMMAND:
		_go_to_step(STEP_FREE_PLAY_CONFIRM)

func notify_perk_activated(perk_name: String) -> void:
	if is_finished:
		return

	if current_step == STEP_SPEED_PERK and perk_name == "speed":
		_go_to_step(STEP_MOVE_COMMAND)

func _process(delta: float) -> void:
	if is_finished:
		return

	if pointer_auto_hide_timer > 0.0:
		pointer_auto_hide_timer -= delta
		if pointer_auto_hide_timer <= 0.0 and tutorial_pointer != null:
			tutorial_pointer.call("hide_pointer")

	if perk_guide_revisit_timer > 0.0:
		perk_guide_revisit_timer -= delta
		if perk_guide_revisit_timer <= 0.0:
			_hide_perk_guide_panel()
			_finish_tutorial()

	if current_step == STEP_CAPTURE_NEUTRAL:
		_highlight_refresh_timer -= delta
		if _highlight_refresh_timer <= 0.0:
			_highlight_refresh_timer = HIGHLIGHT_REFRESH_INTERVAL
			_refresh_neutral_highlights()
	elif current_step == STEP_WAIT_CAPTURE:
		if is_instance_valid(selected_neutral_cell) and selected_neutral_cell.owner_type == BaseCell.OwnerType.PLAYER:
			move_target_position = _compute_move_target()
			_go_to_step(STEP_WAIT_SPEED_ENERGY)
	elif current_step == STEP_WAIT_SPEED_ENERGY:
		if _has_enough_energy_for_speed():
			_go_to_step(STEP_SPEED_PERK)

func _go_to_step(step: int) -> void:
	current_step = step
	match step:
		STEP_INTRO:
			_enter_intro_step()
		STEP_CAPTURE_NEUTRAL:
			_enter_capture_step()
		STEP_WAIT_CAPTURE:
			_enter_wait_capture_step()
		STEP_WAIT_SPEED_ENERGY:
			_enter_wait_speed_energy_step()
		STEP_SPEED_PERK:
			_enter_speed_step()
		STEP_MOVE_COMMAND:
			_enter_move_step()
		STEP_FREE_PLAY_CONFIRM:
			_enter_free_play_confirm_step()
		STEP_FREE_PLAY:
			_enter_free_play_step()
		STEP_DONE:
			_finish_tutorial()

func _enter_intro_step() -> void:
	pointer_auto_hide_timer = -1.0
	_show_hint("Это твоя колония", "top")
	_disable_freeze_overlay()
	_clear_neutral_highlights()
	if is_instance_valid(player_start_cell):
		_apply_pointer_calibration("intro_colony")
		_set_pointer_world_target(player_start_cell)
		if tutorial_pointer != null:
			tutorial_pointer.call("play_tap_hint")

func _skip_intro() -> void:
	if current_step != STEP_INTRO:
		return
	_go_to_step(STEP_CAPTURE_NEUTRAL)

func _enter_capture_step() -> void:
	pointer_auto_hide_timer = -1.0
	_show_hint("Захвати любую нейтральную клетку", "top")
	_disable_freeze_overlay()
	if tutorial_pointer != null:
		tutorial_pointer.call("hide_pointer")
	_highlight_refresh_timer = 0.0
	_refresh_neutral_highlights()

func _enter_wait_capture_step() -> void:
	pointer_auto_hide_timer = -1.0
	_show_hint("Подожди, пока колония захватит клетку", "top")
	_disable_freeze_overlay()
	if tutorial_pointer != null:
		tutorial_pointer.call("hide_pointer")

func _enter_wait_speed_energy_step() -> void:
	pointer_auto_hide_timer = 4.0
	_show_hint("Это энергия перков. Она растет, когда ты захватываешь клетки, и тратится на способности. Захватывай клетки, пока не накопишь энергию на ускорение.", "hud_top")
	_disable_freeze_overlay()
	var energy_bar := _get_energy_bar()
	if energy_bar != null:
		energy_bar.set_tutorial_highlight(true)
		_apply_pointer_calibration("energy_bar")
		_set_pointer_ui_target(energy_bar)
		if tutorial_pointer != null:
			tutorial_pointer.call("set_pulse_rings_enabled", false)
			tutorial_pointer.call("play_tap_hint")

func _enter_speed_step() -> void:
	pointer_auto_hide_timer = -1.0
	perk_guide_revisit_timer = -1.0
	_show_hint("Теперь нажми на перк ускорение!", "hud_top")
	_enable_freeze_overlay()
	_clear_energy_bar_highlight()
	_show_perk_guide_panel()
	var speed_button := _get_speed_button()
	if speed_button != null:
		_apply_pointer_calibration("speed_button")
		_set_pointer_ui_target(speed_button)
		if tutorial_pointer != null:
			tutorial_pointer.call("set_pulse_rings_enabled", true)
			tutorial_pointer.call("play_tap_hint")

func _enter_move_step() -> void:
	pointer_auto_hide_timer = -1.0
	perk_guide_revisit_timer = -1.0
	_hide_perk_guide_panel()
	_hide_corner_hint()
	_clear_energy_bar_highlight()
	_disable_freeze_overlay()
	_show_hint("Теперь кликни в любое место, чтобы отправить колонию дальше!", "top")
	_apply_pointer_calibration("move_anywhere")
	_set_pointer_world_position(move_target_position)
	if tutorial_pointer != null:
		tutorial_pointer.call("set_pulse_rings_enabled", true)
		tutorial_pointer.call("play_tap_hint")

func _enter_free_play_confirm_step() -> void:
	pointer_auto_hide_timer = -1.0
	perk_guide_revisit_timer = -1.0
	_hide_perk_guide_panel()
	_clear_energy_bar_highlight()
	_disable_freeze_overlay()
	_show_hint("Отлично! Колония готова к наступлению. Теперь сокруши вражескую колонию и захвати арену!", "top")
	if tutorial_pointer != null:
		tutorial_pointer.call("hide_pointer")

func _enter_free_play_step() -> void:
	pointer_auto_hide_timer = -1.0
	perk_guide_revisit_timer = -1.0
	_set_ai_tutorial_paused(false)
	_hide_perk_guide_panel()
	_hide_panel_hint()
	_clear_energy_bar_highlight()
	_disable_freeze_overlay()
	_show_corner_hint("Захвати вражескую колонию")
	if tutorial_pointer != null:
		tutorial_pointer.call("hide_pointer")
	_clear_neutral_highlights()

func _finish_tutorial() -> void:
	is_finished = true
	pointer_auto_hide_timer = -1.0
	perk_guide_revisit_timer = -1.0
	_set_ai_tutorial_paused(false)
	_hide_perk_guide_panel()
	_clear_energy_bar_highlight()
	_disable_freeze_overlay()
	_clear_neutral_highlights()
	if tutorial_pointer != null:
		tutorial_pointer.call("clear_target")
	if tutorial_hint_panel != null:
		tutorial_hint_panel.call("hide_panel")
	_hide_corner_hint()

func _create_ui() -> void:
	pointer_layer = CanvasLayer.new()
	pointer_layer.name = "TutorialLayer"
	pointer_layer.layer = TUTORIAL_LAYER
	add_child(pointer_layer)

	tutorial_pointer = Control.new()
	tutorial_pointer.set_script(POINTER_SCRIPT)
	tutorial_pointer.name = "TutorialPointer"
	pointer_layer.add_child(tutorial_pointer)

	tutorial_hint_panel = Control.new()
	tutorial_hint_panel.set_script(HINT_PANEL_SCRIPT)
	tutorial_hint_panel.name = "TutorialHintPanel"
	pointer_layer.add_child(tutorial_hint_panel)

	corner_hint_label = Label.new()
	corner_hint_label.name = "TutorialCornerHint"
	corner_hint_label.visible = false
	corner_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner_hint_label.position = Vector2(24.0, 22.0)
	var corner_settings := LabelSettings.new()
	corner_settings.font_size = 24
	corner_settings.font_color = Color(1.0, 0.96, 0.72, 1.0)
	corner_settings.outline_size = 5
	corner_settings.outline_color = Color(0.04, 0.08, 0.12, 0.9)
	corner_settings.shadow_size = 3
	corner_settings.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	corner_hint_label.label_settings = corner_settings
	pointer_layer.add_child(corner_hint_label)

	perk_guide_panel = Control.new()
	perk_guide_panel.name = "TutorialPerkGuide"
	perk_guide_panel.visible = false
	perk_guide_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer_layer.add_child(perk_guide_panel)

	freeze_overlay_layer = CanvasLayer.new()
	freeze_overlay_layer.name = "TutorialFreezeLayer"
	freeze_overlay_layer.layer = FREEZE_OVERLAY_LAYER
	add_child(freeze_overlay_layer)

	freeze_overlay = Control.new()
	freeze_overlay.name = "FreezeOverlay"
	freeze_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	freeze_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	freeze_overlay.visible = false
	freeze_overlay_layer.add_child(freeze_overlay)

func _show_hint(text: String, mode: String = "top") -> void:
	if tutorial_hint_panel == null:
		return
	match mode:
		"hud_top":
			tutorial_hint_panel.call("set_hud_top_mode")
		"bottom":
			tutorial_hint_panel.call("set_bottom_mode")
		_:
			tutorial_hint_panel.call("set_top_mode")
	tutorial_hint_panel.call("set_text_and_show", text)

func _hide_panel_hint() -> void:
	if tutorial_hint_panel != null:
		tutorial_hint_panel.call("hide_panel")

func _show_corner_hint(text: String) -> void:
	if corner_hint_label == null:
		return
	corner_hint_label.text = text
	corner_hint_label.visible = true
	corner_hint_label.modulate.a = 1.0

func _hide_corner_hint() -> void:
	if corner_hint_label != null:
		corner_hint_label.visible = false

func _set_pointer_world_target(target: Node2D) -> void:
	if tutorial_pointer == null or not is_instance_valid(target) or not is_instance_valid(level_camera):
		return
	tutorial_pointer.call("set_world_target", target, level_camera)

func _set_pointer_world_position(pos: Vector2) -> void:
	if tutorial_pointer == null or not is_instance_valid(level_camera):
		return
	tutorial_pointer.call("set_world_position", pos, level_camera)

func _set_pointer_ui_target(control: Control) -> void:
	if tutorial_pointer == null or control == null:
		return
	tutorial_pointer.call("set_ui_target", control)

func _show_perk_guide_panel() -> void:
	if perk_guide_panel == null or perk_button_panel == null:
		return
	if perk_guide_panel.get_child_count() == 0:
		_build_perk_guide_panel()
	_update_perk_guide_positions()
	perk_guide_panel.visible = true

func _hide_perk_guide_panel() -> void:
	if perk_guide_panel != null:
		perk_guide_panel.visible = false

func _build_perk_guide_panel() -> void:
	if perk_guide_panel == null:
		return
	var entries := [
		{"perk": "shield", "text": "Щит", "color": Color(0.64, 0.9, 1.0, 0.96)},
		{"perk": "rapid_fire", "text": "Скорострельность", "color": Color(1.0, 0.72, 0.4, 0.96)},
		{"perk": "speed", "text": "Скорость", "color": Color(1.0, 0.93, 0.52, 1.0)},
		{"perk": "virus", "text": "Вирус", "color": Color(1.0, 0.56, 0.56, 0.96)},
	]
	for entry in entries:
		var label := Label.new()
		label.name = String(entry["perk"])
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.size = Vector2(220.0, 34.0)
		var settings := LabelSettings.new()
		settings.font_size = 24
		settings.font_color = entry["color"]
		settings.outline_size = 5
		settings.outline_color = Color(0.03, 0.07, 0.1, 0.88)
		settings.shadow_size = 3
		settings.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		label.label_settings = settings
		label.text = String(entry["text"])
		perk_guide_panel.add_child(label)

func _update_perk_guide_positions() -> void:
	if perk_guide_panel == null or perk_button_panel == null:
		return
	var perk_names := ["shield", "rapid_fire", "speed", "virus"]
	for perk_name in perk_names:
		var button := perk_button_panel.get_button_by_perk_name(perk_name)
		var label := perk_guide_panel.get_node_or_null(String(perk_name)) as Label
		if button == null or label == null:
			continue
		var button_rect := button.get_global_rect()
		label.position = Vector2(button_rect.end.x + 18.0, button_rect.position.y + button_rect.size.y * 0.5 - label.size.y * 0.5)

func _apply_pointer_calibration(step_name: String) -> void:
	if tutorial_pointer == null:
		return
	var config_variant: Variant = pointer_calibrations.get(step_name, null)
	if config_variant == null:
		tutorial_pointer.call("reset_calibration")
		return
	var config := config_variant as Dictionary
	var hand_offset: Vector2 = config.get("hand", Vector2.ZERO)
	var pulse_offset: Vector2 = config.get("pulse", Vector2.ZERO)
	tutorial_pointer.call("set_calibration", hand_offset, pulse_offset)

func get_pointer_calibration(step_name: String) -> Dictionary:
	var config_variant: Variant = pointer_calibrations.get(step_name, null)
	if config_variant == null:
		return {}
	return (config_variant as Dictionary).duplicate(true)

func set_pointer_calibration(step_name: String, hand_offset: Vector2, pulse_offset: Vector2) -> void:
	var config := {
		"hand": hand_offset,
		"pulse": pulse_offset,
	}
	pointer_calibrations[step_name] = config
	refresh_current_pointer_calibration()

func set_pointer_calibration_axis(step_name: String, target: String, axis: String, value: float) -> void:
	var config := get_pointer_calibration(step_name)
	if config.is_empty():
		config = {"hand": Vector2.ZERO, "pulse": Vector2.ZERO}
	var offset: Vector2 = config.get(target, Vector2.ZERO)
	if axis == "x":
		offset.x = value
	else:
		offset.y = value
	config[target] = offset
	pointer_calibrations[step_name] = config
	refresh_current_pointer_calibration()

func get_pointer_calibration_axis(step_name: String, target: String, axis: String) -> float:
	var config := get_pointer_calibration(step_name)
	if config.is_empty():
		return 0.0
	var offset: Vector2 = config.get(target, Vector2.ZERO)
	return offset.x if axis == "x" else offset.y

func refresh_current_pointer_calibration() -> void:
	match current_step:
		STEP_INTRO:
			_apply_pointer_calibration("intro_colony")
		STEP_WAIT_SPEED_ENERGY:
			_apply_pointer_calibration("energy_bar")
		STEP_SPEED_PERK:
			_apply_pointer_calibration("speed_button")
		STEP_MOVE_COMMAND:
			_apply_pointer_calibration("move_anywhere")

func get_tutorial_step_keys() -> Array[String]:
	return ["intro_colony", "energy_bar", "speed_button", "move_anywhere"]

func _set_ai_tutorial_paused(paused: bool) -> void:
	for node in get_tree().get_nodes_in_group("ai_faction_managers"):
		var ai := node as AIFactionManager
		if ai != null:
			ai.set_tutorial_paused(paused)

func _pick_target_neutral() -> BaseCell:
	var neutral_cells: Array[BaseCell] = []
	for node in get_tree().get_nodes_in_group("cells"):
		var cell := node as BaseCell
		if cell == null:
			continue
		if cell.owner_type != BaseCell.OwnerType.NEUTRAL:
			continue
		if _is_cell_valid_for_tutorial_target(cell):
			neutral_cells.append(cell)

	if neutral_cells.is_empty():
		for node in get_tree().get_nodes_in_group("cells"):
			var fallback_cell := node as BaseCell
			if fallback_cell != null and fallback_cell.owner_type == BaseCell.OwnerType.NEUTRAL:
				neutral_cells.append(fallback_cell)

	if neutral_cells.is_empty() or not is_instance_valid(player_start_cell):
		return null

	var best_cell: BaseCell = neutral_cells[0]
	var best_score := _get_tutorial_target_score(best_cell)
	for cell in neutral_cells:
		var score := _get_tutorial_target_score(cell)
		if score < best_score:
			best_score = score
			best_cell = cell
	return best_cell

func _get_tutorial_target_score(cell: BaseCell) -> float:
	var score := player_start_cell.global_position.distance_squared_to(cell.global_position)
	if is_instance_valid(level_camera):
		var screen_pos: Vector2 = get_viewport().get_canvas_transform() * cell.global_position
		if screen_pos.y < 220.0:
			score += 10000000.0
	return score

func _is_cell_valid_for_tutorial_target(cell: BaseCell) -> bool:
	if not is_instance_valid(player_start_cell):
		return false

	var player_distance := player_start_cell.global_position.distance_to(cell.global_position)
	if player_distance < 260.0 or player_distance > 2200.0:
		return false

	var min_enemy_distance := INF
	for node in get_tree().get_nodes_in_group("cells"):
		var other := node as BaseCell
		if other == null:
			continue
		if other.owner_type == BaseCell.OwnerType.PLAYER or other.owner_type == BaseCell.OwnerType.NEUTRAL:
			continue
		min_enemy_distance = minf(min_enemy_distance, other.global_position.distance_to(cell.global_position))

	return min_enemy_distance >= MAX_SAFE_ENEMY_DISTANCE

func _compute_move_target() -> Vector2:
	if is_instance_valid(selected_neutral_cell):
		return selected_neutral_cell.global_position + Vector2(720.0, 120.0)
	if is_instance_valid(recommended_neutral_cell):
		return recommended_neutral_cell.global_position + Vector2(720.0, 120.0)
	if is_instance_valid(player_start_cell):
		return player_start_cell.global_position + Vector2(900.0, 180.0)
	return Vector2(900.0, 180.0)

func _has_enough_energy_for_speed() -> bool:
	if selection_manager == null:
		return false
	var current_energy := float(selection_manager.get("perk_energy"))
	var required_energy := float(selection_manager.get("SPEED_ENERGY_COST"))
	return current_energy >= required_energy

func _get_energy_bar() -> Control:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null
	return current_scene.find_child("PerkEnergyBar", true, false) as Control

func _get_speed_button() -> PerkButton:
	if perk_button_panel == null:
		return null
	return perk_button_panel.get_button_by_perk_name("speed")

func _clear_energy_bar_highlight() -> void:
	var energy_bar := _get_energy_bar()
	if energy_bar != null and energy_bar.has_method("set_tutorial_highlight"):
		energy_bar.set_tutorial_highlight(false)

func _refresh_neutral_highlights() -> void:
	if level_camera == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var camera_rect := Rect2(level_camera.global_position - viewport_size * level_camera.zoom * 0.5, viewport_size * level_camera.zoom)
	var next_highlighted: Dictionary = {}
	for node in get_tree().get_nodes_in_group("cells"):
		var cell := node as BaseCell
		if cell == null or cell.owner_type != BaseCell.OwnerType.NEUTRAL:
			continue
		var in_camera := camera_rect.has_point(cell.global_position)
		var in_radius := cell.global_position.distance_to(level_camera.global_position) <= NEUTRAL_HIGHLIGHT_RADIUS
		var should_highlight := in_camera or in_radius
		cell.set_tutorial_highlight(should_highlight)
		if should_highlight:
			next_highlighted[cell.get_instance_id()] = true
	_highlighted_neutral_ids = next_highlighted

func _clear_neutral_highlights() -> void:
	for node in get_tree().get_nodes_in_group("cells"):
		var cell := node as BaseCell
		if cell != null and cell.owner_type == BaseCell.OwnerType.NEUTRAL:
			cell.set_tutorial_highlight(false)
	_highlighted_neutral_ids.clear()

func _enable_freeze_overlay() -> void:
	if freeze_overlay != null:
		freeze_overlay.visible = true
		_update_freeze_overlay_rect(current_step == STEP_SPEED_PERK)

func _disable_freeze_overlay() -> void:
	if freeze_overlay != null:
		freeze_overlay.visible = false

func _update_freeze_overlay_rect(allow_speed_panel_click: bool) -> void:
	if freeze_overlay == null:
		return
	freeze_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if allow_speed_panel_click:
		freeze_overlay.offset_left = PERK_PANEL_WIDTH_BLOCK
	else:
		freeze_overlay.offset_left = 0.0
	freeze_overlay.offset_top = 0.0
	freeze_overlay.offset_right = 0.0
	freeze_overlay.offset_bottom = 0.0

func _is_confirm_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		return touch_event.pressed
	return false
