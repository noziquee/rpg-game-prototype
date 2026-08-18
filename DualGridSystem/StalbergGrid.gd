class_name StalbergGrid
extends RefCounted

var points: Dictionary = {}   # int id -> Vector3
var land: Dictionary = {}     # int id -> bool
var quads: Array = []         # Array[PackedInt32Array] (4 ids, CCW)
var _next_id: int = 0

var boundary_points: Dictionary = {}  # int id -> true, pinned during relax
var _edge_midpoints: Dictionary = {}  # Vector2i edge key -> midpoint id

func generate(radius: int, cell_size: float, relax_iterations: int, relax_strength: float) -> void:
	points.clear()
	land.clear()
	quads.clear()
	boundary_points.clear()
	_next_id = 0
	_edge_midpoints.clear()
	var axial_to_id := _generate_hex_points(radius, cell_size)
	var triangles := _triangulate(axial_to_id, radius)
	var merge_result := _merge_to_quads(triangles)
	var merged_pair_quads: Array = merge_result[0]
	var triangle_split_quads: Array = merge_result[1]

	var subdivided: Array = []
	for q in merged_pair_quads:
		for sub_q in _subdivide_quad(q):
			subdivided.append(sub_q)

	quads = subdivided + triangle_split_quads
	_compute_boundary_points()
	generate_unrelaxed(radius, cell_size)
	relax(relax_iterations, relax_strength)

func _add_point(pos: Vector3) -> int:
	var id := _next_id
	_next_id += 1
	points[id] = pos
	land[id] = "water"
	return id

func _generate_hex_points(radius: int, cell_size: float) -> Dictionary:
	var axial_to_id: Dictionary = {}
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if abs(q) + abs(q + r) + abs(r) <= radius * 2:
				var pos := axial_to_world(q, r, cell_size)
				axial_to_id[Vector2i(q, r)] = _add_point(pos)
	return axial_to_id

static func axial_to_world(q: int, r: int, cell_size: float) -> Vector3:
	var x := cell_size * (q + r * 0.5)
	var z := cell_size * (r * 0.8660254)
	return Vector3(x, 0, z)
	
func _triangulate(axial_to_id: Dictionary, radius: int) -> Array:
	var triangles: Array = []
	for q in range(-radius - 1, radius + 2):
		for r in range(-radius - 1, radius + 2):
			var p00 := Vector2i(q, r)
			var p10 := Vector2i(q + 1, r)
			var p01 := Vector2i(q, r + 1)
			var p11 := Vector2i(q + 1, r + 1)
			if axial_to_id.has(p00) and axial_to_id.has(p10) and axial_to_id.has(p01):
				triangles.append(PackedInt32Array([axial_to_id[p00], axial_to_id[p10], axial_to_id[p01]]))
			if axial_to_id.has(p10) and axial_to_id.has(p11) and axial_to_id.has(p01):
				triangles.append(PackedInt32Array([axial_to_id[p10], axial_to_id[p11], axial_to_id[p01]]))
	return triangles

func _edge_key(a: int, b: int) -> Vector2i:
	return Vector2i(min(a, b), max(a, b))

func _get_midpoint(a: int, b: int) -> int:
	var key := _edge_key(a, b)
	if _edge_midpoints.has(key):
		return _edge_midpoints[key]
	var mid_id := _add_point((points[a] + points[b]) / 2.0)
	_edge_midpoints[key] = mid_id
	return mid_id
	
func _merge_to_quads(triangles: Array) -> Array:
	var edge_to_tri: Dictionary = {}
	for i in range(triangles.size()):
		var tri: PackedInt32Array = triangles[i]
		for e in range(3):
			var key := _edge_key(tri[e], tri[(e + 1) % 3])
			if not edge_to_tri.has(key):
				edge_to_tri[key] = []
			edge_to_tri[key].append(i)

	var merged: Array = []
	merged.resize(triangles.size())
	for i in range(merged.size()):
		merged[i] = false

	var order: Array = range(triangles.size())
	order.shuffle()

	var merged_pair_quads: Array = []
	var leftover_tris: Array = []

	for i in order:
		if merged[i]:
			continue
		var tri: PackedInt32Array = triangles[i]
		var partner := -1
		for e in range(3):
			var key := _edge_key(tri[e], tri[(e + 1) % 3])
			for j in edge_to_tri[key]:
				if j != i and not merged[j]:
					partner = j
					break
			if partner != -1:
				break
		if partner == -1:
			leftover_tris.append(tri)
			continue
		merged[i] = true
		merged[partner] = true
		merged_pair_quads.append(_merge_pair(tri, triangles[partner]))

	var triangle_split_quads: Array = []
	for tri in leftover_tris:
		for q in _split_triangle_to_quads(tri):
			triangle_split_quads.append(q)

	return [merged_pair_quads, triangle_split_quads]

