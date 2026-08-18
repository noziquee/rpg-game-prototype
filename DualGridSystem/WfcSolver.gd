class_name WfcSolver
extends RefCounted

var width: int
var height: int
var adjacency_rules: Dictionary  # String biome -> Array[String] allowed neighbor biomes
var all_tags: Array = []
var domains: Dictionary = {}  # Vector2i -> Array[String] remaining possible tags
var result: Dictionary = {}   # Vector2i -> String, filled once solve() succeeds

const MAX_RESTARTS := 20

func _init(w: int, h: int, rules: Dictionary) -> void:
	width = w
	height = h
	adjacency_rules = rules
	all_tags = rules.keys()

func solve() -> bool:
	for attempt in range(MAX_RESTARTS):
		if _try_solve():
			return true
	return false

func _try_solve() -> bool:
	_reset_domains()
	while true:
		var next = _find_lowest_entropy_cell()
		if next == null:
			break  # every cell has exactly 1 possibility left — fully collapsed
		if not _collapse_cell(next):
			return false  # contradiction hit during propagation, caller retries
	result.clear()
	for pos in domains.keys():
		result[pos] = domains[pos][0]
	return true

func _reset_domains() -> void:
	domains.clear()
	for y in range(height):
		for x in range(width):
			domains[Vector2i(x, y)] = all_tags.duplicate()

func _find_lowest_entropy_cell():
	var best_pos = null
	var best_count := 999999
	for pos in domains.keys():
		var count: int = domains[pos].size()
		if count > 1 and count < best_count:
			best_count = count
			best_pos = pos
	return best_pos

func _collapse_cell(pos: Vector2i) -> bool:
	var options: Array = domains[pos]
	if options.is_empty():
		return false
	var chosen: String = options[randi() % options.size()]
	domains[pos] = [chosen]
	return _propagate([pos])

func _propagate(seed_cells: Array) -> bool:
	var queue: Array = seed_cells.duplicate()
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		var current_tags: Array = domains[pos]
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor_pos: Vector2i = pos + offset
			if not domains.has(neighbor_pos):
				continue
			var neighbor_domain: Array = domains[neighbor_pos]
			var allowed: Dictionary = {}
			for tag in current_tags:
				for allowed_tag in adjacency_rules.get(tag, []):
					allowed[allowed_tag] = true
			var new_domain: Array = []
			for tag in neighbor_domain:
				if allowed.has(tag):
					new_domain.append(tag)
			if new_domain.size() < neighbor_domain.size():
				if new_domain.is_empty():
					return false
				domains[neighbor_pos] = new_domain
				queue.append(neighbor_pos)
	return true
