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

# --- 对话交互逻辑 ---

# 其他人找我说话（被动）
func npc_chat_fn(_player: Node, text: String):
	var prompt = text
	if isSleep:
		# 给 AI 提供明确的状态上下文，让它决定是否要醒来
		prompt = "（当前状态：你在睡觉。%s 对你说：\"%s\"。你可以选择继续睡并说梦话，或者醒来回复。）" % [_player.npc_name, text]
	_send_to_ai_core(prompt)

# 主动触发：自我询问/环境观察
func npc_chat_curr():
	# 核心需求：睡觉时不应该自行询问
	if isSleep:
		print(npc_name, "正在睡觉，无法产生主动思考。")
		return
	
	_send_to_ai_core("观察周围环境并决定下一步动作。")

# 内部统一发送函数
func _send_to_ai_core(input_text: String):
	print(npc_name, " 正在向 AI 发送请求...")
	chatActionText.append("System: " + input_text)
	
	var payload = {
		"npc_id": npc_id,
		"npc_name": npc_name,
		"personality": personality,
		"is_sleeping": isSleep, # 告诉 AI 它现在的状态
		"history": chatActionText
	}
	AiClient.send_to_ai(payload)

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

func show_dialog_bubble(text: String):
	if isSleep:
		# 如果还在睡觉状态，且 AI 没有给出 "wake" 动作前，强制显示 Zzz
		print("[Bubble]: ", npc_name, " 翻了个身：Zzz...")
	else:
		print("[Bubble]: ", npc_name, " 说：", text)

# --- 动作指令处理 ---

func execute_action_queue(actions: Array):
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
				playerBody.set_nav_target(action.get("pos"))
				await action_step_completed
				
			"attack":
				if isSleep: continue
				playerBody.perform_attack()
				await action_step_completed
				
			"use":
				_handle_use_item(action.get("item_name"))
				await action_step_completed

		print("动作完成: ", action.type)
	
	print("所有指令执行完毕！")

# 辅助方法：处理动作表现
func _play_pose(anim_name: String):
	# 模拟动画切换
	if playerBody.has_node("AnimationPlayer"):
		playerBody.get_node("AnimationPlayer").play(anim_name)

# 辅助方法：使用物品
func _handle_use_item(item_name: String):
	if inventory_manager:
		for slot in inventory_manager.slots:
			if slot and slot.item_data and slot.item_data.name == item_name:
				inventory_manager.remove_item_quantity(slot, 1)
				break

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
