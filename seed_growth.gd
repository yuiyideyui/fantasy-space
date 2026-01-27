extends Area2D

enum GrowthStage {SEED, SPROUT, MATURE}
var current_stage = GrowthStage.SEED

@onready var sprite = $AnimatedSprite2D
@onready var timer = $Timer

# --- 新增配置 ---
@export var water_boost_sec: float = 2.0 # 每次浇水减少的秒数

func _ready():
	sprite.frame = 0
	sprite.stop()
	
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

func start_growth(total_time: float):
	var stage_time = total_time / 2.0
	timer.wait_time = stage_time
	timer.one_shot = false
	timer.start()
	print("生长开始，每阶段时间: ", stage_time)

func _on_timer_timeout():
	if current_stage < GrowthStage.MATURE:
		current_stage += 1
		sprite.frame = current_stage
		print("植物进化！当前阶段: ", current_stage)
		
		if current_stage == GrowthStage.MATURE:
			timer.stop()
			print("植物已成熟")

func interactionFn(source, player: Node2D):
	if current_stage == GrowthStage.MATURE:
		harvest(source, player)
	else:
		# 1. 获取玩家的背包管理器
		var inv = source.get_node_or_null("InventoryManager")
		if inv:
			# 2. 在 slots 中寻找名为 "纯净水" 的物品对象
			var water_to_use = null
			for slot in inv.slots:
				if slot and slot.item_data and slot.item_data.name == "纯净水":
					water_to_use = slot
					break # 找到第一个符合条件的就跳出循环
			
			# 3. 如果找到了水，就调用你现有的 remove_item_quantity 方法
			if water_to_use:
				inv.remove_item_quantity(water_to_use, 1) # 这里会扣除1并自动刷新UI
				apply_water_boost() # 执行浇水减时间逻辑
				print("使用了一瓶纯净水，剩余数量: ", water_to_use.amount)
			else:
				print("背包里没有纯净水！")

## --- 新增：核心浇水加速函数 ---
func apply_water_boost():
	if current_stage == GrowthStage.MATURE:
		return

	if not timer.is_stopped():
		var remaining = timer.time_left
		var new_time = remaining - water_boost_sec
		
		# 1. 视觉反馈：闪烁水蓝色
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.AQUA, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		
		# 2. 逻辑处理
		if new_time <= 0:
			print("浇水：直接进入下一阶段！")
			# 手动触发超时逻辑
			_on_timer_timeout()
			# 如果还没熟，开启下一阶段的新计时
			if current_stage < GrowthStage.MATURE:
				timer.start(timer.wait_time)
		else:
			print("浇水成功：缩短了 ", water_boost_sec, "s")
			# 重新启动计时器，剩余时间为缩短后的时间
			timer.start(new_time)

func harvest(last_interacted_source, player: Node2D):
	# 1. 找到玩家（source 在 interactionFn 里传进来了，我们可以存一下）
	# 或者通过这种方式查找（假设玩家在主场景）：
	# print("植物已收获")
	# player.chatActionText.append("获得胡萝卜数量1")
	if last_interacted_source:
		var inv = last_interacted_source.get_node_or_null("InventoryManager")
		if inv:
			# 调用你背包管理器的添加方法
			# 假设你的方法叫 add_item(item_data, quantity)
			inv.add_item(preload("res://resource/胡萝卜.tres"), 1)
			print("已将 ", " 放入背包")
	queue_free()
