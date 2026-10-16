class_name HexSectorMap
extends RefCounted

# Labels the points of ONE unified StalbergGrid with which "sector"
# (formerly a separate patch) they belong to. No mesh generation here —
# just bookkeeping so biome assignment and WFC can still operate on
# hex-shaped regions.

var sector_coords: Array = []          # Array[Vector2i]
var sector_centers: Dictionary = {}    # Vector2i -> Vector3 world position
var point_sector: Dictionary = {}      # int point_id -> Vector2i sector_coord
var sector_points: Dictionary = {}     # Vector2i sector_coord -> Array[int] point_ids

const NEIGHBOR_OFFSETS := [
	Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, -1), Vector2i(-1, 1),
]

func build(grid: StalbergGrid, world_radius: int, hex_radius: int, cell_size: float) -> void:
	sector_coords = _generate_sector_coords(world_radius)

	sector_centers.clear()
	sector_points.clear()
	for coord in sector_coords:
		sector_centers[coord] = _sector_world_offset(coord, hex_radius, cell_size)
		sector_points[coord] = []

	point_sector.clear()
	for pid in grid.points.keys():
		var pos: Vector3 = grid.points[pid]
		var best_coord: Vector2i = sector_coords[0]
		var best_dist := INF
		for coord in sector_coords:
			var d: float = pos.distance_squared_to(sector_centers[coord])
			if d < best_dist:
				best_dist = d
				best_coord = coord
		point_sector[pid] = best_coord
		sector_points[best_coord].append(pid)

func get_adjacency() -> Dictionary:
	var coord_set: Dictionary = {}
	for c in sector_coords:
		coord_set[c] = true
	var adjacency: Dictionary = {}
	for c in sector_coords:
		var neighbors: Array = []
		for offset in NEIGHBOR_OFFSETS:
			var n: Vector2i = c + offset
			if coord_set.has(n):
				neighbors.append(n)
		adjacency[c] = neighbors
	return adjacency

func _generate_sector_coords(radius: int) -> Array:
	var coords: Array = []
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if abs(q) + abs(q + r) + abs(r) <= radius * 2:
				coords.append(Vector2i(q, r))
	return coords

func _sector_world_offset(coord: Vector2i, hex_radius: int, cell_size: float) -> Vector3:
	var q_off := hex_radius * (2 * coord.x + coord.y)
	var r_off := hex_radius * (-coord.x + coord.y)
	return StalbergGrid.axial_to_world(q_off, r_off, cell_size)
