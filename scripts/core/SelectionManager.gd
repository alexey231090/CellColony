extends Node
## SelectionManager
## Клик по клетке = Атака/лечение. Клик в пустоту = Передвижение всей колонии.
## В режиме наблюдателя (нет клеток игрока) — ввод игнорируется.

var CLICK_FEEDBACK_SCENE = preload("res://scenes/ui/click_feedback.tscn")
var TARGET_HIGHLIGHT_SCENE = preload("res://scenes/ui/target_highlight.tscn")

func _unhandled_input(event: InputEvent) -> void:
	# В режиме наблюдателя нет смысла в командах
	if get_tree().get_nodes_in_group("player_cells").is_empty():
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var camera = get_viewport().get_camera_2d()
			if not camera: return
			var world_pos = camera.get_global_mouse_position()
			_handle_selection(world_pos)

func _handle_selection(pos: Vector2) -> void:
	var clicked_node: BaseCell = null
	var all_cells = get_tree().get_nodes_in_group("cells")

	for cell in all_cells:
		if cell is BaseCell:
			var distance = cell.global_position.distance_to(pos)
			if distance < cell.radius * cell.scale.x:
				clicked_node = cell
				break

	var player_cells = get_tree().get_nodes_in_group("player_cells")
	var circle = get_tree().root.get_node_or_null("SelectionCircle")

	if clicked_node:
		# ЦЕЛЬ ЕСТЬ — атакуем/лечим
		if circle:
			circle.target_node = clicked_node
			circle.show()

		for p_cell in player_cells:
			if p_cell is BaseCell:
				p_cell.command_attack(clicked_node.global_position, clicked_node)
				
		# Визуальный отклик (атака/лечение)
		if CLICK_FEEDBACK_SCENE:
			var feedback = CLICK_FEEDBACK_SCENE.instantiate()
			get_parent().add_child(feedback)
			var is_attack = clicked_node.owner_type != BaseCell.OwnerType.PLAYER
			feedback.setup(player_cells, clicked_node.global_position, is_attack)
			
		# Временное выделение атакуемой/нейтральной цели на 3 секунды
		if TARGET_HIGHLIGHT_SCENE and clicked_node.owner_type != BaseCell.OwnerType.PLAYER:
			var highlight = TARGET_HIGHLIGHT_SCENE.instantiate()
			get_parent().add_child(highlight)
			var ht_color = Color(0.9, 0.3, 0.3) if clicked_node.owner_type != BaseCell.OwnerType.NEUTRAL else Color(0.8, 0.8, 0.8)
			highlight.setup(clicked_node, ht_color)
	else:
		# ЦЕЛИ НЕТ — ПЛЫВЕМ ВСЕЙ КОЛОНИЕЙ ТУДА
		if circle:
			circle.target_node = null
			circle.hide()

		for p_cell in player_cells:
			if p_cell is BaseCell:
				p_cell.command_move(pos)
				
		# Визуальный отклик (перемещение)
		if CLICK_FEEDBACK_SCENE:
			var feedback = CLICK_FEEDBACK_SCENE.instantiate()
			get_parent().add_child(feedback)
			feedback.setup(player_cells, pos, false)
