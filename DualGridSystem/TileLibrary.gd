extends Node

const GLB_PATH := "res://DualGridSystem/Assets/DualGridTiles.glb"

const USE_RANDOM_VARIANTS := true  # flip to true once shapes look solid

const TL := 1
const TR := 2
const BR := 4
const BL := 8

var biomes: Array = []
var _variants: Dictionary = {}
var _bitmask_table: Dictionary = {}

func _ready() -> void:
	_load_meshes()
	_build_bitmask_table()
	_compute_biomes()
	print("TileLibrary loaded bases: ", _variants.keys())
	print("TileLibrary biomes: ", biomes)

func _load_meshes() -> void:
	var packed: PackedScene = load(GLB_PATH)
	var temp: Node3D = packed.instantiate()
	var suffix_regex := RegEx.new()
	suffix_regex.compile("_(\\d+)$")
	for child in temp.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var match := suffix_regex.search(child.name)
			var base_name: String = child.name
			var variant_index := 0
			if match:
				base_name = child.name.substr(0, match.get_start())
				variant_index = int(match.get_string(1)) - 1
			if not _variants.has(base_name):
				_variants[base_name] = []
			var arr: Array = _variants[base_name]
			while arr.size() <= variant_index:
				arr.append(null)
			arr[variant_index] = child.mesh
	temp.free()

func _build_bitmask_table() -> void:
	_bitmask_table = {
		0: {"shape": "Empty", "turns": 0},
		15: {"shape": "Full", "turns": 0},

		TL: {"shape": "Corner", "turns": 0},
		TR: {"shape": "Corner", "turns": 1},
		BR: {"shape": "Corner", "turns": 2},
		BL: {"shape": "Corner", "turns": 3},

		TL | TR: {"shape": "Edge", "turns": 0},
		TR | BR: {"shape": "Edge", "turns": 1},
		BR | BL: {"shape": "Edge", "turns": 2},
		BL | TL: {"shape": "Edge", "turns": 3},

		TL | BR: {"shape": "Diagonal", "turns": 0},
		TR | BL: {"shape": "Diagonal", "turns": 1},

		TL | TR | BL: {"shape": "Three", "turns": 0},
		TL | TR | BR: {"shape": "Three", "turns": 1},
		TR | BR | BL: {"shape": "Three", "turns": 2},
		TL | BR | BL: {"shape": "Three", "turns": 3},
	}

func get_tile(bitmask: int, biome: String = "Forest") -> Dictionary:
	var entry: Dictionary = _bitmask_table[bitmask]
	var full_name: String = biome + "_" + entry["shape"]
	if not _variants.has(full_name):
		push_error("TileLibrary: no meshes found for '%s' — check biome name and glb export." % full_name)
		return {"mesh": null, "turns": entry["turns"]}
	var mesh_list: Array = _variants[full_name]
	var mesh: Mesh
	if USE_RANDOM_VARIANTS:
		mesh = mesh_list[randi() % mesh_list.size()]
	else:
		mesh = mesh_list[1]
	return {"mesh": mesh, "turns": entry["turns"]}
	
func _compute_biomes() -> void:
	var seen: Dictionary = {}
	for key in _variants.keys():
		seen[key.split("_")[0]] = true
	biomes = seen.keys()
