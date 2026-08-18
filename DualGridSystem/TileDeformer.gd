class_name TileDeformer
extends RefCounted

static func deform_mesh(source_mesh: Mesh, turns: int, tl: Vector3, tr: Vector3, br: Vector3, bl: Vector3) -> ArrayMesh:
	var arrays: Array = source_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var deformed_vertices := PackedVector3Array()
	deformed_vertices.resize(vertices.size())

	for i in range(vertices.size()):
		var v: Vector3 = vertices[i]
		var u := (v.x + 1.0) * 0.5
		var vv := (v.z + 1.0) * 0.5
		for t in range(turns):
			var new_u := 1.0 - vv
			var new_v := u
			u = new_u
			vv = new_v
		var top := tl.lerp(tr, u)
		var bottom := bl.lerp(br, u)
		var world := top.lerp(bottom, vv)
		deformed_vertices[i] = Vector3(world.x, v.y, world.z)

	var new_arrays: Array = arrays.duplicate()
	new_arrays[Mesh.ARRAY_VERTEX] = deformed_vertices

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)
	if source_mesh.surface_get_material(0):
		array_mesh.surface_set_material(0, source_mesh.surface_get_material(0))
	return array_mesh
