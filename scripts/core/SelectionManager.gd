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
@export var SHIELD_SELECT_RADIUS: float = 100.0

@export var RAPID_FIRE_ENERGY_COST: float = 25.0
@export var RAPID_FIRE_COOLDOWN_MAX: float = 15.0
@export var RAPID_FIRE_DURATION: float = 4.0
@export var RAPID_FIRE_MULTIPLIER: float = 3.0

@export var VIRUS_ENERGY_COST: float = 30.0
@export var VIRUS_COOLDOWN_MAX: float = 20.0
@export var VIRUS_DURATION: float = 6.0
@export var VIRUS_SPREAD_RADIUS: float = 200.0

var rapid_fire_cooldown: float = 0.0
var virus_cooldown: float = 0.0
var virus_outbreak_counter: int = 0 # Уникальный ID для каждой активации вируса
var cursor_visual: Node2D = null

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
		
	if rapid_fire_cooldown > 0:
		rapid_fire_cooldown = max(0.0, rapid_fire_cooldown - delta)
		
	if virus_cooldown > 0:
		virus_cooldown = max(0.0, virus_cooldown - delta)
		
	_refresh_pui()
	_update_cursor_visual()

func _update_cursor_visual() -> void:
	if active_perk == "shield":
		if not cursor_visual:
			var script = load("res://scripts/core/PerkCursorVisual.gd")
			cursor_visual = Node2D.new()
			cursor_visual.set_script(script)
			add_child(cursor_visual)
			cursor_visual.set_radius(SHIELD_SELECT_RADIUS)
		
		var camera = get_viewport().get_camera_2d()
		if camera:
			cursor_visual.global_position = camera.get_global_mouse_position()
			cursor_visual.show()
	else:
		if cursor_visual:
			cursor_visual.hide()

func _refresh_pui() -> void:
	var pui = get_tree().get_first_node_in_group("perks_ui")
	if pui and pui.has_method("update_perk_status"):
		var speed_ratio = 0.0
		if SPEED_COOLDOWN_MAX > 0:
			speed_ratio = speed_cooldown / SPEED_COOLDOWN_MAX
			
		var shield_ratio = 0.0
		if SHIELD_COOLDOWN_MAX > 0:
			shield_ratio = shield_cooldown / SHIELD_COOLDOWN_MAX

		var rapid_ratio = 0.0
		if RAPID_FIRE_COOLDOWN_MAX > 0:
			rapid_ratio = rapid_fire_cooldown / RAPID_FIRE_COOLDOWN_MAX
			
		var virus_ratio = 0.0
		if VIRUS_COOLDOWN_MAX > 0:
			virus_ratio = virus_cooldown / VIRUS_COOLDOWN_MAX
			
		pui.update_perk_status(perk_energy, shield_ratio, speed_ratio, rapid_ratio, virus_ratio)

func _unhandled_input(event: InputEvent) -> void:
	# В режиме наблюдателя нет смысла в командах
	if get_tree().get_nodes_in_group("player_cells").is_empty():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		# Горячая клавиша "1" для активации щита
		if key_event.keycode == KEY_1:
			activate_perk("shield")
			get_viewport().set_input_as_handled()
			return
		# Горячая клавиша "2" для активации ускорения
		if key_event.keycode == KEY_2:
			activate_perk("speed")
			get_viewport().set_input_as_handled()
			return
		# Горячая клавиша "3" для активации скорострельности
		if key_event.keycode == KEY_3:
			activate_perk("rapid_fire")
			get_viewport().set_input_as_handled()
			return
		# Горячая клавиша "4" для активации вируса
		if key_event.keycode == KEY_4:
			activate_perk("virus")
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
		
	elif perk_name == "virus":
		if perk_energy < VIRUS_ENERGY_COST or virus_cooldown > 0:
			print("Нет энергии или КД для вируса")
			return
		# Вирус требует выбора цели (врага)
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
		
	elif perk_name == "rapid_fire":
		if perk_energy < RAPID_FIRE_ENERGY_COST or rapid_fire_cooldown > 0:
			print("Нет энергии или КД для скорострельности")
			return
		
		# Скорострельность применяется мгновенно ко всем клеткам
		perk_energy -= RAPID_FIRE_ENERGY_COST
		rapid_fire_cooldown = RAPID_FIRE_COOLDOWN_MAX
		
		var player_cells = get_tree().get_nodes_in_group("player_cells")
		for cell in player_cells:
			if cell is BaseCell:
				cell.apply_rapid_fire(RAPID_FIRE_DURATION, RAPID_FIRE_MULTIPLIER)
		
		print("Яростный огонь! Длительность: %.1f, Множитель: %.1f, Стоимость: %d, КД: %.1f" % [
			RAPID_FIRE_DURATION,
			RAPID_FIRE_MULTIPLIER,
			RAPID_FIRE_ENERGY_COST,
			RAPID_FIRE_COOLDOWN_MAX
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
			# "Умный" поиск цели в радиусе
			var target_cell: BaseCell = null
			var min_dist = SHIELD_SELECT_RADIUS
			
			
			for cell in player_cells:
				if cell is BaseCell:
					var dist = cell.global_position.distance_to(pos)
					# Учитываем и радиус захвата, и радиус самой клетки
					if dist < SHIELD_SELECT_RADIUS + (cell.radius * cell.scale.x):
						if dist < min_dist:
							min_dist = dist
							target_cell = cell
			
			if target_cell:
				# Спавним эффект на выбранной клетке
				if SHIELD_PERK_EFFECT_SCENE:
					var effect = SHIELD_PERK_EFFECT_SCENE.instantiate()
					get_parent().add_child(effect)
					effect.global_position = target_cell.global_position
					
					# Снимаем ресурсы и ставим КД
					perk_energy -= SHIELD_ENERGY_COST
					shield_cooldown = SHIELD_COOLDOWN_MAX
					_refresh_pui()

				_clear_active_perk()
			else:
				# Если клик не попал ни по одной своей клетке в радиусе - отменяем
				_clear_active_perk()
		
		elif active_perk == "virus":
			# "Умный" поиск вражеской цели в радиусе
			var target_cell: BaseCell = null
			var enemies = get_tree().get_nodes_in_group("cells") # Ищем среди всех, кроме своих
			var min_dist = SHIELD_SELECT_RADIUS # Используем тот же радиус захвата для удобства
			
			for cell in enemies:
				if cell is BaseCell and cell.owner_type != BaseCell.OwnerType.PLAYER:
					var dist = cell.global_position.distance_to(pos)
					if dist < SHIELD_SELECT_RADIUS + (cell.radius * cell.scale.x):
						if dist < min_dist:
							min_dist = dist
							target_cell = cell
			
			if target_cell:
				# Ищем ближайшую НАШУ клетку, которая выстрелит вирусом
				
				var nearest_player: BaseCell = null
				var n_dist = 999999.0
				for p in player_cells:
					var d = p.global_position.distance_to(target_cell.global_position)
					if d < n_dist:
						n_dist = d
						nearest_player = p
				
				if nearest_player:
					var shooter = nearest_player.get_node_or_null("ShooterModule")
					if shooter:
						# Специальный выстрел вирусом с уникальным ID волны
						virus_outbreak_counter += 1
						shooter.shoot_virus(target_cell, VIRUS_DURATION, virus_outbreak_counter)
						perk_energy -= VIRUS_ENERGY_COST
						virus_cooldown = VIRUS_COOLDOWN_MAX
						_refresh_pui()
				_clear_active_perk()
			else:
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
