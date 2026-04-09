extends Node
## SelectionManager
## Клик по клетке = Атака/лечение. Клик в пустоту = Передвижение всей колонии.
## В режиме наблюдателя (нет клеток игрока) — ввод игнорируется.

var CLICK_FEEDBACK_SCENE = preload("res://scenes/ui/click_feedback.tscn")
var TARGET_HIGHLIGHT_SCENE = preload("res://scenes/ui/target_highlight.tscn")
var SHIELD_PERK_EFFECT_SCENE = preload("res://scenes/ui/shield_perk_effect.tscn")

@export var perk_energy: float = 0.0 # Пул энергии игрока для перков
@export var MAX_PERK_ENERGY: float = 100.0 # Максимальная энергия
var active_perk: String = ""

# Кулдауны и стоимость Щита
var shield_cooldown: float = 0.0
@export var SHIELD_COOLDOWN_MAX: float = 12.0
@export var SHIELD_ENERGY_COST: float = 50.0

# Кулдауны и стоимость Ускорения
var speed_cooldown: float = 0.0
@export var SPEED_COOLDOWN_MAX: float = 18.0
@export var SPEED_ENERGY_COST: float = 30.0
@export var SPEED_BOOST_DURATION: float = 8.0
@export var SPEED_BOOST_MULTIPLIER: float = 2.0
@export var SHIELD_SELECT_RADIUS: float = 350.0

@export var RAPID_FIRE_ENERGY_COST: float = 50.0
@export var RAPID_FIRE_COOLDOWN_MAX: float = 15.0
@export var RAPID_FIRE_DURATION: float = 4.0
@export var RAPID_FIRE_MULTIPLIER: float = 3.0

@export var VIRUS_ENERGY_COST: float = 100.0
@export var VIRUS_COOLDOWN_MAX: float = 20.0
@export var VIRUS_DURATION: float = 6.0
@export var VIRUS_SPREAD_RADIUS: float = 200.0

var rapid_fire_cooldown: float = 0.0
var virus_cooldown: float = 0.0

var virus_outbreak_counter: int = 0 # Уникальный ID для каждой активации вируса
var cursor_visual: Node2D = null

# Состояние перетаскивания (Drag to Aim)
var is_dragging_perk: bool = false
var drag_cell: BaseCell = null
var drag_target_pos: Vector2 = Vector2.ZERO
var drag_preview: Node2D = null
var aim_line: Line2D = null
var attack_target_line: Line2D = null
var attack_target_node: BaseCell = null

func _ready() -> void:
	add_to_group("selection_manager")
	_init_aim_line()
	_init_attack_target_line()
	
	# Твёрдая фиксация баланса (игнорирует случайные изменения в Инспекторе)
	SHIELD_ENERGY_COST = 50.0
	SPEED_ENERGY_COST = 30.0
	RAPID_FIRE_ENERGY_COST = 50.0
	VIRUS_ENERGY_COST = 100.0
	MAX_PERK_ENERGY = 100.0

func _init_aim_line() -> void:
	aim_line = Line2D.new()
	aim_line.width = 3.0
	aim_line.default_color = Color(0.2, 0.8, 1.0, 0.3)
	aim_line.hide()
	add_child(aim_line)

func _init_attack_target_line() -> void:
	attack_target_line = Line2D.new()
	attack_target_line.width = 1.4
	attack_target_line.default_color = Color(0.95, 0.72, 0.76, 0.12)
	attack_target_line.joint_mode = Line2D.LINE_JOINT_ROUND
	attack_target_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	attack_target_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	attack_target_line.z_index = 6
	attack_target_line.hide()
	add_child(attack_target_line)

func add_perk_energy(amount: float) -> void:
	perk_energy += amount
	# Ограничиваем максимумом
	perk_energy = min(perk_energy, MAX_PERK_ENERGY)

