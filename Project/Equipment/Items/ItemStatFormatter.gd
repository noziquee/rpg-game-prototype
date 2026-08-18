extends RefCounted
class_name ItemStatFormatter

## Builds the display lines for ItemStatPanel. Centralized so inventory items
## and already-equipped items are formatted identically instead of each
## caller rolling its own subset (this is what previously left weapon stats
## blank when a weapon slot was selected).

static func get_stat_lines(item: ItemDefinition) -> PackedStringArray:

	var lines: PackedStringArray = []

	if item == null or item.payload == null:
		return lines

	if item.payload is WeaponPayload:
		var weapon := item.payload as WeaponPayload
		lines.append("Damage: %d" % int(weapon.base_damage))
		lines.append("Attack Speed: %.1f" % weapon.attack_speed)
		lines.append("Range: %.1f" % weapon.attack_range)
		return lines

	var modifiers: Array = item.payload.get("stat_modifiers")

	if modifiers:
		for entry: StatModifierEntry in modifiers:
			lines.append("%s: +%d" % [StatType.get_display_name(entry.stat), int(entry.value)])

	if item.payload is ArmorPayload:
		var armor := item.payload as ArmorPayload
		if armor.armor_value > 0.0:
			lines.append("Armor: %d" % int(armor.armor_value))

	return lines
