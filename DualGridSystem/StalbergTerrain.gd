extends Node3D

@export var hex_radius: int = 4
@export var cell_size: float = 2.0
@export var relax_iterations: int = 10
@export var relax_strength: float = 0.5
@export var island_radius: float = 6.0
@export var seed_island: bool = false
@export var enable_deformation: bool = false

var grid: StalbergGrid
var _quad_nodes: Array = []
var _point_to_quads: Dictionary = {}

func _ready() -> void:
	grid = StalbergGrid.new()
	grid.generate(hex_radius, cell_size, relax_iterations, relax_strength)
	_build_point_quad_map()
	if seed_island:
		_seed_island()
	_render_all_quads()
	_build_debug_grid()

func _build_point_quad_map() -> void:
	for i in range(grid.quads.size()):
		var quad: PackedInt32Array = grid.quads[i]
		for pid in quad:
			if not _point_to_quads.has(pid):
				_point_to_quads[pid] = []
			_point_to_quads[pid].append(i)

func _seed_island() -> void:
	for id in grid.points.keys():
		if grid.points[id].length() < island_radius:
			grid.land[id] = "Forest"

func _render_all_quads() -> void:
	_quad_nodes.resize(grid.quads.size())
	for i in range(grid.quads.size()):
		var mesh_instance := MeshInstance3D.new()
		add_child(mesh_instance)
		_quad_nodes[i] = mesh_instance
		_update_quad(i)

func _update_quad(quad_index: int) -> void:
	var quad: PackedInt32Array = grid.quads[quad_index]
	var bitmask := 0
	if grid.land.get(quad[0], "water") != "water": bitmask |= TileLibrary.TL
	if grid.land.get(quad[1], "water") != "water": bitmask |= TileLibrary.TR
	if grid.land.get(quad[2], "water") != "water": bitmask |= TileLibrary.BR
	if grid.land.get(quad[3], "water") != "water": bitmask |= TileLibrary.BL
	
	var tile_info := TileLibrary.get_tile(bitmask)
	var mesh_instance: MeshInstance3D = _quad_nodes[quad_index]

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
	grid.land[point_id] = "Forest" if event.button_index == MOUSE_BUTTON_LEFT else "water"
	for quad_index in _point_to_quads.get(point_id, []):
		_update_quad(quad_index)
