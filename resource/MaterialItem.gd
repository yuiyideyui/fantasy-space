extends Resource
class_name MaterialItem

@export_group("材料属性")
@export var stack_size: int = 99  # 最大堆叠数
@export var rarity: int = 1       # 稀有度 (例如: 1普通, 2稀有, 3传说)

# 材料通常是静态的，不需要复杂的 use() 函数
