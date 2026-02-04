extends Node2D

@export_group("AI 配置")
@export var npc_id: String = "npc_001"
@export var npc_name: String = "老村长"
@export_multiline var personality: String = "睿智但有些啰嗦，喜欢谈论当年的往事。"
@export var isSleep: bool = false
@export var chatActionText: Array = []

# ==========================================
# --- 生存属性 (Survival Status) ---
# ==========================================
@export_group("生存状态")
## 饱食度：100为饱腹，0为饥饿。降为0时会持续扣除生命值。
@export var satiety: float = 100.0:
	set(v): satiety = clamp(v, 0, max_satiety)
@export var max_satiety: float = 100.0
## 含水量：100为充足，0为脱水。脱水会影响移动速度或体力回复。
@export var hydration: float = 100.0:
	set(v): hydration = clamp(v, 0, max_hydration)
@export var max_hydration: float = 100.0
## 理智值：100为清醒，0为疯狂。过低会触发幻听或视觉干扰。
@export var sanity: float = 100.0:
	set(v): sanity = clamp(v, 0, max_sanity)
@export var max_sanity: float = 100.0
# ==========================================
# --- 战斗属性 (Combat Stats) ---
# ==========================================
@export_group("战斗数值")
## 攻击力：角色造成的基础伤害值。
@export var attack_power: float = 10.0
## 防御力：降低受到的伤害，计算公式：实际伤害 = 敌人攻击 - 我方防御。
@export var defense: float = 5.0
## 生命值：角色的核心生命，归零则游戏结束。
@export var hp: float = 100.0:
	set(v): hp = clamp(v, 0, max_hp)
@export var max_hp: float = 100.0
# 消耗速率配置 (每单位游戏时间扣除的数值)
@export_group("Rates")
## 饱食度消耗
@export var satiety_decay_rate: float = 0.5
## 含水量消耗   
@export var hydration_decay_rate: float = 0.8
## 饥饿/脱水扣血量  
@export var starve_damage_rate: float = 2.0
## 自动回血量
@export var heal_rate: float = 1.5

@onready var playerBody = $playerBody
@onready var inventory_manager = $playerBody/InventoryManager

signal action_step_completed

func _ready():
	# 连接全局时间系统的 tick 信号
	GameTime.tick.connect(_on_game_tick)
	# 连接 AI 信号
	if AiClient:
		AiClient.reply_received.connect(_on_ai_reply)

func _input(event: InputEvent) -> void:
		# 比如按下 F7 时让玩家触发扫描
	if event is InputEventKey and event.pressed and event.keycode == KEY_F7:
		trigger_map_scan()
	

func trigger_map_scan():
	# 2. 构建一个“玩家上下文”字典
	var player_context = get_save_data()
	
	# 3. 调用 MapManager 的保存函数，并传入额外的数据进行合并
	# 注意：我们需要修改 MapManager 的接口来支持传入额外参数
	var res = MapManager.save_scene_data_to_local(player_context)
	
	var data = JSON.parse_string(res)
	# 创建一个数组来存放所有玩家信息
	var player_info_list = []

	var players = get_tree().get_nodes_in_group("Players")
	for p in players:
		if p.npc_id != npc_id:
			# ✅ 直接拿全局坐标
			var p_pos = p.playerBody.global_position
			print('p_pos',p_pos)
			var p_data = {
				"npc_name": p.npc_name,
				# 统一使用 global_pos 这个键名
				"position": {"x": int(p_pos.x), "y": int(p_pos.y)}
			}
			player_info_list.append(p_data)

	# 将整个列表存入 data 的新参数中
	data["orther_players_status"] = player_info_list
	_send_to_ai_core(data)
# --- 对话交互逻辑 ---

# 内部统一发送函数
func _send_to_ai_core(input_text: Dictionary):
	print(npc_name, " 正在向 AI 发送请求...")
	AiClient.send_to_ai(input_text)

# --- 回复与执行逻辑 ---
func _on_ai_reply(target_id: String, response_data: Dictionary):
	if target_id != npc_id:
		return
	var text = response_data.get("text", "").strip_edges() # 去除空格
	var actions = response_data.get("actions", [])
	print(npc_name, " (收到回复): ", text)
	# --- 修复点：不再这里手动 append，交给下面的函数统一处理 ---
	if not text.is_empty():
		show_dialog_bubble(text)
	if actions.size() > 0:
		execute_action_queue(actions)
	else:
		# 如果没有动作，等待后继续扫描
		await get_tree().create_timer(2.0).timeout
		trigger_map_scan()

