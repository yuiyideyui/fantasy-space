extends Resource
class_name UseableItem

@export_group("状态回复")
## 恢复生命值 (正数为恢复，负数为扣除)
@export var hp: float = 0
## 恢复水分
@export var hydration: float = 0
## 恢复饱食度
@export var satiety: float = 0
## 恢复理智值
@export var sanity: float = 0

@export_group("设置")
@export var is_consumable: bool = true

# 执行具体的效果逻辑
func use(stats: Node2D):
	if stats == null:
		push_error("物品使用失败：未传入有效的 CharacterStats")
		return

	# 注意：take_damage 和 consume 通常是减法。
	# 如果 hp 是 10（恢复量），传入 -hp 即 -10。
	# 内部逻辑通常是：当前值 -= 伤害值，即 当前值 -= -10，变为加法。
	if hp != 0: 
		stats.take_damage(-hp) 
	
	# 同理，如果这些方法内部是减法，这里需要取反
	if hydration != 0: 
		stats.consume_water(hydration)
		
	if satiety != 0: 
		stats.consume_hunger(satiety)
		
	if sanity != 0: 
		stats.change_san(sanity)
		
	print("物品 [", resource_name, "] 已应用效果")
