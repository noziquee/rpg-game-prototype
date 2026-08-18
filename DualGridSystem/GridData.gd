class_name GridData
extends RefCounted

var width: int
var height: int
var cells: Dictionary = {}  # Vector2i -> bool (true = land)

func _init(w: int, h: int) -> void:
	width = w
	height = h

func is_land(x: int, y: int) -> bool:
	if x < 0 or x >= width or y < 0 or y >= height:
		return false
	return cells.get(Vector2i(x, y), false)

func set_land(x: int, y: int, value: bool) -> void:
	cells[Vector2i(x, y)] = value

func get_bitmask(dual_x: int, dual_y: int) -> int:
	var mask := 0
	if is_land(dual_x - 1, dual_y - 1): mask |= TileLibrary.TL
	if is_land(dual_x, dual_y - 1): mask |= TileLibrary.TR
	if is_land(dual_x, dual_y): mask |= TileLibrary.BR
	if is_land(dual_x - 1, dual_y): mask |= TileLibrary.BL
	return mask
