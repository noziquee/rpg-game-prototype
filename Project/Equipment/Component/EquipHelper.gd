extends RefCounted
class_name EquipHelper

## Equips an item that's currently sitting in a specific inventory slot.
## If something else was already equipped in the target slot, that item is
## inserted back into the inventory at the exact index the new item just
## vacated — the Terraria-style "swap places" behavior.
static func equip_from_inventory(
	item: ItemDefinition,
	source_slot: InventorySlot,
	inventory_component: InventoryComponent,
	weapon_component: WeaponComponent,
	equipment_component: EquipmentComponent
) -> bool:

	if item == null or item.payload == null:
		return false

	if item.payload is WeaponPayload:

		if weapon_component == null:
			return false

		var weapon_slot := (item.payload as WeaponPayload).weapon_slot
		var previous := weapon_component.get_equipped_item(weapon_slot)
		var index := inventory_component.remove_slot(source_slot) if inventory_component else -1

		weapon_component.equip(item, weapon_slot)

		if previous != null and inventory_component:
			inventory_component.insert_item_at(index, previous, 1)

		return true

	if item.payload is ArmorPayload or item.payload is AccessoryPayload:

		if equipment_component == null:
			return false

		var equip_slot: int = item.payload.get("equipment_slot")
		var previous := equipment_component.get_equipped(equip_slot)
		var index := inventory_component.remove_slot(source_slot) if inventory_component else -1

		equipment_component.equip(item)

		if previous != null and inventory_component:
			inventory_component.insert_item_at(index, previous, 1)

		return true

	return false

## Unequips whatever's in the given slot and returns it to the inventory
## (appended — there's no "original position" to restore to on unequip).
static func unequip_to_inventory(
	item: ItemDefinition,
	slot: int,
	is_weapon_slot: bool,
	inventory_component: InventoryComponent,
	weapon_component: WeaponComponent,
	equipment_component: EquipmentComponent
) -> void:

	if is_weapon_slot:
		if weapon_component:
			weapon_component.unequip(slot)
	else:
		if equipment_component:
			equipment_component.unequip(slot)

	if inventory_component and item:
		inventory_component.add_item(item, 1)
