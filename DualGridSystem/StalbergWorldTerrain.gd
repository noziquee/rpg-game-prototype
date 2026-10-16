extends Node3D

@export var hex_radius: int = 3
@export var cell_size: float = 2.0
@export var relax_iterations: int = 10
@export var relax_strength: float = 0.5
@export var world_radius: int = 1       # rings of sectors around the center sector
@export var enable_deformation: bool = true

@export var enable_biome_bleeding: bool = false
@export var bleed_width: float = 3.0
@export var bleed_noise_frequency: float = 0.15

var grid: StalbergGrid
var sector_map: HexSectorMap
var _quad_nodes: Array = []            # Array[MeshInstance3D], index matches grid.quads
var _point_to_quads: Dictionary = {}   # int point_id -> Array[int] quad indices

const WFC_RULES := {
	"water": ["water", "Forest"],
	"Forest": ["water", "Forest", "Desert", "Snow"],
	"Desert": ["Forest", "Desert"],
	"Snow": ["Forest", "Snow"],
}

const PATCH_WEIGHTS := {
	"water": 6.0,
	"Forest": 2.0,
	"Desert": 1.0,
	"Snow": 1.0,
}

const GUARANTEED_BIOMES := ["Forest", "Desert", "Snow"]

func _ready() -> void:
	var total_radius := world_radius * hex_radius

	grid = StalbergGrid.new()
	grid.generate(total_radius, cell_size, relax_iterations, relax_strength)

	sector_map = HexSectorMap.new()
	sector_map.build(grid, world_radius, hex_radius, cell_size)

	var sector_adjacency := sector_map.get_adjacency()
	var patch_solver := WfcGraphSolver.new(WFC_RULES, PATCH_WEIGHTS)
	var forced_seeds := _pick_guaranteed_seeds(sector_map.sector_coords, sector_adjacency)
	var patch_success: bool = patch_solver.solve(sector_map.sector_coords, sector_adjacency, forced_seeds)
	var patch_biomes: Dictionary = {}
	if patch_success:
		patch_biomes = patch_solver.result
		print("Sector WFC solved: ", sector_map.sector_coords.size(), " sectors")
	else:
		push_error("StalbergWorldTerrain: sector-level WFC failed, defaulting every sector to Forest")
		for coord in sector_map.sector_coords:
			patch_biomes[coord] = "Forest"

	if enable_biome_bleeding:
		var bleed_noise := FastNoiseLite.new()
		bleed_noise.seed = randi()
		bleed_noise.frequency = bleed_noise_frequency
		BiomeBleeder.apply(grid, sector_map, patch_biomes, bleed_width, bleed_noise)
	else:
		_assign_flat_biomes(patch_biomes)

	_build_point_quad_map()
	_render_all_quads()
	_build_debug_grid()

func _assign_flat_biomes(patch_biomes: Dictionary) -> void:
	for pid in grid.points.keys():
		var coord: Vector2i = sector_map.point_sector[pid]
		grid.land[pid] = patch_biomes.get(coord, "Forest")

func _build_point_quad_map() -> void:
	_point_to_quads.clear()
	for i in range(grid.quads.size()):
		var quad: PackedInt32Array = grid.quads[i]
		for pid in quad:
			if not _point_to_quads.has(pid):
				_point_to_quads[pid] = []
			_point_to_quads[pid].append(i)

func _render_all_quads() -> void:
	_quad_nodes.resize(grid.quads.size())
	for i in range(grid.quads.size()):
		var mesh_instance := MeshInstance3D.new()
		add_child(mesh_instance)
		_quad_nodes[i] = mesh_instance
		_update_quad(i)

