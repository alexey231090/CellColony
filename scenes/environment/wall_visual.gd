extends Node2D
class_name WallVisual

var polygons: Array[PackedVector2Array] = []
var wall_color: Color = Color.BLACK

func _draw() -> void:
	for poly in polygons:
		draw_colored_polygon(poly, wall_color)