func _process(delta: float) -> void:
	if shield_cooldown > 0:
		shield_cooldown = max(0.0, shield_cooldown - delta)
		
	if speed_cooldown > 0:
		speed_cooldown = max(0.0, speed_cooldown - delta)
		
	if rapid_fire_cooldown > 0:
		rapid_fire_cooldown = max(0.0, rapid_fire_cooldown - delta)
		
	if virus_cooldown > 0:
		virus_cooldown = max(0.0, virus_cooldown - delta)
		
	_update_cursor_visual()
	_update_drag_preview()
	_update_attack_target_line()

func _update_attack_target_line() -> void:
	if attack_target_line == null:
		return

	if not is_instance_valid(attack_target_node) or not attack_target_node.is_inside_tree() or attack_target_node.owner_type == BaseCell.OwnerType.PLAYER:
		attack_target_node = null
		attack_target_line.hide()
		return

	var player_cells_raw = get_tree().get_nodes_in_group("player_cells")
	var player_cells: Array[BaseCell] = []
	for node in player_cells_raw:
		var cell := node as BaseCell
		if cell:
			player_cells.append(cell)

	if player_cells.is_empty():
		attack_target_line.hide()
		return

	var colony_center := BaseCell.get_colony_center(get_tree(), BaseCell.OwnerType.PLAYER)
	attack_target_line.clear_points()
	attack_target_line.add_point(colony_center)
	attack_target_line.add_point(attack_target_node.global_position)

	if attack_target_node.owner_type == BaseCell.OwnerType.NEUTRAL:
		attack_target_line.default_color = Color(0.8, 0.9, 0.96, 0.1)
	else:
		attack_target_line.default_color = Color(0.95, 0.72, 0.76, 0.12)

	attack_target_line.show()

func _clear_attack_target_line() -> void:
	attack_target_node = null
	if attack_target_line:
		attack_target_line.hide()

func _update_drag_preview() -> void:
	if is_dragging_perk and drag_cell and is_instance_valid(drag_cell):
		if not drag_preview:
			var script = load("res://scripts/core/PerkCursorVisual.gd")
			drag_preview = Node2D.new()
			drag_preview.set_script(script)
			add_child(drag_preview)
			drag_preview.set_radius(SHIELD_SELECT_RADIUS)
		
		var camera = get_viewport().get_camera_2d()
		if camera:
			var mouse_pos = camera.get_global_mouse_position()
			var cell_pos = drag_cell.global_position
			var dir = (mouse_pos - cell_pos).normalized()
			# Рисуем линию или стрелку прицеливания
			if aim_line:
				aim_line.clear_points()
				aim_line.add_point(cell_pos)
				
				# Если это спринт - меняем цвет на "скоростной" зеленый/неоновый
				if drag_cell.assigned_perk == "speed":
					aim_line.default_color = Color(0.0, 1.0, 0.5, 0.7)
					drag_preview.set_radius(40.0) # Для рывка круг превью меньше
					# Для рывка тянем линию прямо до мышки, без ограничения радиусом щита
					drag_target_pos = mouse_pos
					aim_line.add_point(mouse_pos)
				else:
					aim_line.default_color = Color(0.2, 0.8, 1.0, 0.3)
					drag_preview.set_radius(SHIELD_SELECT_RADIUS)
					drag_target_pos = cell_pos + dir * SHIELD_SELECT_RADIUS
					aim_line.add_point(drag_target_pos)
					
				drag_preview.global_position = drag_target_pos
				aim_line.show()
	else:
		if drag_preview:
			drag_preview.hide()
		if aim_line:
			aim_line.hide()

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
		# Горячая клавиша "2" для активации скорострельности
		if key_event.keycode == KEY_2:
			activate_perk("rapid_fire")
			get_viewport().set_input_as_handled()
			return
		# Горячая клавиша "3" для активации ускорения
		if key_event.keycode == KEY_3:
			activate_perk("speed")
			get_viewport().set_input_as_handled()
			return
		# Горячая клавиша "4" для активации вируса
		if key_event.keycode == KEY_4:
			activate_perk("virus")
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		var camera = get_viewport().get_camera_2d()
		if not camera: return
		var world_pos = camera.get_global_mouse_position()
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Обычное действие (Движение / Атака)
				_handle_selection(world_pos)
				
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# ПКМ теперь обрабатывается RadialPerkMenu
			# Отменяем активный перк только если меню не открыто
			if active_perk != "":
				_clear_active_perk()


