extends Node2D

@export_group("AI 配置")
@export var npc_id: String = "npc_001"
@export var npc_name: String = "老村长"
@export_multiline var personality: String = "睿智但有些啰嗦，喜欢谈论当年的往事。"
@export var isSleep: bool = false
@export var chatActionText: Array = []

@onready var playerBody = $playerBody
@onready var inventory_manager = $playerBody/InventoryManager

signal action_step_completed

func _ready():
	# 连接 AI 信号
	if AiClient:
		AiClient.reply_received.connect(_on_ai_reply)

func _input(event: InputEvent) -> void:
		# 比如按下 F7 时让玩家触发扫描
	if event is InputEventKey and event.pressed and event.keycode == KEY_F7:
		trigger_map_scan()
	

func trigger_map_scan():
	# 1. 获取玩家当前的背包资源数据
	var inv_data = inventory_manager.get_resource()
	
	# 2. 构建一个“玩家上下文”字典
	var player_context = {
		"player_id": npc_id,
		"player_name": npc_name,
		"personality":personality,
		"hp": 100, # 假设值，你可以接真实的 hp
		"inventory": inv_data,
		"is_sleeping": isSleep,
		"current_pos": [round(playerBody.global_position.x), round(playerBody.global_position.y)]
	}
	
	# 3. 调用 MapManager 的保存函数，并传入额外的数据进行合并
	# 注意：我们需要修改 MapManager 的接口来支持传入额外参数
	var res = MapManager.save_scene_data_to_local(player_context)
	_send_to_ai_core(JSON.parse_string(res))
# --- 对话交互逻辑 ---

# 内部统一发送函数
func _send_to_ai_core(input_text: Dictionary):
	print(npc_name, " 正在向 AI 发送请求...")
	AiClient.send_to_ai(input_text)

# --- 回复与执行逻辑 ---

func _on_ai_reply(target_id: String, response_data: Dictionary):
	if target_id != npc_id:
		return

	# 假设 AI 返回的数据结构包含 { "text": "...", "actions": [...] }
	var text = response_data.get("text", "")
	var actions = response_data.get("actions", [])

	print(npc_name, " (收到回复): ", text)
	chatActionText.append(npc_name + ": " + text)
	
	# 无论是否在睡觉，先显示气泡（如果是睡觉，气泡可以显示为 "Zzz"）
	show_dialog_bubble(text)
	
	# 执行动作序列（包含醒来的指令）
	if actions.size() > 0:
		execute_action_queue(actions)
	else:
		await get_tree().create_timer(2.0).timeout
		trigger_map_scan()

func show_dialog_bubble(text: String):
	if isSleep:
		# 如果还在睡觉状态，且 AI 没有给出 "wake" 动作前，强制显示 Zzz
		print("[Bubble]: ", npc_name, " 翻了个身：Zzz...")
	else:
		print("[Bubble]: ", npc_name, " 说：", text)

# --- 动作指令处理 ---

func execute_action_queue(actions: Array):
	print('actions',actions)
	for action in actions:
		match action.type:
			"sleep":
				if not isSleep:
					isSleep = true
					_play_pose("sleep")
					print(npc_name, " 进入了梦乡。")
				
			"wake":
				if isSleep:
					isSleep = false
					_play_pose("idle")
					print(npc_name, " 揉了揉眼睛，醒来了。")

			"move":
				if isSleep:
					print("处于睡觉状态，跳过移动动作")
					continue
				var pos_array = action["pos"] # 这是一个 Array [376.0, 160.0]
				
				# 核心修复：手动转换为 Vector2
				var target_vector = Vector2(pos_array[0], pos_array[1])
				print('pos_array',target_vector)
				# 现在传入 Vector2 就不会报错了
				playerBody.set_nav_target(target_vector)
				await action_step_completed
				
			"attack":
				if isSleep: continue
				playerBody.perform_attack()
				await action_step_completed
			"interact":
				if isSleep: 
					print("睡觉中，无法交互")
					continue
				# 执行交互动作
				playerBody.perform_interact()
				#await action_step_completed	
			"use":
				_handle_use_item(action.get("item_name"))
				#await action_step_completed

		print("动作完成: ", action.type)
	trigger_map_scan()
# 辅助方法：处理动作表现
func _play_pose(anim_name: String):
	# 模拟动画切换
	if playerBody.has_node("AnimationPlayer"):
		playerBody.get_node("AnimationPlayer").play(anim_name)

# 辅助方法：使用物品
func _handle_use_item(item_name: String):
	if not inventory_manager:
		return

	for slot in inventory_manager.slots:
		if slot and slot.item_data and slot.item_data.name == item_name:
			var item = slot.item_data
			
			# 1. 逻辑分支：判断是否为种子
			# 注意：请根据你 ItemData 脚本里实际的变量名（category 或 type）进行匹配
			if item.get("category") == 2:
				_plant_seed(slot)
			#else:
				# 执行常规使用逻辑（如喝水、吃东西）
				#playerBody._perform_planting(slot)
			
			# 2. 消耗物品数量
			inventory_manager.remove_item_quantity(slot, 1)
			print("使用了物品: ", item_name, "，剩余数量已更新")
			break

# 种植逻辑
func _plant_seed(slot):
	print("正在种植: ", slot.item_data.name)
	playerBody._perform_planting(slot)
	# 在这里实例化你的农作物场景
	# var crop = load("res://Scenes/Crops/Carrot.tscn").instantiate()
	# get_parent().add_child(crop)
	# crop.global_position = self.global_position # 在 NPC 当前位置种植

# --- 存档/读档支持 ---

func get_save_data() -> Dictionary:
	# 假设 inventory_manager.get_resource() 返回的是一个数组或字典
	# 里面包含了物品 ID 和数量
	var inv_data = inventory_manager.get_resource()
	return {
		"pos_x": playerBody.global_position.x,
		"pos_y": playerBody.global_position.y,
		"is_sleep": isSleep,
		"chat_history": chatActionText,
		"inventory": inv_data, # 直接存储结构化数据，不要在这里转字符串
	}
func load_save_data(data: Dictionary):
	# 1. 恢复位置
	playerBody.global_position.x = data.get("pos_x", playerBody.global_position.x)
	playerBody.global_position.y = data.get("pos_y", playerBody.global_position.y)
	
	# 2. 恢复状态
	isSleep = data.get("is_sleep", false)
	_play_pose("sleep" if isSleep else "idle")
		
	# 3. 恢复聊天记录
	chatActionText = data.get("chat_history", [])
	
	# 4. 恢复背包装态 (核心修复)
	var inv_data = data.get("inventory")
	if inv_data != null:
		# 如果存档里是 String (JSON)，先解析；如果是 Dictionary/Array，直接传
		if inv_data is String:
			var parsed = JSON.parse_string(inv_data)
			if parsed != null:
				inventory_manager.set_resource(parsed)
		else:
			inventory_manager.set_resource(inv_data)
			
	print(npc_name, " 状态恢复完毕。")
