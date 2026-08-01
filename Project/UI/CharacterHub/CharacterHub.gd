extends BaseUIPanel
class_name CharacterHub

@onready var attributes_tab: Button = $LayoutMargin/Layout/TabList/Tabs/AttributesTab
@onready var equipment_tab: Button = $LayoutMargin/Layout/TabList/Tabs/EquipmentTab
@onready var skills_tab: Button = $LayoutMargin/Layout/TabList/Tabs/SkillsTab
@onready var items_tab: Button = $LayoutMargin/Layout/TabList/Tabs/ItemsTab

@onready var attributes_page: Control = $LayoutMargin/Layout/PageContainer/AttributesPage
@onready var equipment_page: Control = $LayoutMargin/Layout/PageContainer/EquipmentPage
@onready var skills_page: Control = $LayoutMargin/Layout/PageContainer/SkillsPage
@onready var items_page: Control = $LayoutMargin/Layout/PageContainer/ItemsPage

@onready var character_preview: CharacterScreen = $LayoutMargin/Layout/PageContainer/EquipmentPage/EquipmentAndWeaponsGrid/HBoxContainer/CharacterPreview/CharacterScreen

@onready var attributes_panel: CharacterStatsPanel = $LayoutMargin/Layout/PageContainer/AttributesPage/CharacterStatsPanel

@onready var equipment_panel: EquipmentPanel = $LayoutMargin/Layout/PageContainer/EquipmentPage/EquipmentAndWeaponsGrid
@onready var inventory_panel: InventoryPanel = $LayoutMargin/Layout/PageContainer/EquipmentPage/InventoryColumn/InventoryScrollRoot
@onready var item_stat_panel: ItemStatPanel = $LayoutMargin/Layout/PageContainer/EquipmentPage/InventoryColumn/ItemStatPanel

var _pages: Array[Control]

func _ready() -> void:
	layer = UILayerType.Id.SCREEN
	super._ready()

	UIManager.register_panel("character_hub", self)

	var character := CharacterRef.get_player()

	character_preview.setup(character)
	equipment_panel.setup(character)
	inventory_panel.setup(character)
	attributes_panel.setup(character)

	equipment_panel.item_info_requested.connect(item_stat_panel.show_item_info)
	inventory_panel.item_info_requested.connect(item_stat_panel.show_item_info)

	_pages = [attributes_page, equipment_page, skills_page, items_page]

	attributes_tab.pressed.connect(func(): _select_page(attributes_page))
	equipment_tab.pressed.connect(func(): _select_page(equipment_page))
	skills_tab.pressed.connect(func(): _select_page(skills_page))
	items_tab.pressed.connect(func(): _select_page(items_page))

	_select_page(equipment_page)   # default tab on open

	if not InputMap.has_action("toggle_character_hub"):
		InputMap.add_action("toggle_character_hub")
		var event := InputEventKey.new()
		event.keycode = KEY_C
		InputMap.action_add_event("toggle_character_hub", event)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_character_hub"):
		UIManager.toggle_panel("character_hub")
		get_viewport().set_input_as_handled()

func _select_page(page: Control) -> void:
	for p in _pages:
		p.visible = (p == page)
