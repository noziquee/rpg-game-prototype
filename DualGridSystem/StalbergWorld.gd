class_name StalbergWorld
extends RefCounted

const WELD_EPSILON := 0.01  # quantization size for merging exactly-coincident boundary points

var patches: Dictionary = {}          # Vector2i patch_coord -> StalbergGrid
var point_groups: Dictionary = {}     # canonical_key (String) -> Array[String] member keys
var point_to_group: Dictionary = {}   # member_key (String) -> canonical_key

func generate(patch_coords: Array, hex_radius: int, cell_size: float, relax_iterations: int, relax_strength: float) -> void:
	patches.clear()
	point_groups.clear()
	point_to_group.clear()

	for coord in patch_coords:
		var grid := StalbergGrid.new()
		grid.generate_unrelaxed(hex_radius, cell_size)
		_offset_patch(grid, _patch_world_offset(coord, hex_radius, cell_size))
		patches[coord] = grid

	_group_coincident_boundary_points(patch_coords)

	for coord in patch_coords:
		patches[coord].relax(relax_iterations, relax_strength)

func point_key(coord: Vector2i, point_id: int) -> String:
	return "%d,%d:%d" % [coord.x, coord.y, point_id]

func get_group_members(coord: Vector2i, point_id: int) -> Array:
	var key := point_key(coord, point_id)
	var group: String = point_to_group.get(key, key)
	return point_groups.get(group, [key])

func _patch_world_offset(coord: Vector2i, hex_radius: int, cell_size: float) -> Vector3:
	var q_off := hex_radius * (2 * coord.x + coord.y)
	var r_off := hex_radius * (-coord.x + coord.y)
	return StalbergGrid.axial_to_world(q_off, r_off, cell_size)

func _offset_patch(grid: StalbergGrid, offset: Vector3) -> void:
	for id in grid.points.keys():
		grid.points[id] += offset

func _position_key(pos: Vector3) -> Vector3i:
	return Vector3i(round(pos.x / WELD_EPSILON), round(pos.y / WELD_EPSILON), round(pos.z / WELD_EPSILON))

func _group_coincident_boundary_points(patch_coords: Array) -> void:
	var position_buckets: Dictionary = {}  # Vector3i -> Array[String] member keys
	for coord in patch_coords:
		var grid: StalbergGrid = patches[coord]
		for pid in grid.boundary_points.keys():
			var key := point_key(coord, pid)
			var bucket_key := _position_key(grid.points[pid])
			if not position_buckets.has(bucket_key):
				position_buckets[bucket_key] = []
			position_buckets[bucket_key].append(key)

	for bucket_key in position_buckets.keys():
		var members: Array = position_buckets[bucket_key]
		if members.size() < 2:
			continue
		for i in range(1, members.size()):
			_link_points(members[0], members[i])

func _link_points(key_a: String, key_b: String) -> void:
	if not point_to_group.has(key_a):
		point_groups[key_a] = [key_a]
		point_to_group[key_a] = key_a
	if not point_to_group.has(key_b):
		point_groups[key_b] = [key_b]
		point_to_group[key_b] = key_b

	var group_a: String = point_to_group[key_a]
	var group_b: String = point_to_group[key_b]
	if group_a == group_b:
		return
	for member in point_groups[group_b]:
		point_to_group[member] = group_a
		point_groups[group_a].append(member)
	point_groups.erase(group_b)

func build_point_graph() -> Dictionary:
	var canonical_of: Dictionary = {}   # member_key -> canonical_id
	var node_members: Dictionary = {}   # canonical_id -> Array[String] member_keys
	var node_ids: Array = []

	for coord in patches.keys():
		var grid: StalbergGrid = patches[coord]
		for pid in grid.points.keys():
			var key := point_key(coord, pid)
			if canonical_of.has(key):
				continue
			var canon: String = point_to_group.get(key, key)
			var members: Array = point_groups.get(canon, [key])
			for member in members:
				canonical_of[member] = canon
			node_members[canon] = members
			node_ids.append(canon)

	var adjacency: Dictionary = {}
	for coord in patches.keys():
		var grid: StalbergGrid = patches[coord]
		var local_adjacency: Dictionary = grid.get_adjacency()
		for pid in local_adjacency.keys():
			var self_canon: String = canonical_of[point_key(coord, pid)]
			if not adjacency.has(self_canon):
				adjacency[self_canon] = []
			for neighbor_pid in local_adjacency[pid]:
				var neighbor_canon: String = canonical_of[point_key(coord, neighbor_pid)]
				if neighbor_canon != self_canon and not adjacency[self_canon].has(neighbor_canon):
					adjacency[self_canon].append(neighbor_canon)

	return {"node_ids": node_ids, "adjacency": adjacency, "node_members": node_members}
