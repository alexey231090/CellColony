extends Node2D
class_name ShooterModule

@export var projectile_scene: PackedScene = preload("res://scenes/projectile/projectile.tscn")

var target_position: Vector2 = Vector2.ZERO
var target_node: Node2D = null
var is_active: bool = false
var fire_timer: float = 0.0

func set_target(pos: Vector2, node: Node2D = null) -> void:
	target_position = pos
	target_node = node
	is_active = (target_node != null)

func _process(delta: float) -> void:
	if not is_active:
		return
	
	var parent_cell = get_parent() as BaseCell
	if not parent_cell: return
	
	if is_instance_valid(target_node):
		target_position = target_node.global_position
	else:
		is_active = false
		return
		
	if target_node == parent_cell:
		is_active = false
		return
		
	if target_node is BaseCell and target_node.owner_type == parent_cell.owner_type:
		if target_node.stats.current_energy >= target_node.stats.max_energy:
			is_active = false
			return
	
	fire_timer -= delta
	if fire_timer <= 0:
		if parent_cell.stats.current_energy > parent_cell.stats.attack_cost:
			shoot()
			fire_timer = 1.0 / parent_cell.stats.fire_rate

func shoot() -> void:
	var parent_cell = get_parent() as BaseCell
	if not parent_cell: return
	
	parent_cell.stats.current_energy -= parent_cell.stats.attack_cost
	
	var proj = projectile_scene.instantiate() as Projectile
	get_tree().root.add_child(proj)
	
	var shoot_dir = (target_position - global_position).normalized()
	var spread = deg_to_rad(randf_range(-5, 5))
	shoot_dir = shoot_dir.rotated(spread)
	
	var spawn_dist = parent_cell.radius * parent_cell.scale.x + 10.0
	
	proj.global_position = global_position + shoot_dir * spawn_dist
	proj.direction = shoot_dir
	proj.speed = parent_cell.stats.projectile_speed
	proj.damage = parent_cell.stats.attack_cost
	proj.owner_type = parent_cell.owner_type
	proj.target_node = target_node
	
	var p_color = Color(0.55, 0.55, 0.55)
	match parent_cell.owner_type:
		BaseCell.OwnerType.PLAYER:       p_color = Color(0.40, 0.60, 1.00)
		BaseCell.OwnerType.ENEMY_RED:    p_color = Color(0.90, 0.30, 0.30)
		BaseCell.OwnerType.ENEMY_GREEN:  p_color = Color(0.25, 0.80, 0.35)
		BaseCell.OwnerType.ENEMY_YELLOW: p_color = Color(0.95, 0.80, 0.15)
	
	proj.projectile_color = p_color
