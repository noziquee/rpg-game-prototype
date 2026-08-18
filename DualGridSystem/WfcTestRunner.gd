extends Node

const RULES := {
	"water": ["water", "beach"],
	"beach": ["water", "beach", "forest"],
	"forest": ["beach", "forest", "mountain"],
	"mountain": ["forest", "mountain"],
}

const SYMBOLS := {
	"water": "~",
	"beach": ".",
	"forest": "T",
	"mountain": "^",
}

func _ready() -> void:
	var solver := WfcSolver.new(12, 10, RULES)
	var success := solver.solve()
	if not success:
		print("WFC failed to find a solution after retries")
		return
	_print_grid(solver)
	_validate(solver)

func _print_grid(solver: WfcSolver) -> void:
	for y in range(solver.height):
		var line := ""
		for x in range(solver.width):
			var tag: String = solver.result[Vector2i(x, y)]
			line += SYMBOLS.get(tag, "?")
		print(line)

func _validate(solver: WfcSolver) -> void:
	var violations := 0
	for y in range(solver.height):
		for x in range(solver.width):
			var pos := Vector2i(x, y)
			var tag: String = solver.result[pos]
			for offset in [Vector2i(1, 0), Vector2i(0, 1)]:
				var neighbor_pos: Vector2i = pos + offset
				if not solver.result.has(neighbor_pos):
					continue
				var neighbor_tag: String = solver.result[neighbor_pos]
				if not RULES.get(tag, []).has(neighbor_tag):
					violations += 1
					print("VIOLATION at ", pos, ": ", tag, " next to ", neighbor_tag)
	print("Validation complete. Violations found: ", violations)
