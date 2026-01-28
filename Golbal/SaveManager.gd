extends Node

# 存档文件路径
const SAVE_PATH = "user://savegame.json"

# 指向其他的单例或主节点
# 注意：你需要确保这些节点在场景中是唯一的，并且名字正确
# 或者在 _ready() 中动态获取
var game_time_node
var player_node
var inventory_node

func _ready():
	# 尝试获取全局节点引用，根据实际场景层级修改
	# 假设结构是 /root/Main/GameTime, /root/Main/Player 等
	# 这里为了演示，我们假设在 load_game 时动态查找，或者由 Main 脚本注入
	print("SaveManager 已加载")
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("save"):
		save_game()
	if event.is_action_pressed("load"):
		load_game()
# --- 保存游戏 ---
func save_game():
	print("正在保存游戏...")
	
	# 1. 收集数据
	var save_data = {
		"game_time": _get_game_time_data(),
		"player": _get_player_data(),
		"inventory": _get_inventory_data(),
		"layerMap":_get_layerMap_data()
	}
	
	# 2. 序列化为 JSON 字符串
	var json_string = JSON.stringify(save_data, "\t") # \t 用于格式化美观
	
	# 3. 写入文件
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("游戏保存成功！路径：", ProjectSettings.globalize_path(SAVE_PATH))
	else:
		printerr("保存失败，无法打开文件：", SAVE_PATH)

# --- 读取游戏 ---
func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		print("没有找到存档文件。")
		return
	
	print("正在读取存档...")
	
	# 1. 读取文件
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	# 2. 解析 JSON
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		printerr("存档损坏，解析失败：", json.get_error_message())
		return
		
	var save_data = json.get_data()
	
	# 3. 恢复数据
	_restore_game_time(save_data.get("game_time", {}))
	_restore_player(save_data.get("player", {}))
	_restore_inventory(save_data.get("inventory", []))
	_restore_layerMap(save_data.get("layerMap", {}))
	print("游戏读取完成！")

# --- 子模块数据处理 ---

func _get_game_time_data() -> Dictionary:
	# 获取 GameTime 节点
	var gt = get_node_or_null("/root/Main/GameTime") # 根据实际路径调整
	if not gt and has_node("/root/GameTime"): gt = get_node("/root/GameTime") # 尝试 Global Autoload 名字
	
	if gt and gt.has_method("get_game_total_seconds"):
		return {
			"total_seconds": gt.get_game_total_seconds()
		}
	return {}

func _restore_game_time(data: Dictionary):
	if data.is_empty(): return
	var gt = get_node_or_null("/root/Main/GameTime")
	if not gt and has_node("/root/GameTime"): gt = get_node("/root/GameTime")
	
	if gt and gt.has_method("set_game_time"):
		gt.set_game_time(data.get("total_seconds", 0.0))

func _get_player_data() -> Dictionary:
	# 假设 Player 在 Main 场景下，名字叫 Player
	# 更好的方式是使用 Group："Player"
	var player = get_tree().get_first_node_in_group("Players")
	if player and player.has_method("get_save_data"):
		print('player.get_save_data()',player.get_save_data())
		return player.get_save_data()
	return {}

func _restore_player(data: Dictionary):
	if data.is_empty(): return
	var player = get_tree().get_first_node_in_group("Players")
	if player and player.has_method("load_save_data"):
		player.load_save_data(data)

func _get_inventory_data() -> Array:
	var player = get_tree().get_first_node_in_group("Player")
	if not player: return []
	
	# 假设 Player 下面有 InventoryManager
	var inv_mgr = player.get_node_or_null("playerBody/InventoryManager")
	if not inv_mgr: return []
	
	var items_data = []
	for slot in inv_mgr.slots:
		if slot and slot.item_data:
			items_data.append({
				"res_path": slot.item_data.resource_path, # 关键：保存资源路径
				"amount": slot.amount
			})
		else:
			items_data.append(null) # 空格也占位
	return items_data

func _restore_inventory(data: Array):
	var player = get_tree().get_first_node_in_group("Player")
	if not player: return
	
	var inv_mgr = player.get_node_or_null("playerBody/InventoryManager")
	if not inv_mgr: return
	
	# 清空并重新填充
	inv_mgr.slots.clear()
	inv_mgr.slots.resize(inv_mgr.max_slots)
	
	for i in range(min(data.size(), inv_mgr.slots.size())):
		var slot_data = data[i]
		if slot_data == null:
			inv_mgr.slots[i] = null
			continue
			
		var res_path = slot_data.get("res_path", "")
		var amount = slot_data.get("amount", 1)
		
		if ResourceLoader.exists(res_path):
			var item_res = load(res_path)
			var product = InventoryProduct.new()
			product.item_data = item_res
			product.amount = amount
			inv_mgr.slots[i] = product
		else:
			printerr("找不到物品资源：", res_path)
	
	inv_mgr.refresh_ui()
func _get_layerMap_data() -> Dictionary:
	var all_data = {}
	# 1. 获取组内所有的节点
	var layers = get_tree().get_nodes_in_group("layerMap")
	# 2. 遍历数组中的每一个节点
	for layer in layers:
		print('layer',layer)
		if layer is Node2D:
			# 这里手动提取数据，或者调用该层自己的提取函数
			all_data = layer.get_layer_map()
	
	return all_data

## 根据传入的 Dictionary 还原所有 TileMapLayer 的数据
func _restore_layerMap(data: Dictionary):
	var layers = get_tree().get_nodes_in_group("layerMap")
	for layer in layers:
		if layer is Node2D:
			layer.set_layer_map(data)
	print("地图层级数据还原完毕！")
