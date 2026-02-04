extends Node2D
@onready var mutou = preload("res://resource/木头.tres")
@export var hp: int = 100
# 1. 声明一个信号
signal tree_died
func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

# 受到攻击的函数
func beAttack(player:Node2D,attackhp: int) -> void:
	# 减去血量并重新赋值
	hp -= attackhp
	
	# 打印结果方便调试
	print("被攻击了！剩余血量: ", hp)
	
	# 检查是否死亡
	if hp <= 0:
		die(player)

func die(player):
	player.chatActionText.append(GameTime.get_timestamp()+'树被击倒,获得10木头')
	player.inventory_manager.add_item(mutou,10)
	tree_died.emit()
	queue_free() # 从场景中删除自己（比如树倒了或石头碎了）
	
