extends HBoxContainer
class_name InventoryTabBar

signal filter_selected(category: int)  # -1 = All

@onready var all_button: Button = $AllButton
@onready var weapons_button: Button = $WeaponsButton
@onready var armor_button: Button = $ArmorButton
@onready var accessories_button: Button = $AccessoriesButton
@onready var consumables_button: Button = $ConsumablesButton
@onready var materials_button: Button = $MaterialsButton

func _ready() -> void:
	all_button.pressed.connect(func(): filter_selected.emit(-1))
	weapons_button.pressed.connect(func(): filter_selected.emit(ItemCategory.Id.WEAPON))
	armor_button.pressed.connect(func(): filter_selected.emit(ItemCategory.Id.ARMOR))
	accessories_button.pressed.connect(func(): filter_selected.emit(ItemCategory.Id.ACCESSORY))
	consumables_button.pressed.connect(func(): filter_selected.emit(ItemCategory.Id.CONSUMABLE))
	materials_button.pressed.connect(func(): filter_selected.emit(ItemCategory.Id.MATERIAL))