func _is_perk_ready(perk_name: String) -> bool:
	match perk_name:
		"shield": return perk_energy >= SHIELD_ENERGY_COST and shield_cooldown <= 0
		"speed": return perk_energy >= SPEED_ENERGY_COST and speed_cooldown <= 0
		"rapid_fire": return perk_energy >= RAPID_FIRE_ENERGY_COST and rapid_fire_cooldown <= 0
		"virus": return perk_energy >= VIRUS_ENERGY_COST and virus_cooldown <= 0
	return false

func get_perk_cooldown_ratio(perk_name: String) -> float:
	match perk_name:
		"shield": return shield_cooldown / SHIELD_COOLDOWN_MAX if SHIELD_COOLDOWN_MAX > 0 else 0.0
		"speed": return speed_cooldown / SPEED_COOLDOWN_MAX if SPEED_COOLDOWN_MAX > 0 else 0.0
		"rapid_fire": return rapid_fire_cooldown / RAPID_FIRE_COOLDOWN_MAX if RAPID_FIRE_COOLDOWN_MAX > 0 else 0.0
		"virus": return virus_cooldown / VIRUS_COOLDOWN_MAX if VIRUS_COOLDOWN_MAX > 0 else 0.0
	return 0.0

func get_perk_energy_cost(perk_name: String) -> float:
	match perk_name:
		"shield": return SHIELD_ENERGY_COST
		"speed": return SPEED_ENERGY_COST
		"rapid_fire": return RAPID_FIRE_ENERGY_COST
		"virus": return VIRUS_ENERGY_COST
	return 0.0

func _handle_double_click(pos: Vector2) -> bool:
	var clicked_node: BaseCell = _get_cell_at_pos(pos)
	if clicked_node and clicked_node.owner_type == BaseCell.OwnerType.PLAYER:
		if clicked_node.assigned_perk != "":
			return try_activate_cell_perk(clicked_node)
	return false

func _get_cell_at_pos(pos: Vector2) -> BaseCell:
	var all_cells = get_tree().get_nodes_in_group("cells")
	for cell in all_cells:
		if cell is BaseCell:
			var distance = cell.global_position.distance_to(pos)
			if distance < cell.radius * cell.scale.x:
				return cell
	return null

