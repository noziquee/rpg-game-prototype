class_name BiomeBleeder
extends RefCounted

# Blends biomes across sector seams on a single unified StalbergGrid.
# There are no separate patches or welded point-groups anymore — a "seam
# point" is just a grid point that has at least one grid-adjacent neighbor
# in a different sector. We bleed each point toward the nearest seam point's
# other-side biome, the same edge_factor/noise blend as before.

static func apply(grid: StalbergGrid, sector_map: HexSectorMap, patch_biomes: Dictionary, bleed_width: float, noise: FastNoiseLite) -> void:
	var adjacency := grid.get_adjacency()

	# seam_points: pid -> Array[Vector2i] of neighboring sector coords that
	# touch this point (usually just one, occasionally more at a sector corner).
	var seam_points: Dictionary = {}
	for pid in grid.points.keys():
		var own_sector: Vector2i = sector_map.point_sector[pid]
		var neighbor_sectors: Array = []
		for npid in adjacency.get(pid, []):
			var n_sector: Vector2i = sector_map.point_sector[npid]
			if n_sector != own_sector and not neighbor_sectors.has(n_sector):
				neighbor_sectors.append(n_sector)
		if not neighbor_sectors.is_empty():
			seam_points[pid] = neighbor_sectors

	if seam_points.is_empty():
		return  # single-sector world, nothing to bleed

	var seam_ids: Array = seam_points.keys()

	for pid in grid.points.keys():
		var own_sector: Vector2i = sector_map.point_sector[pid]
		var own_biome: String = patch_biomes.get(own_sector, "Forest")
		var pos: Vector3 = grid.points[pid]

		var nearest_seam_id := -1
		var nearest_dist := INF
		for sid in seam_ids:
			var d: float = pos.distance_to(grid.points[sid])
			if d < nearest_dist:
				nearest_dist = d
				nearest_seam_id = sid

		var final_biome := own_biome
		if nearest_seam_id != -1 and nearest_dist < bleed_width:
			var neighbor_biome := _pick_neighbor_biome(seam_points[nearest_seam_id], patch_biomes, own_biome)
			if neighbor_biome != "":
				var edge_factor: float = 1.0 - (nearest_dist / bleed_width)
				var n: float = (noise.get_noise_3d(pos.x, pos.y, pos.z) + 1.0) * 0.5
				if n < edge_factor:
					final_biome = neighbor_biome

		grid.land[pid] = final_biome

static func _pick_neighbor_biome(neighbor_sectors: Array, patch_biomes: Dictionary, own_biome: String) -> String:
	for coord in neighbor_sectors:
		var candidate: String = patch_biomes.get(coord, own_biome)
		if candidate != own_biome:
			return candidate
	return ""
