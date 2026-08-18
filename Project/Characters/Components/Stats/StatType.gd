extends RefCounted
class_name StatType

enum Id {
	STRENGTH,
	DEXTERITY,
	INTELLIGENCE,
	VITALITY,

	MOVE_SPEED,
	ATTACK_SPEED,

	CRITICAL_CHANCE,
	CRITICAL_DAMAGE,

	DEFENSE,

	POISE
}

const STAT_NAMES := {
	Id.STRENGTH: "Strength",
	Id.DEXTERITY: "Dexterity",
	Id.INTELLIGENCE: "Intelligence",
	Id.VITALITY: "Vitality",
	Id.MOVE_SPEED: "Move Speed",
	Id.ATTACK_SPEED: "Attack Speed",
	Id.CRITICAL_CHANCE: "Critical Chance",
	Id.CRITICAL_DAMAGE: "Critical Damage",
	Id.DEFENSE: "Defense",
	Id.POISE: "Poise",
}

static func get_display_name(id: Id) -> String:
	return STAT_NAMES.get(id, Id.keys()[id].capitalize())