func try_activate_cell_perk(cell: BaseCell, custom_pos: Vector2 = Vector2.ZERO) -> bool:
	if not is_instance_valid(cell) or cell.is_infected:
		return false
		
	var perk_name = cell.assigned_perk
	var act_pos = cell.global_position
	if custom_pos != Vector2.ZERO:
		act_pos = custom_pos
	
	if perk_name == "shield":
		if perk_energy < SHIELD_ENERGY_COST or shield_cooldown > 0:
			print("Нет энергии или КД для щита на клетке")
			return false
		
		# Спавним эффект в целевой позиции
		if SHIELD_PERK_EFFECT_SCENE:
			var effect = SHIELD_PERK_EFFECT_SCENE.instantiate()
			get_parent().add_child(effect)
			effect.global_position = act_pos
			
			# Раздаем щит соседним клеткам игрока от ЦЕНТРА ЭФФЕКТА
			var player_cells = get_tree().get_nodes_in_group("player_cells")
			for p_cell in player_cells:
				if p_cell is BaseCell and p_cell.is_infected: continue
				var dist = p_cell.global_position.distance_to(act_pos)
				if dist <= SHIELD_SELECT_RADIUS + (p_cell.radius * p_cell.scale.x):
					p_cell.reflect_chance = 0.5
					p_cell.reflect_timer = 10.0
					p_cell.queue_redraw()
			
			perk_energy -= SHIELD_ENERGY_COST
			shield_cooldown = SHIELD_COOLDOWN_MAX
			
			if active_perk == "shield":
				_clear_active_perk()
			return true
			
	elif perk_name == "speed":
		if perk_energy < SPEED_ENERGY_COST or speed_cooldown > 0:
			print("Нет энергии или КД для спринта на клетке")
			return false
			
		var player_cells = get_tree().get_nodes_in_group("player_cells")
		
		if custom_pos != Vector2.ZERO:
			# РЕЖИМ РЫВКА (Super Dash)
			var mouse_pos = custom_pos
			var cell_pos = cell.global_position
			var dash_dir = (mouse_pos - cell_pos).normalized()
			
			# Применяем очень быстрый, но короткий буст
			for p_cell in player_cells:
				if p_cell is BaseCell and not p_cell.is_infected:
					p_cell.apply_speed_boost(1.0, 6.0) # 1.0 сек, скорость х6
					# Форсируем движение в сторону рывка (задаем цель далеко впереди)
					p_cell.command_move(p_cell.global_position + dash_dir * 2000.0)
					# Даем резкий "пинок" (импульс)
					p_cell.velocity += dash_dir * 1200.0
						
			print("СВЕРХЗВУКОВОЙ РЫВОК в направлении: ", dash_dir)
		else:
			# ОБЫЧНЫЙ СПРИНТ
			for p_cell in player_cells:
				if p_cell is BaseCell:
					p_cell.apply_speed_boost(7.0, 2.0) # 7 сек, скорость х2
			print("Обычный спринт (7 сек)")
			
		perk_energy -= SPEED_ENERGY_COST
		speed_cooldown = SPEED_COOLDOWN_MAX
		return true
			
	elif perk_name == "rapid_fire":
		if perk_energy < RAPID_FIRE_ENERGY_COST or rapid_fire_cooldown > 0:
			print("Нет энергии или КД для скорострельности на клетке")
			return false
			
		var player_cells = get_tree().get_nodes_in_group("player_cells")
		for p_cell in player_cells:
			if p_cell is BaseCell and not p_cell.is_infected:
				p_cell.apply_rapid_fire(RAPID_FIRE_DURATION, RAPID_FIRE_MULTIPLIER)
		
		perk_energy -= RAPID_FIRE_ENERGY_COST
		rapid_fire_cooldown = RAPID_FIRE_COOLDOWN_MAX
		return true

	elif perk_name == "virus":
		if perk_energy < VIRUS_ENERGY_COST or virus_cooldown > 0:
			print("Нет энергии или КД для вируса на клетке")
			return false
			
		var target_cell: BaseCell = null
		
		# ПРИЦЕЛЬНЫЙ ОГОНЬ (Drag)
		if custom_pos != Vector2.ZERO:
			target_cell = _get_cell_at_pos(custom_pos)
			# Проверка: цель должна быть ВРАГОМ (не игрок, не нейтрал)
			if target_cell and (target_cell.owner_type == BaseCell.OwnerType.PLAYER or target_cell.owner_type == BaseCell.OwnerType.NEUTRAL):
				target_cell = null
				
		# АВТО-АТАКА (Click / если мимо цели при Drag)
		if not target_cell:
			var enemies = get_tree().get_nodes_in_group("cells")
			var min_dist = 1200.0 # Увеличен радиус поиска для авто-атаки вируса
			for c in enemies:
				if c is BaseCell and c.owner_type != BaseCell.OwnerType.PLAYER and c.owner_type != BaseCell.OwnerType.NEUTRAL:
					var dist = cell.global_position.distance_to(c.global_position)
					if dist < min_dist:
						min_dist = dist
						target_cell = c
		
		if target_cell:
			var shooter = cell.get_node_or_null("ShooterModule")
			if shooter:
				virus_outbreak_counter += 1
				shooter.shoot_virus(target_cell, VIRUS_DURATION, virus_outbreak_counter)
				perk_energy -= VIRUS_ENERGY_COST
				virus_cooldown = VIRUS_COOLDOWN_MAX
				print("ВИРУС запущен из ", cell.name, " в ", target_cell.name)
				return true
		else:
			print("Вирус: Нет вражеской цели в радиусе!")
			show_floating_message("НЕТ ЦЕЛИ", Color(1.0, 0.4, 0.4))
			return false
			
	return false

