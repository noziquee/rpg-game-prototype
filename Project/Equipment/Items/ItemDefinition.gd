extends Resource
class_name ItemDefinition

#==============================================================================
# Identity
#==============================================================================
@export_group("Category")
@export var category: ItemCategory.Id = ItemCategory.Id.MISCELLANEOUS
@export var payload: ItemPayload

@export_group("Base")
@export var icon: Texture2D
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rarity: ItemRarity.Id = ItemRarity.Id.COMMON

@export_group("Economy")
@export var value: int = 0
@export var weight: float = 0.0

@export_group("Interaction")
@export var is_gatherable: bool = true


#==============================================================================
# Stacking
#==============================================================================

@export var stackable: bool = false

@export var consumable: bool = false

@export_group("Consumable Effects")
@export var heal_amount: float = 0.0
@export var restore_resource_type: ResourceType.Id = ResourceType.Id.MANA
@export var restore_amount: float = 0.0
