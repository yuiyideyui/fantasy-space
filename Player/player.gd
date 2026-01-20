## NPC.gd
extends Node2D

@export_group("AI 配置")
@export var npc_id: String = "npc_001"
@export var npc_name: String = "老村长"
@export_multiline var personality: String = "睿智但有些啰嗦，喜欢谈论当年的往事。"

# 引用全局的 WebSocket 客户端（单例/Autoload）
@onready var ai_client = get_node("/root/AIClient")

func interactionFn(_player: Node2D):
	# 监听这个 NPC 特有的回复信号（可选）
	if not ai_client.reply_received.is_connected(_on_ai_reply):
		ai_client.reply_received.connect(_on_ai_reply)
	
	var user_text = "你好！" # 这里之后可以改成 UI 输入框的内容
	
	# 发送请求时带上自己的身份信息
	ai_client.send_to_ai({
		"npc_id": npc_id,
		"npc_name": npc_name,
		"personality": personality,
		"content": user_text
	})

func _on_ai_reply(target_id: String, text: String):
	if target_id == npc_id:
		print(npc_name, " 说话了: ", text)
		# 这里触发对话框 UI 显示文字