func activate_perk(perk_name: String) -> void:
	# Проверка на наличие ресурсов и КД
	if perk_name == "shield":
		if perk_energy < SHIELD_ENERGY_COST or shield_cooldown > 0:
			print("Нет энергии или КД")
			return
		_clear_attack_target_line()
		
		# Щит активируется на центральной клетке и передаётся соседям
		_activate_shield_chain()
		
	elif perk_name == "virus":
		if perk_energy < VIRUS_ENERGY_COST or virus_cooldown > 0:
			print("Нет энергии или КД для вируса")
			return
		_clear_attack_target_line()
		
		# Автоприцеливание на ближайшего врага
		_activate_virus_auto()
		
	elif perk_name == "speed":
		if perk_energy < SPEED_ENERGY_COST or speed_cooldown > 0:
			print("Нет энергии или КД для ускорения")
			return
		_clear_attack_target_line()
		
		# Ускорение применяется мгновенно ко всем клеткам
		perk_energy -= SPEED_ENERGY_COST
		speed_cooldown = SPEED_COOLDOWN_MAX
		
		var player_cells = get_tree().get_nodes_in_group("player_cells")
		for cell in player_cells:
			if cell is BaseCell and not cell.is_infected:
				cell.apply_speed_boost(SPEED_BOOST_DURATION, SPEED_BOOST_MULTIPLIER)
		
		print("Спринт! Длительность: %.1f, Множитель: %.1f, Стоимость: %d, КД: %.1f" % [
			SPEED_BOOST_DURATION,
			SPEED_BOOST_MULTIPLIER,
			SPEED_ENERGY_COST,
			SPEED_COOLDOWN_MAX
		])
	elif perk_name == "rapid_fire":
		if perk_energy < RAPID_FIRE_ENERGY_COST or rapid_fire_cooldown > 0:
			print("Нет энергии или КД для скорострельности")
			return
		_clear_attack_target_line()
		
		# Скорострельность применяется мгновенно ко всем клеткам
		perk_energy -= RAPID_FIRE_ENERGY_COST
		rapid_fire_cooldown = RAPID_FIRE_COOLDOWN_MAX
		
		var player_cells = get_tree().get_nodes_in_group("player_cells")
		for cell in player_cells:
			if cell is BaseCell and not cell.is_infected:
				cell.apply_rapid_fire(RAPID_FIRE_DURATION, RAPID_FIRE_MULTIPLIER)
		
		print("Яростный огонь! Длительность: %.1f, Множитель: %.1f, Стоимость: %d, КД: %.1f" % [
			RAPID_FIRE_DURATION,
			RAPID_FIRE_MULTIPLIER,
			RAPID_FIRE_ENERGY_COST,
			RAPID_FIRE_COOLDOWN_MAX
		])

