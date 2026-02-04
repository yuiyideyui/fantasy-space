## AIClient.gd (单例)
extends Node

signal reply_received(npc_id: String, content: String)
signal connection_established() # 连接成功信号
signal connection_closed()      # 连接断开信号

var socket = WebSocketPeer.new()
var url = "ws://172.28.198.14:8765"
var last_state = WebSocketPeer.STATE_CLOSED

func _ready():
	print("正在尝试连接 AI 网关: ", url)
	socket.connect_to_url(url)
func _process(_delta):
	socket.poll()
	var current_state = socket.get_ready_state()
	
	if current_state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet()
			var raw_packet_str = packet.get_string_from_utf8()
			
			# 1. 首先解析外层的包装（网关发来的 {"npc_id":..., "content":...}）
			var outer_data = JSON.parse_string(raw_packet_str)
			print('outer_data',outer_data)
			if outer_data and outer_data.has("npc_id") and outer_data.has("content"):
				var npc_id = outer_data["npc_id"]
				var ai_raw_content = outer_data["content"] # 这里是你的 AI JSON 字符串
				
				# 2. 核心修复：解析内层的 AI 决策逻辑
				var final_content = _safe_parse_ai_json(ai_raw_content)
				
				# 发送信号，此时 final_content 已经是一个 Godot 字典了
				reply_received.emit(npc_id, final_content)

# 辅助函数：专门处理 AI 返回的那段 content 字符串
func _safe_parse_ai_json(raw_str):
	if typeof(raw_str) != TYPE_STRING:
		return raw_str
		
	var clean_text = raw_str.strip_edges()
	
	# 清洗 Markdown 标签 (如 ```json ... ```)
	if clean_text.begins_with("```"):
		# 移除开头的 ```json 或 ```
		var lines = clean_text.split("\n")
		if lines.size() > 2:
			lines.remove_at(0) # 移除第一行 ```json
			lines.remove_at(lines.size() - 1) # 移除最后一行 ```
			clean_text = "".join(lines).strip_edges()

	# 执行解析
	var json_tool = JSON.new()
	var error = json_tool.parse(clean_text)
	if error == OK:
		return json_tool.data # 返回解析好的 Dictionary
	else:
		# 如果 AI 抽风返回了非 JSON 纯文本，则返回原始文本
		print("[AIClient] AI 内容解析 JSON 失败: ", clean_text)
		return clean_text
# 处理状态变化的内部函数
func _on_state_changed(new_state):
	match new_state:
		WebSocketPeer.STATE_CONNECTING:
			print("[AIClient] 正在连接中...")
		WebSocketPeer.STATE_OPEN:
			print("[AIClient] 连接成功！可以发送数据了。")
			connection_established.emit()
		WebSocketPeer.STATE_CLOSING:
			print("[AIClient] 正在关闭连接...")
		WebSocketPeer.STATE_CLOSED:
			var code = socket.get_close_code()
			var reason = socket.get_close_reason()
			print("[AIClient] 连接已关闭。代码: %d, 原因: %s" % [code, reason])
			connection_closed.emit()

func send_to_ai(data_dict: Dictionary):
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		#print('JSON.stringify(data_dict)',JSON.stringify(data_dict))
		
		socket.send_text(JSON.stringify(data_dict))
	else:
		push_error("[AIClient] 发送失败：WebSocket 未连接！")
