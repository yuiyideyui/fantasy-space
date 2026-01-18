## AIClient.gd (单例)
extends Node

signal reply_received(npc_id: String, content: String)

var socket = WebSocketPeer.new()
var url = "ws://localhost:8765"

func _ready():
	socket.connect_to_url(url)

func _process(_delta):
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet()
			var data = JSON.parse_string(packet.get_string_from_utf8())
			if data:
				# 发出信号，带上 npc_id，对应的 NPC 会自己领走消息
				reply_received.emit(data["npc_id"], data["content"])

func send_to_ai(data_dict: Dictionary):
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(data_dict))
