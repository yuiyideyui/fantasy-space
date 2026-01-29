extends Node2D

# 存储运行时动态数据，例如 {"LayerName:(0, 0)": {"Seeded": true, "plant_path": "...", "stage": 1}}
var dynamic_tile_data: Dictionary = {}

## 获取所有层级及其数据（用于存档）
func get_layer_map() -> Dictionary:
	var all_layers_data = {}
	
	for child in get_children():
		if child is TileMapLayer:
			var tile_set: TileSet = child.tile_set
			if not tile_set: continue
			
			# 缓存当前层级 TileSet 定义的自定义数据层名称 
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
					"cd": {} # Custom Data 容器 
				}
				
				# 1. 提取静态 TileData (TileSet 中配置的默认属性) 
				var tile_data = child.get_cell_tile_data(coords)
				if tile_data:
					for key in custom_keys:
						var val = tile_data.get_custom_data(key)
						if val != null:
							cell_dict.cd[key] = val
				
				# 2. 核心修复：合并该位置的动态运行时数据 (Seeded, plant_path 等) 
				var cell_key = child.name + ":" + str(coords)
				if dynamic_tile_data.has(cell_key):
					cell_dict.cd.merge(dynamic_tile_data[cell_key], true)
				
				cells_data.append(cell_dict)
			
			all_layers_data[child.name] = cells_data
			
	return all_layers_data

## 根据存档数据恢复层级
func set_layer_map(data_dict: Dictionary):
	# 恢复前清理当前状态
	dynamic_tile_data.clear()
	
	for layer_name in data_dict.keys():
		var layer = find_child(layer_name, true, false)
		if layer and layer is TileMapLayer:
			layer.clear()
			var cells_data = data_dict[layer_name]
			
			for cell in cells_data:
				var coords = Vector2i(cell.get("x", 0), cell.get("y", 0))
				var atlas_coords = Vector2i(cell.get("ax", 0), cell.get("ay", 0))
				
				# 1. 恢复物理瓦片绘制 
				layer.set_cell(coords, cell.get("sid", -1), atlas_coords, cell.get("alt", 0))
				
				# 2. 恢复自定义数据到动态缓存 
				if cell.has("cd") and cell.cd is Dictionary:
					for key in cell.cd.keys():
						_dispatch_custom_data(layer_name, coords, key, cell.cd[key])

## 内部数据分发与实体触发
func _dispatch_custom_data(layer_name: String, coords: Vector2i, data_key: String, data_value: Variant):
	var cell_key = layer_name + ":" + str(coords)
	if not dynamic_tile_data.has(cell_key):
		dynamic_tile_data[cell_key] = {}
	
	dynamic_tile_data[cell_key][data_key] = data_value

	# 发现 Seeded 标记且为真时，触发植物还原 
	if data_key == "Seeded" and data_value == true:
		# 使用 call_deferred 确保在 TileMapLayer 绘制完成后再添加子节点
		_restore_plant_entity.call_deferred(layer_name, coords)

# mapLayer.gd 内部
func _restore_plant_entity(layer_name: String, map_pos: Vector2i):
	var cell_key = layer_name + ":" + str(map_pos)
	var data_ref = dynamic_tile_data.get(cell_key, {})
	
	var plant_res_path = data_ref.get("plant_path")
	if not plant_res_path: return 
	
	var plant_scene = load(plant_res_path).instantiate()
	var layer = find_child(layer_name, true, false)
	layer.add_child(plant_scene)
	plant_scene.global_position = layer.to_global(layer.map_to_local(map_pos))
	
	if plant_scene.has_method("load_state"):
		plant_scene.load_state(
			data_ref.get("stage", 0), 
			data_ref.get("growth_time", 0.0), 
			data_ref.get("time_left", 0.0),
			cell_key,
			data_ref # 传入引用
		)
