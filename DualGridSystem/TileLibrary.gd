extends Node


#==============================================================================
# Asset
#==============================================================================

const GLB_PATH := "res://DualGridSystem/Assets/DualGridTiles.glb"


#==============================================================================
# Current Tile Set
#==============================================================================

# For now we ONLY use the Half tiles.
#
# Later this can become a configurable Half/Full system.
const USE_HALF_TILES := true


# Randomly select between .001, .002, .003 variants.
const USE_RANDOM_VARIANTS := true


#==============================================================================
# Bitmask
#==============================================================================

const TL := 1
const TR := 2
const BR := 4
const BL := 8


#==============================================================================
# Runtime Data
#==============================================================================

var biomes: Array = []

# Example:
#
# "Forest_Half_Corner" -> [Mesh, Mesh, Mesh]
# "Forest_Half_Edge"   -> [Mesh, Mesh, Mesh]
#
var _variants: Dictionary = {}

var _bitmask_table: Dictionary = {}


#==============================================================================
# Initialization
#==============================================================================

func _ready() -> void:

	_load_meshes()
	_build_bitmask_table()
	_compute_biomes()


	print(
		"TileLibrary loaded bases: ",
		_variants.keys()
	)

	print(
		"TileLibrary biomes: ",
		biomes
	)


#==============================================================================
# Load GLB
#==============================================================================

func _load_meshes() -> void:

	var packed: PackedScene = load(GLB_PATH)


	if packed == null:

		push_error(
			"TileLibrary: Failed to load GLB: "
			+ GLB_PATH
		)

		return


	var temp: Node3D = packed.instantiate()


	# Handles:
	#
	# Forest_Half_Corner
	# Forest_Half_Corner.001
	# Forest_Half_Corner.002
	#
	# Forest_Full_Corner
	# Forest_Full_Corner.001
	#
	var suffix_regex := RegEx.new()

	suffix_regex.compile(
	"[._](\\d+)$"
	)


	for child in temp.get_children():

		if not (child is MeshInstance3D):
			continue

		var mesh_instance: MeshInstance3D = child


		if mesh_instance.mesh == null:
			continue


		var base_name: String = mesh_instance.name
		var variant_index := 0


		var match := suffix_regex.search(
			base_name
		)


		if match:

			base_name = base_name.substr(
				0,
				match.get_start()
			)

			# Blender's .001 is the first variant.
			variant_index = (
				int(match.get_string(1)) - 1
			)


		if not _variants.has(base_name):
			_variants[base_name] = []


		var variants: Array = _variants[base_name]


		while variants.size() <= variant_index:
			variants.append(null)


		variants[variant_index] = mesh_instance.mesh


	temp.free()


#==============================================================================
# Bitmask Table
#==============================================================================

func _build_bitmask_table() -> void:

	_bitmask_table = {

		# No land.
		0: {
			"shape": "Empty",
			"turns": 0
		},


		# Four corners.
		15: {
			"shape": "Full",
			"turns": 0
		},


		# One corner.
		TL: {
			"shape": "Corner",
			"turns": 0
		},

		TR: {
			"shape": "Corner",
			"turns": 1
		},

		BR: {
			"shape": "Corner",
			"turns": 2
		},

		BL: {
			"shape": "Corner",
			"turns": 3
		},


		# Two adjacent corners.
		TL | TR: {
			"shape": "Edge",
			"turns": 0
		},

		TR | BR: {
			"shape": "Edge",
			"turns": 1
		},

		BR | BL: {
			"shape": "Edge",
			"turns": 2
		},

		BL | TL: {
			"shape": "Edge",
			"turns": 3
		},


		# Two diagonal corners.
		TL | BR: {
			"shape": "Diagonal",
			"turns": 0
		},

		TR | BL: {
			"shape": "Diagonal",
			"turns": 1
		},


		# Three corners.
		TL | TR | BL: {
			"shape": "Three",
			"turns": 0
		},

		TL | TR | BR: {
			"shape": "Three",
			"turns": 1
		},

		TR | BR | BL: {
			"shape": "Three",
			"turns": 2
		},

		TL | BR | BL: {
			"shape": "Three",
			"turns": 3
		}
	}


#==============================================================================
# Get Tile
#==============================================================================

func get_tile(
	bitmask: int,
	biome: String = "Forest"
) -> Dictionary:

	if bitmask == 0:

		return {
			"mesh": null,
			"turns": 0
		}


	if not _bitmask_table.has(bitmask):

		push_error(
			"TileLibrary: Unsupported bitmask: %d"
			% bitmask
		)

		return {
			"mesh": null,
			"turns": 0
		}


	var entry: Dictionary = _bitmask_table[bitmask]


	#----------------------------------------------------------------------
	# Half-only mode
	#----------------------------------------------------------------------

	var height_name := "Half"


	if not USE_HALF_TILES:
		height_name = "Full"


	var mesh_name: String = (
		biome
		+ "_"
		+ height_name
		+ "_"
		+ entry["shape"]
	)


	if not _variants.has(mesh_name):

		push_error(
			"TileLibrary: No meshes found for '%s'."
			% mesh_name
		)

		return {
			"mesh": null,
			"turns": entry["turns"]
		}


	var mesh_list: Array = _variants[mesh_name]


	var valid_meshes: Array = []


	for mesh in mesh_list:

		if mesh != null:
			valid_meshes.append(mesh)


	if valid_meshes.is_empty():

		push_error(
			"TileLibrary: Mesh list is empty for '%s'."
			% mesh_name
		)

		return {
			"mesh": null,
			"turns": entry["turns"]
		}


	var selected_mesh: Mesh


	if USE_RANDOM_VARIANTS:

		selected_mesh = valid_meshes[
			randi() % valid_meshes.size()
		]

	else:

		selected_mesh = valid_meshes[0]


	return {
		"mesh": selected_mesh,
		"turns": entry["turns"]
	}


#==============================================================================
# Biomes
#==============================================================================

func _compute_biomes() -> void:

	var seen: Dictionary = {}


	for key in _variants.keys():

		var parts: PackedStringArray = key.split("_")


		if parts.is_empty():
			continue


		seen[parts[0]] = true


	biomes = seen.keys()
