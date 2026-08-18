extends BaseComponent
class_name InventoryComponent

#==============================================================================
# Signals
#==============================================================================

signal inventory_changed()
signal item_added(item: Resource, quantity: int)

#==============================================================================
# Export Variables
#==============================================================================

@export var starting_items: Array[Resource] = []

@export var max_slots: int = 20

#==============================================================================
# Runtime
#==============================================================================

var _slots: Array[InventorySlot] = []

#==============================================================================
# Lifecycle
#==============================================================================

var _initializing: bool = false

func on_initialize() -> void:
	_initializing = true
	for item in starting_items:
		add_item(item, 1)
	_initializing = false

#==============================================================================
# Public API — adding / removing
#==============================================================================

func add_item(item: Resource, quantity: int = 1) -> bool:

	if item == null or quantity <= 0:
		return false

	var definition := item as ItemDefinition
	var stackable := definition != null and definition.stackable

	if stackable:

		var existing := _find_slot(item)

		if existing != null:
			existing.quantity += quantity
		else:
			if _slots.size() >= max_slots:
				return false
			_slots.append(InventorySlot.new(item, quantity))

	else:
		# Unstackable — one slot per copy.
		if _slots.size() + quantity > max_slots:
			return false

		for i in quantity:
			_slots.append(InventorySlot.new(item, 1))

	_finish_add(item, quantity)
	return true

func remove_item(item: Resource, quantity: int = 1) -> bool:

	if item == null or quantity <= 0:
		return false

	var slot := _find_slot(item)

	if slot == null or slot.quantity < quantity:
		return false

	slot.quantity -= quantity

	if slot.quantity <= 0:
		_slots.erase(slot)

	inventory_changed.emit()
	return true

## Removes one exact slot instance — needed once unstackable items can have
## several slots sharing the same item, so "remove one" has to mean "remove
## the specific card the player clicked/dragged," not "remove the first
## match." Returns the index the slot occupied (or -1 if not found) so the
## caller can reinsert something else at that same position.
func remove_slot(slot: InventorySlot) -> int:
	var index := _slots.find(slot)
	if index == -1:
		return -1
	_slots.remove_at(index)
	inventory_changed.emit()
	return index

## Inserts at a specific index instead of appending — used to put a
## just-unequipped item back exactly where the item that replaced it used
## to sit (the Terraria-style swap), instead of it jumping to the end of
## the list.
func insert_item_at(index: int, item: Resource, quantity: int = 1) -> void:

	if item == null or quantity <= 0:
		return

	var definition := item as ItemDefinition
	var stackable := definition != null and definition.stackable

	if stackable:
		var existing := _find_slot(item)
		if existing != null:
			existing.quantity += quantity
			inventory_changed.emit()
			return

	var clamped_index: int = clampi(index, 0, _slots.size())
	_slots.insert(clamped_index, InventorySlot.new(item, quantity))
	inventory_changed.emit()

func _finish_add(item: Resource, quantity: int) -> void:

	inventory_changed.emit()

	if _initializing:
		return

	item_added.emit(item, quantity)

	var definition := item as ItemDefinition
	if definition != null:
		UIEvents.item_picked_up.emit(definition, quantity)

#==============================================================================
# Public API — queries
#==============================================================================

func get_quantity(item: Resource) -> int:
	var total := 0
	for slot in _slots:
		if slot.item == item:
			total += slot.quantity
	return total

func has_item(item: Resource, quantity: int = 1) -> bool:
	return get_quantity(item) >= quantity

func get_all_slots() -> Array[InventorySlot]:
	return _slots

func _find_slot(item: Resource) -> InventorySlot:
	for slot in _slots:
		if slot.item == item:
			return slot
	return null

#==============================================================================
# Save/Load
#==============================================================================

func save_state() -> Array:
	var data: Array = []
	for slot in _slots:
		data.append({"path": slot.item.resource_path, "quantity": slot.quantity})
	return data

func load_state(data: Array) -> void:
	_slots.clear()
	for entry in data:
		var item := load(entry["path"]) as Resource
		if item != null:
			add_item(item, entry["quantity"])
