extends Node
## SelectionManager
## Клик по клетке = Атака/лечение. Клик в пустоту = Передвижение всей колонии.
## В режиме наблюдателя (нет клеток игрока) — ввод игнорируется.

var CLICK_FEEDBACK_SCENE = preload("res://scenes/ui/click_feedback.tscn")
var TARGET_HIGHLIGHT_SCENE = preload("res://scenes/ui/target_highlight.tscn")
var SHIELD_PERK_EFFECT_SCENE = preload("res://scenes/ui/shield_perk_effect.tscn")

@export var perk_energy: float = 0.0 # Пул энергии игрока для перков
var active_perk: String = ""

# Кулдауны и стоимость Щита
var shield_cooldown: float = 0.0
@export var SHIELD_COOLDOWN_MAX: float = 12.0
@export var SHIELD_ENERGY_COST: float = 20.0

# Кулдауны и стоимость Ускорения
var speed_cooldown: float = 0.0
@export var SPEED_COOLDOWN_MAX: float = 18.0
@export var SPEED_ENERGY_COST: float = 15.0
@export var SPEED_BOOST_DURATION: float = 8.0
@export var SPEED_BOOST_MULTIPLIER: float = 2.0

func _ready() -> void:
	add_to_group("selection_manager")

func add_perk_energy(amount: float) -> void:
	perk_energy += amount
	_refresh_pui()

func _process(delta: float) -> void:
	if shield_cooldown > 0:
		shield_cooldown = max(0.0, shield_cooldown - delta)
		
	if speed_cooldown > 0:
		speed_cooldown = max(0.0, speed_cooldown - delta)
		
	_refresh_pui()

func _refresh_pui() -> void:
	var pui = get_tree().get_first_node_in_group("perks_ui")
	if pui and pui.has_method("update_perk_status"):
		pui.update_perk_status(
			perk_energy, 
			shield_cooldown / SHIELD_COOLDOWN_MAX,
			speed_cooldown / SPEED_COOLDOWN_MAX
		)

func _unhandled_input(event: InputEvent) -> void:
	# В режиме наблюдателя нет смысла в командах
	if get_tree().get_nodes_in_group("player_cells").is_empty():
		return

	# Горячая клавиша "1" для активации щита
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_1:
			activate_perk("shield")
			get_viewport().set_input_as_handled()
			return
		# Горячая клавиша "2" для активации ускорения
		if key_event.keycode == KEY_2:
			activate_perk("speed")
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var camera = get_viewport().get_camera_2d()
			if not camera: return
			var world_pos = camera.get_global_mouse_position()
			_handle_selection(world_pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Отмена перка
			_clear_active_perk()

func activate_perk(perk_name: String) -> void:
	# Если мы уже выбрали этот же перк - отменяем (тоггл)
	if active_perk == perk_name:
		_clear_active_perk()
		return

	# Проверка на наличие ресурсов и КД
	if perk_name == "shield":
		if perk_energy < SHIELD_ENERGY_COST or shield_cooldown > 0:
			print("Нет энергии или КД")
			return
		# Щит требует выбора цели, поэтому ставим active_perk
		active_perk = perk_name
		var pui = get_tree().get_first_node_in_group("perks_ui")
		if pui and pui.has_method("set_button_highlight"):
			pui.set_button_highlight(perk_name, true)
		print("Активирован перк: ", perk_name)
		
	elif perk_name == "speed":
		if perk_energy < SPEED_ENERGY_COST or speed_cooldown > 0:
			print("Нет энергии или КД для ускорения")
			return
		
		# Ускорение применяется мгновенно ко всем клеткам
		perk_energy -= SPEED_ENERGY_COST
		speed_cooldown = SPEED_COOLDOWN_MAX
		
		var player_cells = get_tree().get_nodes_in_group("player_cells")
		for cell in player_cells:
			if cell is BaseCell:
				cell.apply_speed_boost(SPEED_BOOST_DURATION, SPEED_BOOST_MULTIPLIER)
		
		print("Спринт! Длительность: %.1f, Множитель: %.1f, Стоимость: %d, КД: %.1f" % [
			SPEED_BOOST_DURATION,
			SPEED_BOOST_MULTIPLIER,
			SPEED_ENERGY_COST,
			SPEED_COOLDOWN_MAX
		])
		_refresh_pui()

func _clear_active_perk() -> void:
	if active_perk != "":
		# Убираем подсветку в UI
		var pui = get_tree().get_first_node_in_group("perks_ui")
		if pui and pui.has_method("set_button_highlight"):
			pui.set_button_highlight(active_perk, false)
			
		active_perk = ""
		Input.set_custom_mouse_cursor(null)

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

	# === ОБРАБОТКА АКТИВНОГО ПЕРКА ===
	if active_perk != "":
		if active_perk == "shield":
			if clicked_node and clicked_node.owner_type == BaseCell.OwnerType.PLAYER:
				# Спавним эффект на выбранной клетке
				if SHIELD_PERK_EFFECT_SCENE:
					var effect = SHIELD_PERK_EFFECT_SCENE.instantiate()
					get_parent().add_child(effect)
					effect.global_position = clicked_node.global_position
					
					# Снимаем ресурсы и ставим КД
					perk_energy -= SHIELD_ENERGY_COST
					shield_cooldown = SHIELD_COOLDOWN_MAX
					_refresh_pui()

				_clear_active_perk()
			else:
				# Если клик не на свою клетку - просто отменяем перк
				_clear_active_perk()
		return
	# ==================================
	
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