func _activate_shield_chain() -> void:
	## Активирует щит на центральной клетке и передаёт соседям
	var player_cells = get_tree().get_nodes_in_group("player_cells")
	if player_cells.is_empty():
		return
	
	# Находим центральную клетку (ближайшую к центру колонии)
	var colony_center = BaseCell.get_colony_center(get_tree(), BaseCell.OwnerType.PLAYER)
	
	var center_cell: BaseCell = null
	var min_dist = INF
	for cell in player_cells:
		if cell is BaseCell and not cell.is_infected:
			var dist = cell.global_position.distance_to(colony_center)
			if dist < min_dist:
				min_dist = dist
				center_cell = cell
	
	if not center_cell:
		return
	
	# Спавним эффект на центральной клетке
	if SHIELD_PERK_EFFECT_SCENE:
		var effect = SHIELD_PERK_EFFECT_SCENE.instantiate()
		get_parent().add_child(effect)
		effect.global_position = center_cell.global_position
	
	# Активируем щит на центральной клетке
	center_cell.reflect_chance = 0.5
	center_cell.reflect_timer = 10.0
	center_cell.queue_redraw()
	
	# Передаём щит соседним клеткам в радиусе
	for cell in player_cells:
		if cell is BaseCell and cell != center_cell and not cell.is_infected:
			var dist = cell.global_position.distance_to(center_cell.global_position)
			if dist <= SHIELD_SELECT_RADIUS:
				cell.reflect_chance = 0.5
				cell.reflect_timer = 10.0
				cell.queue_redraw()
	
	perk_energy -= SHIELD_ENERGY_COST
	shield_cooldown = SHIELD_COOLDOWN_MAX

