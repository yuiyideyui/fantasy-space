extends Area2D

enum GrowthStage { SEED, SPROUT, MATURE }
var current_stage = GrowthStage.SEED

@onready var sprite = $AnimatedSprite2D
@onready var timer = $Timer

func _ready():
	sprite.frame = 0
	sprite.pause()

## 被 seedLayer 调用
func start_growth(total_time: float):
	# 每一阶段的时间 = 总时间 / (阶段数 - 1)
	timer.wait_time = total_time / 2.0
	timer.one_shot = false
	timer.start()

## 信号连接：Timer -> timeout
func _on_timer_timeout():
	if current_stage < GrowthStage.MATURE:
		current_stage += 1
		sprite.frame = current_stage
		
		if current_stage == GrowthStage.MATURE:
			timer.stop()
			# 成熟后可以添加一些视觉特效，比如发光
			# sprite.modulate = Color(1.2, 1.2, 1.2) 

## 响应玩家交互
func interactionFn(_source):
	if current_stage == GrowthStage.MATURE:
		harvest()
	else:
		print("还没熟，别急...")

func harvest():
	# 可以在这里实例化一个掉落物 ItemData 丢在地上
	# 或者直接加进玩家背包
	print("植物已收获")
	queue_free() # 触发 seedLayer 的 tree_exiting 信号