func _update_quad(quad_index: int) -> void:
	var quad: PackedInt32Array = grid.quads[quad_index]
	var tags: Array = [
		grid.land.get(quad[0], "water"),
		grid.land.get(quad[1], "water"),
		grid.land.get(quad[2], "water"),
		grid.land.get(quad[3], "water"),
	]
	var biome := _pick_quad_biome(tags)

	var bitmask := 0
	if biome != "water" and tags[0] == biome: bitmask |= TileLibrary.TL
	if biome != "water" and tags[1] == biome: bitmask |= TileLibrary.TR
	if biome != "water" and tags[2] == biome: bitmask |= TileLibrary.BR
	if biome != "water" and tags[3] == biome: bitmask |= TileLibrary.BL

	bitmask = _apply_world_edge_shape(quad, bitmask)

	var tile_info := TileLibrary.get_tile(bitmask, biome)
	var mesh_instance: MeshInstance3D = _quad_nodes[quad_index]

	if tile_info["mesh"] == null:
		mesh_instance.mesh = null
		return

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

func _apply_world_edge_shape(quad: PackedInt32Array, bitmask: int) -> int:
	# Only taper a quad that would otherwise render as a solid Full block.
	# A quad that's already partial (a real biome/water transition) is left
	# alone — it already reflects the actual data.
	var full := TileLibrary.TL | TileLibrary.TR | TileLibrary.BR | TileLibrary.BL
	if bitmask != full:
		return bitmask

	var boundary_edges: Array = grid.get_boundary_edges_for_quad(quad)
	if boundary_edges.is_empty():
		return bitmask

	if boundary_edges.size() == 1:
		match boundary_edges[0]:
			0: return TileLibrary.TL | TileLibrary.TR
			1: return TileLibrary.TR | TileLibrary.BR
			2: return TileLibrary.BR | TileLibrary.BL
			3: return TileLibrary.BL | TileLibrary.TL

	if boundary_edges.size() >= 2:
		return _get_edge_corner_bitmask(boundary_edges)

	return bitmask

func _get_edge_corner_bitmask(boundary_edges: Array) -> int:
	var has_top := boundary_edges.has(0)
	var has_right := boundary_edges.has(1)
	var has_bottom := boundary_edges.has(2)
	var has_left := boundary_edges.has(3)

	if has_top and has_left: return TileLibrary.TL
	if has_top and has_right: return TileLibrary.TR
	if has_bottom and has_right: return TileLibrary.BR
	if has_bottom and has_left: return TileLibrary.BL

	return TileLibrary.TL

func _build_debug_grid() -> void:
	var mesh_instance := MeshInstance3D.new()
	add_child(mesh_instance)
	var immediate_mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.BLACK
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for quad in grid.quads:
		for e in range(4):
			var a: Vector3 = grid.points[quad[e]]
			var b: Vector3 = grid.points[quad[(e + 1) % 4]]
			immediate_mesh.surface_add_vertex(a + Vector3(0, 0.05, 0))
			immediate_mesh.surface_add_vertex(b + Vector3(0, 0.05, 0))
	immediate_mesh.surface_end()
	mesh_instance.mesh = immediate_mesh

func _find_nearest_point(world_pos: Vector3) -> int:
	var best_id := -1
	var best_dist := INF
	for id in grid.points.keys():
		var d: float = grid.points[id].distance_squared_to(world_pos)
		if d < best_dist:
			best_dist = d
			best_id = id
	return best_id

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
	var point_id := _find_nearest_point(hit)
	if point_id == -1:
		return

	var value := "Forest" if event.button_index == MOUSE_BUTTON_LEFT else "water"
	grid.land[point_id] = value
	for quad_index in _point_to_quads.get(point_id, []):
		_update_quad(quad_index)

func _pick_guaranteed_seeds(patch_coords: Array, adjacency: Dictionary) -> Dictionary:
	var shuffled: Array = patch_coords.duplicate()
	shuffled.shuffle()
	var forced: Dictionary = {}
	for biome in GUARANTEED_BIOMES:
		for coord in shuffled:
			if forced.has(coord):
				continue
			var compatible := true
			for neighbor in adjacency.get(coord, []):
				if forced.has(neighbor) and not WFC_RULES[forced[neighbor]].has(biome):
					compatible = false
					break
			if compatible:
				forced[coord] = biome
				break
	return forced
