extends Node2D

@export var blood: int = 100
# 1. 声明一个信号
signal tree_died
func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

# 受到攻击的函数
func attack(attackBlood: int) -> void:
	# 减去血量并重新赋值
	blood -= attackBlood
	
	# 打印结果方便调试
	print("被攻击了！剩余血量: ", blood)
	
	# 检查是否死亡
	if blood <= 0:
		die()

func die():
	print("消失了")
	tree_died.emit()
	queue_free() # 从场景中删除自己（比如树倒了或石头碎了）
	
