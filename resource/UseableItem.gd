extends Resource
class_name UseableItem

@export_group("状态回复")
@export var health_gain: float = 0
@export var water_gain: float = 0
@export var hunger_gain: float = 0
@export var san_gain: float = 0

@export var is_consumable: bool = true

# 执行具体的效果逻辑
func use(stats: CharacterStats):
	if health_gain != 0: stats.take_damage(-health_gain)
	if water_gain != 0: stats.consume_water(-water_gain)
	if hunger_gain != 0: stats.consume_hunger(-hunger_gain)
	if san_gain != 0: stats.change_san(san_gain)
	print("已应用物品效果")
