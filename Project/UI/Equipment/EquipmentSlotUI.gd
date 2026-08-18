extends PanelContainer
class_name EquipmentSlotUI

signal slot_selected

@onready var icon: TextureRect = $Icon
@onready var slot_name_label: Label = $SlotName

@export var slot: EquipmentSlotType.Id

const BASE_STYLE: StyleBoxFlat = preload("res://Project/UI/Themes/Styles/Equipment_Slot_Style.tres")
const HIGHLIGHT_COLOR := Color("6be675")
const EMPTY_COLOR := Color("6b5c4f")

var equipped_item: ItemDefinition
var equipment_component: EquipmentComponent
var inventory_component: InventoryComponent

var is_selected: bool = false
var _highlighted: bool = false

func _ready() -> void:
	gui_input.connect(_on_gui_input)

	var names := EquipmentSlotType.Id.keys()

	if slot < 0 or slot >= names.size():
		push_error("%s has invalid slot value %d" % [get_path(), slot])
		return

	slot_name_label.text = names[slot].capitalize()
	_refresh_style()

func set_equipment(item: ItemDefinition) -> void:
	equipped_item = item
	icon.texture = item.icon if item else null
	slot_name_label.visible = item == null
	_refresh_style()

func set_selected(value: bool) -> void:
	is_selected = value
	_refresh_style()

func _refresh_style() -> void:

	if _highlighted:
		return

	var style := BASE_STYLE.duplicate() as StyleBoxFlat
	style.border_color = ItemRarity.get_color(equipped_item.rarity) if equipped_item else EMPTY_COLOR

	if is_selected:
		style.border_color = Color("ffc23e")
		style.border_width_left = 4
		style.border_width_right = 4
		style.border_width_top = 4
		style.border_width_bottom = 4

	add_theme_stylebox_override("panel", style)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		slot_selected.emit()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or data.get("type") != "inventory_item":
		return false

	var item: ItemDefinition = data.get("item")

	if item == null or item.payload == null:
		return false

	if not (item.payload is ArmorPayload or item.payload is AccessoryPayload):
		return false

	return item.payload.get("equipment_slot") == slot

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var item: ItemDefinition = data["item"]
	var source_slot: InventorySlot = data["slot"]

	if EquipHelper.equip_from_inventory(item, source_slot, inventory_component, null, equipment_component):
		slot_selected.emit()
		
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		if _can_drop_data(Vector2.ZERO, data):
			_set_highlight(true)
	elif what == NOTIFICATION_DRAG_END:
		_set_highlight(false)

func _set_highlight(value: bool) -> void:

	_highlighted = value

	if not value:
		_refresh_style()
		return

	var style := BASE_STYLE.duplicate() as StyleBoxFlat
	style.border_color = HIGHLIGHT_COLOR
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	add_theme_stylebox_override("panel", style)
