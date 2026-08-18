extends Control
class_name EquipmentPanel

signal item_info_requested(item: ItemDefinition, slot: int, is_weapon_slot: bool)

@onready var left_column: VBoxContainer = $HBoxContainer/LeftCollumn
@onready var right_column: VBoxContainer = $HBoxContainer/RightCollumn

@onready var weapon_power_label: Label = $EquipedStatsPanel/WeaponPowerLabel
@onready var defense_label: Label = $EquipedStatsPanel/DefenseLabel
@onready var magic_power_label: Label = $EquipedStatsPanel/MagicPowerLabel

var character: Character
var inventory_component: InventoryComponent
var equipment_component: EquipmentComponent
var weapon_component: WeaponComponent
var equipment_slots: Dictionary = {}
var weapon_slots: Dictionary = {}

var _selected_widget: Control

func setup(bound_character: Character) -> void:

	character = bound_character

	if character == null or character.context == null:
		return

	inventory_component = character.context.inventory
	equipment_component = character.context.equipment
	weapon_component = character.context.weapon

	_bind_slots(left_column)
	_bind_slots(right_column)

	if equipment_component:
		equipment_component.equipment_equipped.connect(_on_equipment_changed)
		equipment_component.equipment_unequipped.connect(_on_equipment_changed)

	if weapon_component:
		weapon_component.weapon_equipped.connect(_on_weapon_changed)
		weapon_component.weapon_unequipped.connect(_on_weapon_changed)

	_update_equipment_display()
	_update_weapon_display()
	_update_derived_stats()

func clear_selection() -> void:
	if _selected_widget:
		_selected_widget.set_selected(false)
	_selected_widget = null

func _bind_slots(container: VBoxContainer) -> void:
	for child in container.get_children():
		if child is EquipmentSlotUI:
			child.slot_selected.connect(func(): _on_equipment_slot_selected(child))
			child.equipment_component = equipment_component
			child.inventory_component = inventory_component
			equipment_slots[child.slot] = child
		elif child is WeaponSlotUI:
			child.slot_selected.connect(func(): _on_weapon_slot_selected(child))
			child.weapon_component = weapon_component
			child.inventory_component = inventory_component
			weapon_slots[child.slot] = child

func _on_equipment_slot_selected(widget: EquipmentSlotUI) -> void:
	_select_widget(widget)
	var item := equipment_component.get_equipped(widget.slot) if equipment_component else null
	item_info_requested.emit(item, widget.slot, false)

func _on_weapon_slot_selected(widget: WeaponSlotUI) -> void:
	_select_widget(widget)
	var item := weapon_component.get_equipped_item(widget.slot) if weapon_component else null
	item_info_requested.emit(item, widget.slot, true)

func _select_widget(widget: Control) -> void:
	if _selected_widget and _selected_widget != widget:
		_selected_widget.set_selected(false)
	_selected_widget = widget
	widget.set_selected(true)

func _on_equipment_changed(_slot: int, _item: ItemDefinition) -> void:
	_update_equipment_display()

func _on_weapon_changed(_item: ItemDefinition, _slot: WeaponSlot.Id) -> void:
	_update_weapon_display()

func _update_equipment_display() -> void:
	for slot in equipment_slots.keys():
		equipment_slots[slot].set_equipment(equipment_component.get_equipped(slot))
	_update_derived_stats()

func _update_weapon_display() -> void:
	for slot in weapon_slots.keys():
		weapon_slots[slot].set_weapon(weapon_component.get_equipped_item(slot))
	_update_derived_stats()

func _update_derived_stats() -> void:

	if character == null or character.context == null:
		return

	# Weapon Power — main hand's base attack damage, 0 if unarmed
	var weapon_power := 0.0
	if weapon_component != null:
		var main_hand_attack := weapon_component.get_attack_definition() as AttackDefinition
		if main_hand_attack != null and main_hand_attack.attack_data != null:
			weapon_power = main_hand_attack.attack_data.damage

	# Defense — summed from all equipped armor's stat modifiers
	var defense := 0.0
	if equipment_component != null:
		for slot in equipment_slots.keys():
			var item := equipment_component.get_equipped(slot)
			if item == null:
				continue
			var modifiers: Array = item.payload.get("stat_modifiers")
			if modifiers == null:
				continue
			for entry: StatModifierEntry in modifiers:
				if entry.stat == StatType.Id.DEFENSE:
					defense += entry.value

	# Magic Power — closest existing stat is Intelligence
	var magic_power := 0.0
	if character.context.stats != null:
		magic_power = character.context.stats.get_stat(StatType.Id.INTELLIGENCE)

	weapon_power_label.text = "Weapon Power\n%d" % int(weapon_power)
	defense_label.text = "Defense\n%d" % int(defense)
	magic_power_label.text = "Magic Power\n%d" % int(magic_power)
