extends Node2D
# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	pass # Replace with function body.
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
## 获取所有层级及其 Custom Data
func get_layer_map() -> Dictionary:
	var all_layers_data = {}
	
	for child in get_children():
		if child is TileMapLayer:
			var tile_set: TileSet = child.tile_set
			if not tile_set: continue
			
			# 优化：在进入格子循环前，先缓存所有自定义数据层的名字
			var custom_keys = []
			for i in range(tile_set.get_custom_data_layers_count()):
				custom_keys.append(tile_set.get_custom_data_layer_name(i))
			
			var cells_data = []
			for coords in child.get_used_cells():
				var cell_dict = {
					"x": coords.x, 
					"y": coords.y,
					"sid": child.get_cell_source_id(coords),
					"ax": child.get_cell_atlas_coords(coords).x,
					"ay": child.get_cell_atlas_coords(coords).y,
					"alt": child.get_cell_alternative_tile(coords),
					"cd": {} # Custom Data 的缩写，节省存档体积
				}
				
				var tile_data = child.get_cell_tile_data(coords)
				if tile_data:
					for key in custom_keys:
						var val = tile_data.get_custom_data(key)
						# 只有当数据不为 null 时才存储
						if val != null:
							cell_dict.cd[key] = val
				
				cells_data.append(cell_dict)
			
			all_layers_data[child.name] = cells_data
			
	return all_layers_data
## 根据保存的数据恢复所有层级
func set_layer_map(data_dict: Dictionary):
	for layer_name in data_dict.keys():
		var layer = find_child(layer_name, true, false)
		
		if layer and layer is TileMapLayer:
			layer.clear()
			var cells_data = data_dict[layer_name]
			
			for cell in cells_data:
				var coords = Vector2i(cell.get("x", 0), cell.get("y", 0))
				var atlas_coords = Vector2i(cell.get("ax", 0), cell.get("ay", 0))
				
				# 1. 基础恢复：物理层面的绘制
				layer.set_cell(coords, cell.get("sid", -1), atlas_coords, cell.get("alt", 0))
				
				# 2. 灵活恢复：全自动化遍历存档里的 custom_data (cd)
				if cell.has("cd") and cell.cd is Dictionary:
					# 遍历存档里存的所有 key，不管是 hp, type 还是你新加的任何东西
					for key in cell.cd.keys():
						var value = cell.cd[key]
						print('value',key,value)
						# 这里调用一个通用的分发函数，保持逻辑解耦
						_dispatch_custom_data(layer_name, coords, key, value)
var dynamic_tile_data: Dictionary = {}
func _dispatch_custom_data(layer_name: String, coords: Vector2i, data_key: String, data_value: Variant):
	# 创建一个唯一的 Key，区分层和坐标
	var cell_key = layer_name + ":" + str(coords)
	
	if not dynamic_tile_data.has(cell_key):
		dynamic_tile_data[cell_key] = {}
	
	# 这就是你要的“重新赋值”
	# 把存档里的 custom_data 还原到内存里的动态字典中
	dynamic_tile_data[cell_key][data_key] = data_value
