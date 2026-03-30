# DEVELOPMENT_BLUEPRINT.md: Редизайн уровней и интерфейса

Этот документ содержит эталонные куски «сложного» кода, которые мы внедрили. Мы используем их для пошагового восстановления функционала после отката проекта.

---

## 1. Ядро: Система уровней (LevelManager)
**Файл:** `res://scripts/core/LevelManager.gd` (Autoload: `LevelManager`)

```gdscript
extends Node
var current_level: int = 1

func get_current_level_data() -> Dictionary:
	var data = {"num_enemies": 1, "has_islands": false, "is_dumbbell": false, "map_scale": 1.0, "num_neutrals": 20}
	match current_level:
		1: data.num_enemies = 1; data.map_scale = 0.6; data.num_neutrals = 25
		2: data.num_enemies = 2; data.is_dumbbell = true; data.map_scale = 0.85; data.num_neutrals = 35
		3: data.num_enemies = 2; data.has_islands = true; data.map_scale = 1.1; data.num_neutrals = 50
	return data
```

---

## 2. Ядро: Синхронизация Групп (BaseCell)
**Файл:** `res://scenes/base_cell/cell.gd`
*Критично для того, чтобы камера не теряла игрока при смене владельца.*

```gdscript
@export var owner_type: OwnerType = OwnerType.NEUTRAL:
	set(val):
		owner_type = val
		if is_inside_tree():
			_update_groups()
			_update_visuals()

# В _ready() обязательно вызывать _update_groups()
```

---

## 3. Интерфейс: Уровни в Меню (main_menu.gd)
**Файл:** `res://scenes/ui/main_menu/main_menu.gd`

```gdscript
# Внутри _populate_levels создание элементов ячейки:
var num_lbl = Label.new()
num_lbl.text = str(level_num)
num_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
num_lbl.position = Vector2(12, 8)

var icon_lbl = Label.new()
icon_lbl.text = "▶"
icon_lbl.modulate.a = 0.3
# Анимация наведения:
btn.mouse_entered.connect(func(): icon_lbl.modulate.a = 0.9)
btn.mouse_exited.connect(func(): icon_lbl.modulate.a = 0.3)
```

---

## 4. Мир: Органическая генерация (main.gd)
**Файл:** `res://scenes/main.gd`

### Групповые алгоритмы (Blob и Шум)
```gdscript
func _generate_blob(center: Vector2, radius: float, noise: FastNoiseLite, segments: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var noise_amplitude = radius * 0.35
	for i in range(segments):
		var angle = (TAU / segments) * i
		var dir = Vector2(cos(angle), sin(angle))
		var base_p = center + dir * radius
		var n = noise.get_noise_2d(base_p.x, base_p.y)
		pts.append(base_p + dir * (n * noise_amplitude))
	# Гарантируем CCW для внешней зоны
	if not Geometry2D.is_polygon_clockwise(pts): pts.reverse()
	return pts
```

### Инвертированные стены (Plate with Hole)
```gdscript
# bounding_box должен быть CW, playable_polygon - CCW
var clipped_walls = Geometry2D.clip_polygons(bounding_box, playable_polygon)
for poly in clipped_walls:
	var coll = CollisionPolygon2D.new()
	coll.polygon = poly
	# z_index = -10 для стен, чтобы не перекрывали клетки
```

---

## 5. Камера: Свободный режим (CameraFollow)
**Файл:** `res://scripts/core/CameraFollow.gd`

```gdscript
# Снятие ограничений при spectator_active:
func _disable_limits() -> void:
	limit_left = -1000000; limit_right = 1000000
	limit_top = -1000000; limit_bottom = 1000000

# Восстановление оригинальных лимитов (после сохранения через update_original_limits())
func _apply_stored_limits() -> void:
	limit_left = _original_limits.left # ...и так далее
```

---

## 6. Снаряды: Столкновение со стенами (projectile.gd)
**Файл:** `res://scenes/projectile/projectile.gd`

```gdscript
func _on_body_entered(body: Node2D) -> void:
	if body is StaticBody2D: # Попадание в стену или остров
		_impact_wall()
		return
	# ...логика попадания в клетку
```
