extends Resource
class_name InventoryProduct

## 指向你的 ItemData (SeedItem, UseableItem 等)
@export var item_data: ItemData

## 当前堆叠的数量
@export var amount: int = 1

## 辅助函数：增加数量
func add_amount(value: int) -> void:
	amount += value
	# 如果是材料类，可以参考 MaterialItem 里的 max_stack 限制
