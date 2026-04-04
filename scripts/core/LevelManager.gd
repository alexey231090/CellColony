extends Node

var current_level: int = 1
var unlocked_levels: int = 1

const DEFAULT_LEVEL_DATA := {
	"scene_path": "res://scenes/levels/organic_level.tscn",
	"num_enemies": 1,
	"has_islands": true,
	"is_organic": true,
	"map_scale": 1.1,
	"num_neutrals": 36,
	"seed": 42,
}

const LEVELS: Array[Dictionary] = [
	{
		"id": 1,
		"scene_path": "res://scenes/levels/organic_level.tscn",
		"num_enemies": 1,
		"has_islands": true,
		"is_organic": true,
		"map_scale": 1.1,
		"num_neutrals": 36,
		"seed": 101,
		"shape_type": "rounded_box",
		"shape_size": Vector2(7200, 5000),
		"shape_power": 4.6,
		"play_area_radius_mult": 1.0,
		"noise_freq": 0.0014,
		"noise_amp": 0.08,
		"island_count": 2,
		"island_radius": 260.0,
		"island_noise_freq": 0.0032,
		"island_noise_amp": 0.22,
		"island_specs": [
			{
				"center_ratio": Vector2(-0.34, -0.18),
				"radius_x": 320.0,
				"radius_y": 160.0,
				"rotation": -0.42,
				"noise_amp": 0.24,
			},
			{
				"center_ratio": Vector2(0.3, 0.22),
				"radius_x": 280.0,
				"radius_y": 140.0,
				"rotation": 0.73,
				"noise_amp": 0.2,
			},
		],
	},
]

func get_total_levels() -> int:
	return LEVELS.size()

func get_level_data(level_num: int) -> Dictionary:
	if level_num < 1 or level_num > LEVELS.size():
		return DEFAULT_LEVEL_DATA.duplicate(true)
	return LEVELS[level_num - 1].duplicate(true)

func get_current_level_data() -> Dictionary:
	return get_level_data(current_level)

func get_current_level_scene_path() -> String:
	return String(get_current_level_data().get("scene_path", DEFAULT_LEVEL_DATA.scene_path))

func set_current_level(level_num: int) -> void:
	current_level = clampi(level_num, 1, max(1, LEVELS.size()))
