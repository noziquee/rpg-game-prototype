extends PanelContainer
class_name ItemStatPanel

enum Source { NONE, INVENTORY, EQUIPPED }

@onready var name_label: Label = $VBox/Name
@onready var description_label: Label = $VBox/Description
@onready var stats_label: Label = $VBox/Stats
@onready var equip_button: Button = $VBox/EquipButton

var inventory_component: InventoryComponent
var weapon_component: WeaponComponent
var equipment_component: EquipmentComponent

var _item: ItemDefinition
var _inventory_slot: InventorySlot
var _source: Source = Source.NONE
var _equipped_slot: int = -1
var _is_weapon_slot: bool = false

func _ready() -> void:
	visible = false
	equip_button.pressed.connect(_on_equip_button_pressed)

func setup(character: Character) -> void:
	if character == null or character.context == null:
		return
	inventory_component = character.context.inventory
	weapon_component = character.context.weapon
	equipment_component = character.context.equipment

func show_inventory_item(slot: InventorySlot) -> void:
	_inventory_slot = slot
	_item = slot.item as ItemDefinition
	_source = Source.INVENTORY
	_refresh()

func show_equipped_item(item: ItemDefinition, slot: int, is_weapon_slot: bool) -> void:
	_item = item
	_source = Source.EQUIPPED
	_equipped_slot = slot
	_is_weapon_slot = is_weapon_slot
	_refresh()

func hide_info() -> void:
	visible = false
	_item = null
	_inventory_slot = null
	_source = Source.NONE

func _refresh() -> void:
	visible = true

	if _item == null:
		name_label.text = "Empty"
		name_label.modulate = Color.WHITE
		description_label.text = ""
		stats_label.text = ""
		equip_button.visible = false
		return

	name_label.text = _item.display_name
	name_label.modulate = ItemRarity.get_color(_item.rarity)
	description_label.text = _item.description
	stats_label.text = "\n".join(ItemStatFormatter.get_stat_lines(_item))

	var can_equip := _item.payload is WeaponPayload or _item.payload is ArmorPayload or _item.payload is AccessoryPayload

	equip_button.visible = can_equip
	equip_button.text = "Unequip" if _source == Source.EQUIPPED else "Equip"

func _on_equip_button_pressed() -> void:

	if _item == null:
		return

	if _source == Source.INVENTORY:
		EquipHelper.equip_from_inventory(_item, _inventory_slot, inventory_component, weapon_component, equipment_component)
		hide_info()

	elif _source == Source.EQUIPPED:
		EquipHelper.unequip_to_inventory(_item, _equipped_slot, _is_weapon_slot, inventory_component, weapon_component, equipment_component)
		hide_info()
