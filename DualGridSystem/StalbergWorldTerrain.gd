extends Node3D

@export var hex_radius: int = 3
@export var cell_size: float = 2.0
@export var relax_iterations: int = 10
@export var relax_strength: float = 0.5
@export var world_radius: int = 1       # rings of patches around the center patch
@export var enable_deformation: bool = true

var world: StalbergWorld
var _quad_nodes: Dictionary = {}       # Vector2i patch_coord -> Array[MeshInstance3D]
var _point_to_quads: Dictionary = {}   # Vector2i patch_coord -> Dictionary(point_id -> Array[int])

const WFC_RULES := {
	"water": ["water", "Forest"],
	"Forest": ["water", "Forest", "Desert", "Snow"],
	"Desert": ["Forest", "Desert"],
	"Snow": ["Forest", "Snow"],
}

func _ready() -> void:
	var patch_coords := _generate_patch_coords(world_radius)

	world = StalbergWorld.new()
	world.generate(patch_coords, hex_radius, cell_size, relax_iterations, relax_strength)

	var graph := world.build_point_graph()
	var solver := WfcGraphSolver.new(WFC_RULES)
	var success: bool = solver.solve(graph["node_ids"], graph["adjacency"])
	if success:
		_apply_wfc_result(solver.result, graph["node_members"])
		print("WFC solved: ", graph["node_ids"].size(), " points")
	else:
		push_error("StalbergWorldTerrain: WFC failed to find a solution, world will render as all-water")

	for coord in patch_coords:
		_build_point_quad_map(coord)
		_render_patch(coord)
	_build_debug_grid()

func _apply_wfc_result(result: Dictionary, node_members: Dictionary) -> void:
	for canon in result.keys():
		var tag: String = result[canon]
		for member_key in node_members[canon]:
			var parts: PackedStringArray = member_key.split(":")
			var coord_parts: PackedStringArray = parts[0].split(",")
			var coord := Vector2i(int(coord_parts[0]), int(coord_parts[1]))
			var point_id := int(parts[1])
			world.patches[coord].land[point_id] = tag
			
func _generate_patch_coords(radius: int) -> Array:
	var coords: Array = []
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if abs(q) + abs(q + r) + abs(r) <= radius * 2:
				coords.append(Vector2i(q, r))
	return coords

func _build_point_quad_map(coord: Vector2i) -> void:
	var grid: StalbergGrid = world.patches[coord]
	var map: Dictionary = {}
	for i in range(grid.quads.size()):
		var quad: PackedInt32Array = grid.quads[i]
		for pid in quad:
			if not map.has(pid):
				map[pid] = []
			map[pid].append(i)
	_point_to_quads[coord] = map

func _render_patch(coord: Vector2i) -> void:
	var grid: StalbergGrid = world.patches[coord]
	var nodes: Array = []
	nodes.resize(grid.quads.size())
	for i in range(grid.quads.size()):
		var mesh_instance := MeshInstance3D.new()
		add_child(mesh_instance)
		nodes[i] = mesh_instance
	_quad_nodes[coord] = nodes
	for i in range(grid.quads.size()):
		_update_quad(coord, i)

func _update_quad(coord: Vector2i, quad_index: int) -> void:
	var grid: StalbergGrid = world.patches[coord]
	var quad: PackedInt32Array = grid.quads[quad_index]
	var tags: Array = [
		grid.land.get(quad[0], "water"),
		grid.land.get(quad[1], "water"),
		grid.land.get(quad[2], "water"),
		grid.land.get(quad[3], "water"),
	]
	var bitmask := 0
	if tags[0] != "water": bitmask |= TileLibrary.TL
	if tags[1] != "water": bitmask |= TileLibrary.TR
	if tags[2] != "water": bitmask |= TileLibrary.BR
	if tags[3] != "water": bitmask |= TileLibrary.BL

	var biome := _pick_quad_biome(tags)
	var tile_info := TileLibrary.get_tile(bitmask, biome)
	var mesh_instance: MeshInstance3D = _quad_nodes[coord][quad_index]

	if enable_deformation:
		mesh_instance.mesh = TileDeformer.deform_mesh(
			tile_info["mesh"],
			tile_info["turns"],
			grid.points[quad[0]],
			grid.points[quad[1]],
			grid.points[quad[2]],
			grid.points[quad[3]]
		)
		mesh_instance.position = Vector3.ZERO
		mesh_instance.rotation = Vector3.ZERO
	else:
		var centroid: Vector3 = (grid.points[quad[0]] + grid.points[quad[1]] + grid.points[quad[2]] + grid.points[quad[3]]) / 4.0
		mesh_instance.mesh = tile_info["mesh"]
		mesh_instance.position = centroid
		mesh_instance.rotation = Vector3(0, tile_info["turns"] * -PI / 2.0, 0)

func _pick_quad_biome(tags: Array) -> String:
	var counts: Dictionary = {}
	for tag in tags:
		if tag == "water":
			continue
		counts[tag] = counts.get(tag, 0) + 1
	var best_tag := "Forest"
	var best_count := -1
	for tag in counts.keys():
		if counts[tag] > best_count:
			best_count = counts[tag]
			best_tag = tag
	return best_tag

func _build_debug_grid() -> void:
	var mesh_instance := MeshInstance3D.new()
	add_child(mesh_instance)
	var immediate_mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.BLACK
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for coord in world.patches.keys():
		var grid: StalbergGrid = world.patches[coord]
		for quad in grid.quads:
			for e in range(4):
				var a: Vector3 = grid.points[quad[e]]
				var b: Vector3 = grid.points[quad[(e + 1) % 4]]
				immediate_mesh.surface_add_vertex(a + Vector3(0, 0.05, 0))
				immediate_mesh.surface_add_vertex(b + Vector3(0, 0.05, 0))
	immediate_mesh.surface_end()
	mesh_instance.mesh = immediate_mesh

func _find_nearest_point(world_pos: Vector3) -> Dictionary:
	var best_coord: Vector2i
	var best_id := -1
	var best_dist := INF
	for coord in world.patches.keys():
		var grid: StalbergGrid = world.patches[coord]
		for id in grid.points.keys():
			var d: float = grid.points[id].distance_squared_to(world_pos)
			if d < best_dist:
				best_dist = d
				best_id = id
				best_coord = coord
	return {"coord": best_coord, "id": best_id}

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var from := camera.project_ray_origin(event.position)
	var dir := camera.project_ray_normal(event.position)
	var ground := Plane(Vector3.UP, 0.0)
	var hit = ground.intersects_ray(from, dir)
	if hit == null:
		return
	var found := _find_nearest_point(hit)
	if found["id"] == -1:
		return
	
	var value := "Forest" if event.button_index == MOUSE_BUTTON_LEFT else "water"

	for member_key in world.get_group_members(found["coord"], found["id"]):
		var parts: PackedStringArray = member_key.split(":")
		var coord_parts: PackedStringArray = parts[0].split(",")
		var member_coord := Vector2i(int(coord_parts[0]), int(coord_parts[1]))
		var member_id := int(parts[1])
		world.patches[member_coord].land[member_id] = value
		for quad_index in _point_to_quads[member_coord].get(member_id, []):
			_update_quad(member_coord, quad_index)
