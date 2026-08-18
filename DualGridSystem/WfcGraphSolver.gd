class_name WfcGraphSolver
extends RefCounted

var adjacency_rules: Dictionary  # String tag -> Array[String] allowed neighbor tags
var all_tags: Array = []
var node_adjacency: Dictionary   # node_id -> Array[node_id]
var domains: Dictionary = {}     # node_id -> Array[String]
var result: Dictionary = {}      # node_id -> String

const MAX_RESTARTS := 20

func _init(rules: Dictionary) -> void:
	adjacency_rules = rules
	all_tags = rules.keys()

func solve(node_ids: Array, adjacency: Dictionary) -> bool:
	node_adjacency = adjacency
	for attempt in range(MAX_RESTARTS):
		if _try_solve(node_ids):
			return true
	return false

func _try_solve(node_ids: Array) -> bool:
	domains.clear()
	for id in node_ids:
		domains[id] = all_tags.duplicate()
	while true:
		var next = _find_lowest_entropy_node(node_ids)
		if next == null:
			break
		if not _collapse_node(next):
			return false
	result.clear()
	for id in node_ids:
		result[id] = domains[id][0]
	return true

func _find_lowest_entropy_node(node_ids: Array):
	var best_id = null
	var best_count := 999999
	for id in node_ids:
		var count: int = domains[id].size()
		if count > 1 and count < best_count:
			best_count = count
			best_id = id
	return best_id

func _collapse_node(id) -> bool:
	var options: Array = domains[id]
	if options.is_empty():
		return false
	var chosen: String = options[randi() % options.size()]
	domains[id] = [chosen]
	return _propagate([id])

func _propagate(seed_nodes: Array) -> bool:
	var queue: Array = seed_nodes.duplicate()
	while not queue.is_empty():
		var id = queue.pop_front()
		var current_tags: Array = domains[id]
		var allowed: Dictionary = {}
		for tag in current_tags:
			for allowed_tag in adjacency_rules.get(tag, []):
				allowed[allowed_tag] = true
		for neighbor_id in node_adjacency.get(id, []):
			if not domains.has(neighbor_id):
				continue
			var neighbor_domain: Array = domains[neighbor_id]
			var new_domain: Array = []
			for tag in neighbor_domain:
				if allowed.has(tag):
					new_domain.append(tag)
			if new_domain.size() < neighbor_domain.size():
				if new_domain.is_empty():
					return false
				domains[neighbor_id] = new_domain
				queue.append(neighbor_id)
	return true