func _merge_pair(tri1: PackedInt32Array, tri2: PackedInt32Array) -> PackedInt32Array:
	var u1 := -1
	for v in tri1:
		if not tri2.has(v):
			u1 = v
	var u2 := -1
	for v in tri2:
		if not tri1.has(v):
			u2 = v
	var idx := tri1.find(u1)
	var s_a: int = tri1[(idx + 1) % 3]
	var s_b: int = tri1[(idx + 2) % 3]
	return PackedInt32Array([u1, s_a, u2, s_b])

func _split_triangle_to_quads(tri: PackedInt32Array) -> Array:
	var centroid_id := _add_point((points[tri[0]] + points[tri[1]] + points[tri[2]]) / 3.0)
	var mids: Array = []
	for e in range(3):
		var a: int = tri[e]
		var b: int = tri[(e + 1) % 3]
		mids.append(_get_midpoint(a, b))
	var result: Array = []
	for e in range(3):
		var v: int = tri[e]
		var mid_next: int = mids[e]
		var mid_prev: int = mids[(e + 2) % 3]
		result.append(PackedInt32Array([v, mid_next, centroid_id, mid_prev]))
	return result

func _subdivide_quad(quad: PackedInt32Array) -> Array:
	var c0: int = quad[0]; var c1: int = quad[1]; var c2: int = quad[2]; var c3: int = quad[3]
	var m01 := _get_midpoint(c0, c1)
	var m12 := _get_midpoint(c1, c2)
	var m23 := _get_midpoint(c2, c3)
	var m30 := _get_midpoint(c3, c0)
	var centroid := _add_point((points[c0] + points[c1] + points[c2] + points[c3]) / 4.0)
	return [
		PackedInt32Array([c0, m01, centroid, m30]),
		PackedInt32Array([c1, m12, centroid, m01]),
		PackedInt32Array([c2, m23, centroid, m12]),
		PackedInt32Array([c3, m30, centroid, m23]),
	]

func _build_adjacency() -> Dictionary:
	var adjacency: Dictionary = {}
	for quad in quads:
		for e in range(4):
			var a: int = quad[e]
			var b: int = quad[(e + 1) % 4]
			if not adjacency.has(a):
				adjacency[a] = []
			if not adjacency[a].has(b):
				adjacency[a].append(b)
			if not adjacency.has(b):
				adjacency[b] = []
			if not adjacency[b].has(a):
				adjacency[b].append(a)
	return adjacency

func _compute_boundary_points() -> void:
	boundary_points.clear()
	var edge_count: Dictionary = {}
	for quad in quads:
		for e in range(4):
			var a: int = quad[e]
			var b: int = quad[(e + 1) % 4]
			var key := _edge_key(a, b)
			edge_count[key] = edge_count.get(key, 0) + 1
	for key in edge_count.keys():
		if edge_count[key] == 1:
			boundary_points[key.x] = true
			boundary_points[key.y] = true
			
			
func generate_unrelaxed(radius: int, cell_size: float) -> void:
	points.clear()
	land.clear()
	quads.clear()
	boundary_points.clear()
	_next_id = 0
	_edge_midpoints.clear()
	var axial_to_id := _generate_hex_points(radius, cell_size)
	var triangles := _triangulate(axial_to_id, radius)
	var merge_result := _merge_to_quads(triangles)
	var merged_pair_quads: Array = merge_result[0]
	var triangle_split_quads: Array = merge_result[1]

	var subdivided: Array = []
	for q in merged_pair_quads:
		for sub_q in _subdivide_quad(q):
			subdivided.append(sub_q)

	quads = subdivided + triangle_split_quads
	_compute_boundary_points()

func relax(iterations: int, strength: float) -> void:
	_relax(iterations, strength)
	
func _relax(iterations: int, strength: float) -> void:
	var adjacency := _build_adjacency()
	for iter in range(iterations):
		var new_positions: Dictionary = {}
		for id in points.keys():
			if boundary_points.has(id):
				new_positions[id] = points[id]
				continue
			var neighbors: Array = adjacency.get(id, [])
			if neighbors.is_empty():
				new_positions[id] = points[id]
				continue
			var avg := Vector3.ZERO
			for n in neighbors:
				avg += points[n]
			avg /= neighbors.size()
			new_positions[id] = points[id].lerp(avg, strength)
		points = new_positions

func get_adjacency() -> Dictionary:
	return _build_adjacency()
	
	