func show_dialog_bubble(text: String):
	if isSleep:
		print("[Bubble]: ", npc_name, " 翻了个身：Zzz...")
		return # 睡觉时直接返回，不执行后面的逻辑
	print("[Bubble]: ", npc_name, " 说：", text)
	if text.is_empty(): # 使用内置的 is_empty() 更规范
		return
	var players = get_tree().get_nodes_in_group("Players")
	for p in players:
		# 确保对象有效且包含需要的属性，防止报错
		if not p.has_method("append") and not ("chatActionText" in p):
			continue
			
		var display_text: String
		if p.npc_id == npc_id:
			display_text = "我说：" + text
		else:
			display_text = npc_name + "说：" + text
		
		p.chatActionText.append(GameTime.get_timestamp()+display_text)
			

# --- 动作指令处理 ---

func execute_action_queue(actions: Array):
	print('actions', actions)
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
				print('pos_array', target_vector)
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
	get_tree().create_timer(5.0)
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
				inventory_manager.remove_item_quantity(slot, 1)
				# 执行常规使用逻辑（如喝水、吃东西）
				#playerBody._perform_planting(slot)
				# 2. 消耗物品数量
			# 
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
		"player_id": npc_id,
		"player_name": npc_name,
		"personality": personality,
		"hp": hp, # 假设值，你可以接真实的 hp
		"satiety": satiety,
		"hydration": hydration,
		"sanity": sanity,
		"attack_power": attack_power,
		"defense": defense,
		"is_sleep": isSleep,
		"current_pos": [round(playerBody.global_position.x), round(playerBody.global_position.y)],
		"chat_history": chatActionText,
		"inventory": inv_data,
	}
func load_save_data(data: Dictionary):
	# 1. 恢复位置
	var pos = data.get("current_pos")
	if pos is Array and pos.size() >= 2:
		playerBody.global_position = Vector2(pos[0], pos[1])
	
	# 2. 恢复状态
	satiety = data.get("satiety", satiety)
	hydration = data.get("hydration", hydration)
	sanity = data.get("sanity", sanity)
	attack_power = data.get("attack_power", attack_power)
	defense = data.get("defense", defense)
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
func _on_game_tick(delta: float):
	# 1. 计算消耗倍率 (如果正在睡觉，消耗减半)
	var multiplier = 0.01 if isSleep else 0.02
	
	# 2. 扣除饱食度和含水量
	satiety -= satiety_decay_rate * multiplier * delta
	hydration -= hydration_decay_rate * multiplier * delta
	# 3. 处理生命值逻辑
	_handle_hp_logic(delta)

func _handle_hp_logic(delta: float):
	# 检查是否处于极端状态 (0饱食 或 0含水)
	if satiety <= 0 or hydration <= 0:
		hp -= starve_damage_rate * delta
		return # 优先执行扣血，不执行回血
	
	# 检查是否满足回血条件 (双指标 > 50)
	if satiety > 50.0 and hydration > 50.0 and hp < max_hp:
		var sleep_heal_bonus = 2.0 if isSleep else 1.0
		hp += heal_rate * sleep_heal_bonus * delta
# 1. 处理生命值 (包含伤害和治疗)
func take_damage(amount: float):
	# 如果 amount 是负数（比如 -10），这里会变成 hp -= -10，即加血
	hp = clamp(hp - amount, 0, max_hp)
	print("HP 变化: ", -amount, " 当前: ", hp)

# 2. 处理水分 (通常消耗是减法，所以使用物品传入正数时应增加)
func consume_water(amount: float):
	# 逻辑：当前值 + 恢复量
	hydration = clamp(hydration + amount, 0, max_hydration)
	print("水分增加: ", amount, " 当前: ", hydration)

# 3. 处理饱食度
func consume_hunger(amount: float):
	# 逻辑：当前值 + 恢复量
	satiety = clamp(satiety + amount, 0, max_satiety)
	print("饱食度增加: ", amount, " 当前: ", satiety)

# 4. 处理理智值
func change_san(amount: float):
	# 逻辑：直接加减偏移量
	sanity = clamp(sanity + amount, 0, max_sanity)
	print("Sanity 变化: ", amount, " 当前: ", sanity)
