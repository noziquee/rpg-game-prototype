extends Node3D

@export var grid_width: int = 8
@export var grid_height: int = 8
@export var cell_size: float = 2.0
@export var jitter_strength: float = 0.35
@export var enable_deformation: bool = false

var _cell_jitter: Dictionary = {}  # Vector2i(cell) -> Vector2 world-space XZ offset
var grid_data: GridData
var _tile_nodes: Dictionary = {}  # Vector2i(dual_x, dual_y) -> MeshInstance3D

func _ready() -> void:
	grid_data = GridData.new(grid_width, grid_height)
	_generate_jitter()
	_build_all_tiles()
	_setup_ground_collision()
	_build_debug_grid()

func _build_all_tiles() -> void:
	for dy in range(grid_height + 1):
		for dx in range(grid_width + 1):
			var mesh_instance := MeshInstance3D.new()
			add_child(mesh_instance)
			mesh_instance.position = Vector3((dx - 0.5) * cell_size, 0, (dy - 0.5) * cell_size)
			_tile_nodes[Vector2i(dx, dy)] = mesh_instance
			_update_tile(dx, dy)

func _update_tile(dual_x: int, dual_y: int) -> void:
	var key := Vector2i(dual_x, dual_y)
	if not _tile_nodes.has(key):
		return
	var bitmask := grid_data.get_bitmask(dual_x, dual_y)
	var tile_info := TileLibrary.get_tile(bitmask)
	var mesh_instance: MeshInstance3D = _tile_nodes[key]

	if enable_deformation:
		var tl := _cell_world_pos(dual_x - 1, dual_y - 1)
		var tr := _cell_world_pos(dual_x, dual_y - 1)
		var br := _cell_world_pos(dual_x, dual_y)
		var bl := _cell_world_pos(dual_x - 1, dual_y)
		mesh_instance.mesh = TileDeformer.deform_mesh(tile_info["mesh"], tile_info["turns"], tl, tr, br, bl)
		mesh_instance.position = Vector3.ZERO
		mesh_instance.rotation = Vector3.ZERO
	else:
		mesh_instance.mesh = tile_info["mesh"]
		mesh_instance.position = Vector3((dual_x - 0.5) * cell_size, 0, (dual_y - 0.5) * cell_size)
		mesh_instance.rotation = Vector3(0, tile_info["turns"] * -PI / 2.0, 0)
	
func set_land(x: int, y: int, value: bool) -> void:
	if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
		return
	grid_data.set_land(x, y, value)
	for dy in [y, y + 1]:
		for dx in [x, x + 1]:
			_update_tile(dx, dy)

func _debug_seed() -> void:
	set_land(2, 2, true)
	set_land(3, 2, true)
	set_land(2, 3, true)
	set_land(4, 4, true)

func _setup_ground_collision() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(grid_width * cell_size, 0.1, grid_height * cell_size)
	collision.shape = shape
	body.add_child(collision)
	body.position = Vector3((grid_width - 1) * 0.5 * cell_size, -0.05, (grid_height - 1) * 0.5 * cell_size)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var from := camera.project_ray_origin(event.position)
	var to := from + camera.project_ray_normal(event.position) * 1000.0
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return
	var cell_x := int(round(result.position.x / cell_size))
	var cell_y := int(round(result.position.z / cell_size))
	set_land(cell_x, cell_y, event.button_index == MOUSE_BUTTON_LEFT)

func _build_debug_grid() -> void:
	var mesh_instance := MeshInstance3D.new()
	add_child(mesh_instance)
	var immediate_mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.BLACK
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var min_x := -0.5 * cell_size
	var max_x := (grid_width - 0.5) * cell_size
	var min_z := -0.5 * cell_size
	var max_z := (grid_height - 0.5) * cell_size
	for i in range(grid_width + 1):
		var x := (i - 0.5) * cell_size
		immediate_mesh.surface_add_vertex(Vector3(x, 0.05, min_z))
		immediate_mesh.surface_add_vertex(Vector3(x, 0.05, max_z))
	for j in range(grid_height + 1):
		var z := (j - 0.5) * cell_size
		immediate_mesh.surface_add_vertex(Vector3(min_x, 0.05, z))
		immediate_mesh.surface_add_vertex(Vector3(max_x, 0.05, z))
	immediate_mesh.surface_end()
	mesh_instance.mesh = immediate_mesh

func _generate_jitter() -> void:
	var max_offset := cell_size * jitter_strength
	for y in range(grid_height):
		for x in range(grid_width):
			_cell_jitter[Vector2i(x, y)] = Vector2(randf_range(-max_offset, max_offset), randf_range(-max_offset, max_offset))

func _cell_world_pos(cx: int, cy: int) -> Vector3:
	var base := Vector3(cx * cell_size, 0, cy * cell_size)
	var jitter: Vector2 = _cell_jitter.get(Vector2i(cx, cy), Vector2.ZERO)
	return base + Vector3(jitter.x, 0, jitter.y)
