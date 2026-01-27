extends Node2D

@export_group("AI 配置")
@export var npc_id: String = "npc_001"
@export var npc_name: String = "老村长"
@export_multiline var personality: String = "睿智但有些啰嗦，喜欢谈论当年的往事。"

# ⚠️ 注意：chatActionText 通常用来存历史记录。
# 如果你想发给 AI "玩家刚刚说了什么"，建议在函数里传参，而不是只发这个数组。
@export var chatActionText: Array = []

@onready var playerBody = $playerBody
# 建议变量名首字母小写，符合 GDScript 规范
@onready var inventory_manager = $playerBody/InventoryManager
# 这里的信号用于驱动队列
signal action_step_completed
func _ready():
	# 1. 最佳实践：在 _ready 中连接信号，而不是在交互时反复检查
	# 只要你在项目设置里把 AIClient 设为 Autoload，直接用类名访问即可
	AiClient.reply_received.connect(_on_ai_reply)

# 玩家点击 NPC 时触发
func interactionFn(_player: Node2D):
	print("正在向 AI 发送请求...")
	
	# 2. 构造发送给 AI 的数据
	# 这里假设 chatActionText 里存的是之前的对话历史或上下文
	var payload = {
		"npc_id": npc_id,
		"npc_name": npc_name,
		"personality": personality,
		# 你可能需要在这里加上玩家当前的输入，比如：
		# "player_input": "你好，村长！", 
		"history": chatActionText # 将 chatActionText 作为历史记录发送
	}
	
	# 3. 直接通过全局单例调用
	AiClient.send_to_ai(payload)

func _on_ai_reply(target_id: String, text: String):
	# 4. 过滤：只处理发给自己的消息
	if target_id == npc_id:
		print(npc_name, " (收到回复): ", text)
		
		# 将 AI 的回复存入历史记录，避免下次发送时丢失上下文
		chatActionText.append("NPC: " + text)
		# execute_action_queue(text.actions)

		# ---在此处更新 UI ---
		show_dialog_bubble(text)

# 模拟：显示气泡的方法
func show_dialog_bubble(text: String):
	# 假设你有一个子节点叫 Label 或者 DialogBox
	# $DialogLabel.text = text
	# $AnimationPlayer.play("show_bubble")
	pass


# 统一的动作执行入口
func execute_action_queue(actions: Array):
    for action in actions:
        print("正在执行动作: ", action.type)
        
        match action.type:
            "move":
                playerBody.set_nav_target()
                # 关键：等待导航结束信号
                await action_step_completed
            "attack":
                playerBody.perform_attack()
                # 关键：等待动画播放结束信号
                await action_step_completed
                
            "interact":
				playerBody.perform_interact()
                # 关键：等待计时器结束
                await action_step_completed
			"use":
				# 1. 获取玩家的背包管理器
				var inv = source.get_node_or_null("InventoryManager")
				if inv:
					# 2. 在 slots 中寻找名为 "纯净水" 的物品对象
					var to_use = null
					for slot in inv.slots:
						if slot and slot.item_data and slot.item_data.name == action.use.name:
							to_use = slot
							break # 找到第一个符合条件的就跳出循环
					
					# 3. 如果找到了水，就调用你现有的 remove_item_quantity 方法
					if to_use:
						inv.remove_item_quantity(to_use, 1) # 这里会扣除1并自动刷新UI
				await action_step_completed
        print("动作完成: ", action.type)
        # 此时循环会自动进入下一次迭代，执行下一个 action
    
    print("所有指令执行完毕！")