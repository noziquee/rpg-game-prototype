extends PanelContainer
class_name InventorySlotUI

signal item_selected
signal item_activated

@onready var icon: TextureRect = $Icon
@onready var quantity: Label = $Quantity

const BASE_STYLE := preload("res://Project/UI/Themes/Styles/inventory_slot_style.tres")

var slot: InventorySlot
var item: ItemDefinition
var item_quantity: int = 1
var is_selected: bool = false

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func set_slot(new_slot: InventorySlot) -> void:

	slot = new_slot
	item = new_slot.item as ItemDefinition
	item_quantity = new_slot.quantity

	if item:
		icon.texture = item.icon
		quantity.text = str(item_quantity) if item_quantity > 1 else ""
		tooltip_text = item.display_name

	_refresh_style()

func set_selected(value: bool) -> void:
	is_selected = value
	_refresh_style()

func _refresh_style() -> void:
	if item == null:
		return

	var style := BASE_STYLE.duplicate() as StyleBoxFlat
	style.border_color = ItemRarity.get_color(item.rarity)

	if is_selected:
		style.border_color = Color("ffc23e")
		style.border_width_left = 4
		style.border_width_right = 4
		style.border_width_top = 4
		style.border_width_bottom = 4

	add_theme_stylebox_override("panel", style)

func _on_gui_input(event: InputEvent) -> void:
	if not item:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			item_activated.emit()
		else:
			item_selected.emit()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item == null:
		return null

	DragPreviewManager.start(item.icon, Vector2(64, 64))

	return {"type": "inventory_item", "item": item, "slot": slot}
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		DragPreviewManager.stop()
