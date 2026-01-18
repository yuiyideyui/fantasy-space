extends Node
class_name CharacterStats  # 关键：定义类名，让其他脚本能识别它

@export var health: float = 100.0
@export var water: float = 100.0
@export var hunger: float = 100.0
@export var san: float = 100.0

# 这是一个让物品调用的通用函数
func apply_change(stat_name: String, amount: float):
	match stat_name:
		"health": health = clamp(health + amount, 0, 100)
		"water": water = clamp(water + amount, 0, 100)
		"hunger": hunger = clamp(hunger + amount, 0, 100)
		"san": san = clamp(san + amount, 0, 100)
	
	print("更新了状态 ", stat_name, "，当前值: ", get(stat_name))
