extends RefCounted
class_name ItemRarity

enum Id {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

const COLORS := {
	Id.COMMON: Color("9aa0a6"),
	Id.UNCOMMON: Color("4caf50"),
	Id.RARE: Color("3d8be0"),
	Id.EPIC: Color("ab47cf"),
	Id.LEGENDARY: Color("f5a623"),
}

const NAMES := {
	Id.COMMON: "Common",
	Id.UNCOMMON: "Uncommon",
	Id.RARE: "Rare",
	Id.EPIC: "Epic",
	Id.LEGENDARY: "Legendary",
}

static func get_color(id: Id) -> Color:
	return COLORS.get(id, Color.WHITE)

static func get_name(id: Id) -> String:
	return NAMES.get(id, "?")
