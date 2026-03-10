extends Node2D
## Генератор мира. 4 фракции: Игрок (синий), Красные, Зелёные, Жёлтые.
## Каждый начинает с базой и несколькими клетками. Нейтральные разбросаны по карте.

@export var cell_scene: PackedScene = preload("res://scenes/base_cell/cell.tscn")
@export var map_size: Vector2 = Vector2(5000, 5000)
@export var num_neutral_cells: int = 50

# Базовые позиции фракций по углам карты
const FACTION_BASES: Array = [
	{"type": 1, "pos": Vector2(-1800, -1800)},  # PLAYER (синий) — левый верх
	{"type": 2, "pos": Vector2( 1800,  1800)},  # ENEMY_RED  — правый низ
	{"type": 3, "pos": Vector2( 1800, -1800)},  # ENEMY_GREEN — правый верх
	{"type": 4, "pos": Vector2(-1800,  1800)},  # ENEMY_YELLOW — левый низ
]

func _ready() -> void:
	# 1. Спавним игрока из сцены
	var player_cell = get_node_or_null("PlayerCell")
	var player_base = FACTION_BASES[0]
	if player_cell:
		player_cell.position = player_base.pos
		player_cell.owner_type = BaseCell.OwnerType.PLAYER
		player_cell.stats.current_energy = 20

	# 2. Спавним 3 AI-фракции с базой и стартовыми клетками
	for i in range(1, 4):
		var faction_data = FACTION_BASES[i]
		var faction_type = _int_to_owner_type(faction_data.type)
		var base_pos: Vector2 = faction_data.pos

		# Главная база
		_spawn_cell(base_pos, faction_type, 25)
		# 2 стартовые клетки рядом с базой
		_spawn_cell(base_pos + Vector2(randf_range(-200, 200), randf_range(-200, 200)), faction_type, 15)
		_spawn_cell(base_pos + Vector2(randf_range(-200, 200), randf_range(-200, 200)), faction_type, 12)

	# 3. Нейтральные клетки — разбросаны по всей карте
	var base_positions: Array = []
	for bd in FACTION_BASES:
		base_positions.append(bd.pos)

	var spawned := 0
	var attempts := 0
	while spawned < num_neutral_cells and attempts < num_neutral_cells * 5:
		attempts += 1
		var pos = Vector2(
			randf_range(-map_size.x / 2.0, map_size.x / 2.0),
			randf_range(-map_size.y / 2.0, map_size.y / 2.0)
		)
		# Не спавним прямо на базах
		var too_close := false
		for bpos in base_positions:
			if pos.distance_to(bpos) < 500:
				too_close = true
				break
		if too_close:
			continue
		_spawn_cell(pos, BaseCell.OwnerType.NEUTRAL, randf_range(3.0, 22.0))
		spawned += 1

	print("Мир: %d нейтральных, 4 фракции." % spawned)

func _spawn_cell(pos: Vector2, owner_type: BaseCell.OwnerType, energy: float) -> BaseCell:
	var cell = cell_scene.instantiate() as BaseCell
	cell.position = pos
	cell.owner_type = owner_type
	cell.stats.current_energy = energy
	add_child(cell)
	return cell

func _int_to_owner_type(i: int) -> BaseCell.OwnerType:
	match i:
		1: return BaseCell.OwnerType.PLAYER
		2: return BaseCell.OwnerType.ENEMY_RED
		3: return BaseCell.OwnerType.ENEMY_GREEN
		4: return BaseCell.OwnerType.ENEMY_YELLOW
	return BaseCell.OwnerType.NEUTRAL
