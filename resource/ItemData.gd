@tool
extends Resource
class_name ItemData

enum ItemCategory { MATERIAL, USEABLE, SEED, EQUIPMENT }

@export_group("核心信息")
@export var name: String = "新物品"
@export var id: int
@export var texture: Texture2D
@export_multiline var describe: String = ""

@export_group("类别管理")
@export var category: ItemCategory = ItemCategory.MATERIAL:
	set(v):
		if category != v or item_logic == null:
			category = v
			_update_logic()
			notify_property_list_changed()

@export var item_logic: Resource

func _update_logic():
	# 检查当前 item_logic 的类型，如果不符合当前 category 则重新创建
	match category:
		ItemCategory.MATERIAL:
			if not item_logic is MaterialItem:
				item_logic = MaterialItem.new()
		ItemCategory.USEABLE:
			if not item_logic is UseableItem:
				item_logic = UseableItem.new()
		ItemCategory.SEED:
			if not item_logic is SeedItem:
				item_logic = SeedItem.new()
		ItemCategory.EQUIPMENT:
			if not item_logic is EquipmentItem:
				item_logic = EquipmentItem.new()
