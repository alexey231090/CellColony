extends Node

const POINTER_SCRIPT = preload("res://scripts/ui/tutorial_pointer.gd")
const HINT_PANEL_SCRIPT = preload("res://scripts/ui/tutorial_hint_panel.gd")

const STEP_INTRO: int = 0
const STEP_CAPTURE_NEUTRAL: int = 1
const STEP_WAIT_CAPTURE: int = 2
const STEP_SPEED_PERK: int = 3
const STEP_MOVE_COMMAND: int = 4
const STEP_FREE_PLAY: int = 5
const STEP_DONE: int = 6

const INTRO_DURATION: float = 1.35
const MOVE_TARGET_RADIUS: float = 220.0
const MAX_SAFE_ENEMY_DISTANCE: float = 1100.0

var selection_manager: Node = null
var level_camera: Camera2D = null
var perk_button_panel: PerkButtonPanel = null
var player_start_cell: BaseCell = null
var level_data: Dictionary = {}

var pointer_layer: CanvasLayer = null
var tutorial_pointer: Control = null
var tutorial_hint_panel: Control = null

var current_step: int = STEP_INTRO
var target_neutral_cell: BaseCell = null
var move_target_position: Vector2 = Vector2.ZERO
var move_target_radius: float = MOVE_TARGET_RADIUS
var intro_timer: float = 0.0
var is_finished: bool = false

func setup(selection: Node, camera: Camera2D, perk_panel: PerkButtonPanel, player_cell: BaseCell, data: Dictionary) -> void:
	selection_manager = selection
	level_camera = camera
	perk_button_panel = perk_panel
	player_start_cell = player_cell
	level_data = data.duplicate(true)
	target_neutral_cell = _pick_target_neutral()
	move_target_position = _compute_move_target()
	_create_ui()
	_go_to_step(STEP_INTRO)

func can_select_cell(cell: BaseCell) -> bool:
	if is_finished or cell == null:
		return true if is_finished else false

	match current_step:
		STEP_CAPTURE_NEUTRAL:
			return cell == target_neutral_cell
		STEP_WAIT_CAPTURE:
			return false
		STEP_SPEED_PERK:
			return false
		STEP_MOVE_COMMAND:
			return false
		_:
			return true

func can_move_to(world_pos: Vector2) -> bool:
	if is_finished:
		return true

	match current_step:
		STEP_MOVE_COMMAND:
			return world_pos.distance_to(move_target_position) <= move_target_radius
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
		STEP_FREE_PLAY, STEP_DONE:
			return true
		_:
			return false

func notify_cell_clicked(cell: BaseCell) -> void:
	if is_finished or cell == null:
		return

	if current_step == STEP_CAPTURE_NEUTRAL and cell == target_neutral_cell:
		_go_to_step(STEP_WAIT_CAPTURE)

func notify_move_command(world_pos: Vector2) -> void:
	if is_finished:
		return

	if current_step == STEP_MOVE_COMMAND and world_pos.distance_to(move_target_position) <= move_target_radius:
		_go_to_step(STEP_FREE_PLAY)

func notify_perk_activated(perk_name: String) -> void:
	if is_finished:
		return

	if current_step == STEP_SPEED_PERK and perk_name == "speed":
		_go_to_step(STEP_MOVE_COMMAND)

func _process(delta: float) -> void:
	if is_finished:
		return

	if current_step == STEP_INTRO:
		intro_timer -= delta
		if intro_timer <= 0.0:
			_go_to_step(STEP_CAPTURE_NEUTRAL)
	elif current_step == STEP_WAIT_CAPTURE:
		if is_instance_valid(target_neutral_cell) and target_neutral_cell.owner_type == BaseCell.OwnerType.PLAYER:
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
		STEP_SPEED_PERK:
			_enter_speed_step()
		STEP_MOVE_COMMAND:
			_enter_move_step()
		STEP_FREE_PLAY:
			_enter_free_play_step()
		STEP_DONE:
			_finish_tutorial()

func _enter_intro_step() -> void:
	intro_timer = INTRO_DURATION
	_show_hint("Это твоя колония")
	if is_instance_valid(player_start_cell):
		_set_pointer_world_target(player_start_cell)

func _enter_capture_step() -> void:
	_show_hint("Нажми на ближайшую нейтральную клетку, чтобы захватить ее")
	if is_instance_valid(target_neutral_cell):
		_set_pointer_world_target(target_neutral_cell)

func _enter_wait_capture_step() -> void:
	_show_hint("Подожди, пока колония захватит клетку")
	if is_instance_valid(target_neutral_cell):
		_set_pointer_world_target(target_neutral_cell)

func _enter_speed_step() -> void:
	_show_hint("Теперь включи ускорение")
	var speed_button := _get_speed_button()
	if speed_button != null:
		_set_pointer_ui_target(speed_button)
		tutorial_pointer.call("play_tap_hint")

func _enter_move_step() -> void:
	_show_hint("Теперь укажи точку перемещения")
	_set_pointer_world_position(move_target_position)
	if tutorial_pointer != null:
		tutorial_pointer.call("play_tap_hint")

func _enter_free_play_step() -> void:
	is_finished = true
	_show_hint("Отлично. Теперь добей врага самостоятельно")
	if tutorial_pointer != null:
		tutorial_pointer.call("hide_pointer")

func _finish_tutorial() -> void:
	is_finished = true
	if tutorial_pointer != null:
		tutorial_pointer.call("clear_target")
	if tutorial_hint_panel != null:
		tutorial_hint_panel.call("hide_panel")

func _create_ui() -> void:
	pointer_layer = CanvasLayer.new()
	pointer_layer.name = "TutorialLayer"
	pointer_layer.layer = 118
	add_child(pointer_layer)

	tutorial_pointer = Control.new()
	tutorial_pointer.set_script(POINTER_SCRIPT)
	tutorial_pointer.name = "TutorialPointer"
	pointer_layer.add_child(tutorial_pointer)

	tutorial_hint_panel = Control.new()
	tutorial_hint_panel.set_script(HINT_PANEL_SCRIPT)
	tutorial_hint_panel.name = "TutorialHintPanel"
	pointer_layer.add_child(tutorial_hint_panel)

func _show_hint(text: String) -> void:
	if tutorial_hint_panel != null:
		tutorial_hint_panel.call("set_top_mode")
		tutorial_hint_panel.call("set_text_and_show", text)

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
	var best_distance := player_start_cell.global_position.distance_squared_to(best_cell.global_position)
	for cell in neutral_cells:
		var dist := player_start_cell.global_position.distance_squared_to(cell.global_position)
		if dist < best_distance:
			best_distance = dist
			best_cell = cell
	return best_cell

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
	if is_instance_valid(target_neutral_cell):
		return target_neutral_cell.global_position + Vector2(720.0, 120.0)
	if is_instance_valid(player_start_cell):
		return player_start_cell.global_position + Vector2(900.0, 180.0)
	return Vector2(900.0, 180.0)

func _get_speed_button() -> PerkButton:
	if perk_button_panel == null:
		return null
	return perk_button_panel.get_button_by_perk_name("speed")
