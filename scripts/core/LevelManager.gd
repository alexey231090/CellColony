extends Node

const DIFFICULTY_EASY := "easy"
const DIFFICULTY_MEDIUM := "medium"
const DIFFICULTY_HARD := "hard"
const CHAPTER_SIZE := 5

var current_level: int = 1
var unlocked_levels: int = 1
var selected_difficulty: String = DIFFICULTY_EASY

const DEFAULT_LEVEL_DATA := {
	"scene_path": "res://scenes/levels/organic_level.tscn",
	"num_enemies": 1,
	"has_islands": true,
	"is_organic": true,
	"map_scale": 1.1,
	"num_neutrals": 46,
	"seed": 42,
	"chapter": 1,
	"title": "Уровень",
}

const BASE_LEVELS: Array[Dictionary] = [
	{
		"id": 1,
		"chapter": 1,
		"title": "Первые Деления",
		"scene_path": "res://scenes/levels/organic_level.tscn",
		"num_enemies": 1,
		"has_islands": true,
		"is_organic": true,
		"map_scale": 1.1,
		"num_neutrals": 46,
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

var levels: Array[Dictionary] = []

func _ready() -> void:
	levels = BASE_LEVELS.duplicate(true)
	_ensure_level_count(30)

func _ensure_level_count(target_count: int) -> void:
	if levels.size() >= target_count:
		return

	var template: Dictionary = levels[0].duplicate(true)
	for i in range(levels.size() + 1, target_count + 1):
		var level_data: Dictionary = template.duplicate(true)
		level_data["id"] = i
		level_data["chapter"] = int(ceili(float(i) / float(CHAPTER_SIZE)))
		level_data["title"] = "Уровень %d" % i
		level_data["seed"] = 100 + i * 17
		level_data["num_neutrals"] = maxi(24, 48 - int((i - 1) / 2))
		level_data["map_scale"] = 1.08 + minf(0.5, float(i - 1) * 0.015)
		level_data["island_count"] = mini(5, 2 + int((i - 1) / 5))
		levels.append(level_data)

func get_total_levels() -> int:
	return levels.size()

func get_total_chapters() -> int:
	return int(ceili(float(get_total_levels()) / float(CHAPTER_SIZE)))

func get_level_data(level_num: int) -> Dictionary:
	if level_num < 1 or level_num > levels.size():
		return DEFAULT_LEVEL_DATA.duplicate(true)
	return levels[level_num - 1].duplicate(true)

func get_current_level_data() -> Dictionary:
	var data := get_level_data(current_level)
	data["selected_difficulty"] = selected_difficulty
	return data

func get_current_level_scene_path() -> String:
	return String(get_current_level_data().get("scene_path", DEFAULT_LEVEL_DATA.scene_path))

func set_current_level(level_num: int) -> void:
	current_level = clampi(level_num, 1, max(1, levels.size()))

func set_selected_difficulty(difficulty: String) -> void:
	match difficulty:
		DIFFICULTY_EASY, DIFFICULTY_MEDIUM, DIFFICULTY_HARD:
			selected_difficulty = difficulty
		_:
			selected_difficulty = DIFFICULTY_EASY

func get_selected_difficulty() -> String:
	return selected_difficulty

func get_chapter_range(chapter_index: int) -> Vector2i:
	var start_level := (chapter_index - 1) * CHAPTER_SIZE + 1
	var end_level := mini(chapter_index * CHAPTER_SIZE, get_total_levels())
	return Vector2i(start_level, end_level)