func _activate_virus_auto() -> void:
	## Автоматический выстрел вируса в ближайшего врага с визуализацией траектории
	var player_cells = get_tree().get_nodes_in_group("player_cells")
	if player_cells.is_empty():
		return
	
	# Находим центр колонии
	var colony_center = BaseCell.get_colony_center(get_tree(), BaseCell.OwnerType.PLAYER)
	
	# Поиск ближайшего врага
	var all_cells = get_tree().get_nodes_in_group("cells")
	var closest_enemy: BaseCell = null
	var closest_dist = 1200.0
	
	for cell in all_cells:
		if cell is BaseCell and cell.owner_type != BaseCell.OwnerType.PLAYER and cell.owner_type != BaseCell.OwnerType.NEUTRAL:
			var dist = cell.global_position.distance_to(colony_center)
			if dist < closest_dist:
				closest_dist = dist
				closest_enemy = cell
	
	if not closest_enemy:
		print("Нет цели!")
		show_floating_message("НЕТ ЦЕЛИ", Color(1.0, 0.4, 0.4))
		return
	
	# Находим ближайшую клетку для выстрела
	var shooter_cell: BaseCell = null
	var min_dist = INF
	for cell in player_cells:
		if cell is BaseCell and not cell.is_infected:
			var dist = cell.global_position.distance_to(closest_enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				shooter_cell = cell
	
	if not shooter_cell:
		return
	
	# Создаём линию траектории (в глобальных координатах)
	var trajectory_line = Line2D.new()
	trajectory_line.set_script(load("res://scripts/core/VirusTrajectoryLine.gd"))
	trajectory_line.width = 4.0
	trajectory_line.default_color = Color(0.9, 0.1, 0.9, 1.0)
	trajectory_line.z_index = 50
	trajectory_line.z_as_relative = false  # Глобальный z_index
	get_tree().root.add_child(trajectory_line)  # Добавляем в root для глобальных координат
	trajectory_line.add_point(shooter_cell.global_position)
	trajectory_line.add_point(closest_enemy.global_position)
	
	print("Вирус: линия создана от ", shooter_cell.global_position, " до ", closest_enemy.global_position)
	
	# Выстреливаем вирус
	virus_outbreak_counter += 1
	var outbreak_id = virus_outbreak_counter
	
	var projectile_scene = preload("res://scenes/projectile/projectile.tscn")
	if projectile_scene:
		var projectile = projectile_scene.instantiate()
		get_parent().add_child(projectile)
		projectile.global_position = shooter_cell.global_position
		
		projectile.is_virus = true
		projectile.virus_outbreak_id = outbreak_id
		projectile.virus_duration = VIRUS_DURATION
		projectile.owner_type = shooter_cell.owner_type
		projectile.original_owner_type = shooter_cell.owner_type
		projectile.projectile_color = Color(0.9, 0.1, 0.9)
		
		var direction = (closest_enemy.global_position - shooter_cell.global_position).normalized()
		projectile.direction = direction
		projectile.speed = 600.0  # Увеличена скорость вируса
		projectile.target_node = closest_enemy
		
		print("Вирус: снаряд создан, цель: ", closest_enemy.global_position, ", скорость: 600")
	
	perk_energy -= VIRUS_ENERGY_COST
	virus_cooldown = VIRUS_COOLDOWN_MAX

func _clear_active_perk() -> void:
	if active_perk != "":
		active_perk = ""
		Input.set_custom_mouse_cursor(null)

func _activate_shield_at_position(world_pos: Vector2) -> void:
	## Активирует щит в указанной позиции (для джойстика)
	if perk_energy < SHIELD_ENERGY_COST or shield_cooldown > 0:
		return
	
	# Спавним эффект в целевой позиции
	if SHIELD_PERK_EFFECT_SCENE:
		var effect = SHIELD_PERK_EFFECT_SCENE.instantiate()
		get_parent().add_child(effect)
		effect.global_position = world_pos
		
		# Раздаем щит соседним клеткам игрока от ЦЕНТРА ЭФФЕКТА
		var player_cells = get_tree().get_nodes_in_group("player_cells")
		for p_cell in player_cells:
			if p_cell is BaseCell and p_cell.is_infected: continue
			var dist = p_cell.global_position.distance_to(world_pos)
			if dist <= SHIELD_SELECT_RADIUS + (p_cell.radius * p_cell.scale.x):
				p_cell.reflect_chance = 0.5
				p_cell.reflect_timer = 10.0
				p_cell.queue_redraw()
		
		perk_energy -= SHIELD_ENERGY_COST
		shield_cooldown = SHIELD_COOLDOWN_MAX
		active_perk = ""

func _activate_speed_dash(direction: Vector2) -> void:
	## Активирует рывок спринта в указанном направлении
	if perk_energy < SPEED_ENERGY_COST or speed_cooldown > 0:
		return
	
	perk_energy -= SPEED_ENERGY_COST
	speed_cooldown = SPEED_COOLDOWN_MAX
	
	# Рывок: x6 скорость на 1 секунду
	var player_cells = get_tree().get_nodes_in_group("player_cells")
	for cell in player_cells:
		if cell is BaseCell and not cell.is_infected:
			# Применяем рывок с направлением
			cell.apply_speed_boost(1.0, 6.0)  # 1 сек, x6 скорость
			# Добавляем физический импульс в направлении
			if direction.length() > 0.1:
				cell.velocity = direction.normalized() * 800.0
	
	active_perk = ""

func _activate_virus_at_position(world_pos: Vector2) -> void:
	## Активирует вирус в указанной позиции (для джойстика)
	if perk_energy < VIRUS_ENERGY_COST or virus_cooldown > 0:
		return
	
	# Поиск клеток игрока для выстрела
	var player_cells = get_tree().get_nodes_in_group("player_cells")
	if player_cells.is_empty():
		return
	
	# Выбираем ближайшую клетку к позиции для выстрела
	var shooter_cell: BaseCell = null
	var min_dist = INF
	
	for cell in player_cells:
		if cell is BaseCell and not cell.is_infected:
			var dist = cell.global_position.distance_to(world_pos)
			if dist < min_dist:
				min_dist = dist
				shooter_cell = cell
	
	if not shooter_cell:
		return
	
	# Выстреливаем вирус
	virus_outbreak_counter += 1
	var outbreak_id = virus_outbreak_counter
	
	# Создаём снаряд вируса
	var projectile_scene = preload("res://scenes/projectile/projectile.tscn")
	if projectile_scene:
		var projectile = projectile_scene.instantiate()
		get_parent().add_child(projectile)
		projectile.global_position = shooter_cell.global_position
		
		# Устанавливаем параметры вируса напрямую
		projectile.is_virus = true
		projectile.virus_outbreak_id = outbreak_id
		projectile.virus_duration = VIRUS_DURATION
		projectile.owner_type = shooter_cell.owner_type
		projectile.original_owner_type = shooter_cell.owner_type
		projectile.projectile_color = Color(0.9, 0.1, 0.9)  # Фиолетовый для вируса
		
		# Направление к целевой позиции
		var direction = (world_pos - shooter_cell.global_position).normalized()
		projectile.direction = direction
		projectile.speed = 400.0
		projectile.target_node = null
	
	perk_energy -= VIRUS_ENERGY_COST
	virus_cooldown = VIRUS_COOLDOWN_MAX
	active_perk = ""

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
				if cell is BaseCell and not cell.is_infected:
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
				_clear_active_perk()
			else:
				show_floating_message("НЕТ ЦЕЛИ", Color(1.0, 0.4, 0.4))
				_clear_active_perk()
		return
	# ==================================
	
	if clicked_node:
		# ЦЕЛЬ ЕСТЬ — атакуем/лечим
		if circle:
			circle.target_node = clicked_node
			circle.show()

		# ИСПРАВЛЕНИЕ: Если кликнули по СВОЕЙ клетке (например, для перка),
		# не заставляем всю остальную колонию бросать дела и целиться в неё.
		if clicked_node.owner_type != BaseCell.OwnerType.PLAYER:
			attack_target_node = clicked_node
			for p_cell in player_cells:
				if p_cell is BaseCell:
					p_cell.command_attack(clicked_node.global_position, clicked_node)
					
			# Визуальный отклик (атака/лечение) - только для не-своих при одиночном клике
			if CLICK_FEEDBACK_SCENE:
				var feedback = CLICK_FEEDBACK_SCENE.instantiate()
				get_parent().add_child(feedback)
				var is_attack = clicked_node.owner_type != BaseCell.OwnerType.PLAYER
				feedback.setup(player_cells, clicked_node.global_position, is_attack)
				
			# Временное выделение атакуемой или нейтральной цели на 3 секунды
			if TARGET_HIGHLIGHT_SCENE:
				var highlight = TARGET_HIGHLIGHT_SCENE.instantiate()
				get_parent().add_child(highlight)
				var ht_color = Color(0.95, 0.45, 0.42) if clicked_node.owner_type != BaseCell.OwnerType.NEUTRAL else Color(0.78, 0.9, 0.96)
				highlight.setup(clicked_node, ht_color)
		else:
			# Если кликнули по своей, просто покажем круг выбора на ней (опционально)
			_clear_attack_target_line()
	else:
		# ЦЕЛИ НЕТ — ПЛЫВЕМ ВСЕЙ КОЛОНИЕЙ ТУДА
		if circle:
			circle.target_node = null
			circle.hide()
		_clear_attack_target_line()

		for p_cell in player_cells:
			if p_cell is BaseCell:
				p_cell.command_move(pos)
				
		# Визуальный отклик (перемещение)
		if CLICK_FEEDBACK_SCENE:
			var feedback = CLICK_FEEDBACK_SCENE.instantiate()
			get_parent().add_child(feedback)
			feedback.setup(player_cells, pos, false)

func show_floating_message(text_str: String, color: Color = Color.WHITE) -> void:
	var msg = Label.new()
	msg.text = text_str
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var settings = LabelSettings.new()
	settings.font_size = 48
	settings.font_color = color
	settings.outline_size = 8
	settings.outline_color = Color(0, 0, 0, 0.8)
	settings.shadow_size = 4
	settings.shadow_color = Color(0, 0, 0, 0.5)
	msg.label_settings = settings
	
	# Создаем CanvasLayer для правильного порядка отрисовки поверх всего UI
	var cl = CanvasLayer.new()
	cl.layer = 150
	get_tree().root.add_child(cl)
	cl.add_child(msg)
	
	var vp_size = get_viewport().get_visible_rect().size
	msg.size.x = 600
	msg.position = Vector2(vp_size.x / 2.0 - 300.0, vp_size.y * 0.4)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(msg, "position:y", msg.position.y - 120.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(msg, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(cl.queue_free)
