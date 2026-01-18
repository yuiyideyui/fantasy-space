extends Resource
class_name EquipmentItem

enum SlotType { MAIN_HAND, OFF_HAND, ARMOR, ACCESSORY }

@export_group("装备信息")
@export var slot: SlotType = SlotType.MAIN_HAND
@export var attack_power: int = 0
@export var defense: int = 0

# 装备逻辑
func on_equip(player):
	print("装备了: ", slot)
	# 可以在这里增加玩家的攻击力属性
