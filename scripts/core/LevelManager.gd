extends Node

var current_level: int = 1
var unlocked_levels: int = 2 # Разблокировано 2 уровня по умолчанию для теста

func get_current_level_data() -> Dictionary:
	var data = {
		"num_enemies": 1,
		"has_islands": false,
		"is_organic": false,
		"map_scale": 1.0, 
		"num_neutrals": 20,
		"seed": 42 # Фиксированный сид по умолчанию
	}
	
	match current_level:
		1:
			data.num_enemies = 1
			data.has_islands = false
			data.is_organic = false # Квадрат
			data.map_scale = 0.6
			data.num_neutrals = 25
			data.seed = 101
		2:
			data.num_enemies = 2
			data.has_islands = true
			data.is_organic = true # Органическая "Клякса"
			data.map_scale = 0.9
			data.num_neutrals = 35
			data.seed = 202
		3:
			data.num_enemies = 2
			data.has_islands = true
			data.is_organic = true
			data.map_scale = 1.1
			data.num_neutrals = 50
			data.seed = 303
	
	return data
