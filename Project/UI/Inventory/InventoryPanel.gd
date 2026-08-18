extends Control
class_name InventoryPanel

signal item_info_requested(slot: InventorySlot)

@onready var tab_bar: InventoryTabBar = $VBoxContainer/TabBar
@onready var grid: GridContainer = $VBoxContainer/ScrollContainer/ItemGrid

@export var inventory_slot_scene: PackedScene
@export var grid_columns: int = 5

var character: Character
var inventory_component: InventoryComponent
var weapon_component: WeaponComponent
var equipment_component: EquipmentComponent
var selected_slot: InventorySlot
var current_filter: int = -1  # -1 = All

var _slot_uis: Array = []

func setup(bound_character: Character) -> void:

	character = bound_character

	if character == null or character.context == null or character.context.inventory == null:
		return

	inventory_component = character.context.inventory
	weapon_component = character.context.weapon
	equipment_component = character.context.equipment

	inventory_component.inventory_changed.connect(_on_inventory_changed)
	tab_bar.filter_selected.connect(_on_filter_selected)

	grid.columns = grid_columns
	_populate_inventory()
	
func clear_selection() -> void:
	selected_slot = null
	for slot_ui in _slot_uis:
		slot_ui.set_selected(false)

func _on_filter_selected(category: int) -> void:
	current_filter = category
	_populate_inventory()

func _populate_inventory() -> void:
	for child in grid.get_children():
		child.queue_free()
	_slot_uis.clear()

	for slot in inventory_component.get_all_slots():
		var item := slot.item as ItemDefinition
		if item == null:
			continue

		if current_filter != -1 and item.category != current_filter:
			continue

		var slot_ui = inventory_slot_scene.instantiate()
		grid.add_child(slot_ui)
		slot_ui.set_slot(slot)
		slot_ui.set_selected(slot == selected_slot)
		slot_ui.item_selected.connect(func(): _on_item_selected(slot))
		slot_ui.item_activated.connect(func(): _on_item_activated(slot))
		_slot_uis.append(slot_ui)

func _on_item_activated(slot: InventorySlot) -> void:

	if character == null or character.context == null:
		return

	var item := slot.item as ItemDefinition
	if item == null:
		return

	var equippable := item.category == ItemCategory.Id.WEAPON \
		or item.category == ItemCategory.Id.ARMOR \
		or item.category == ItemCategory.Id.ACCESSORY

	if equippable:
		EquipHelper.equip_from_inventory(item, slot, inventory_component, weapon_component, equipment_component)

	elif item.consumable:
		if item.heal_amount > 0.0 and character.context.health:
			character.context.health.heal(item.heal_amount)
		if item.restore_amount > 0.0 and character.context.resources:
			character.context.resources.restore(item.restore_resource_type, item.restore_amount)
		inventory_component.remove_item(item, 1)

func _on_item_selected(slot: InventorySlot) -> void:
	selected_slot = slot
	for slot_ui in _slot_uis:
		slot_ui.set_selected(slot_ui.slot == slot)
	item_info_requested.emit(slot)

func _on_inventory_changed() -> void:
	_populate_inventory()
