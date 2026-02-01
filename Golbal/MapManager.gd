## MapScanner.gd
extends Node2D
## 导出全场景数据
func get_full_world_state_json(extra_info: Dictionary = {}) -> String:
	var world_root = get_tree().current_scene
	
	var data = {
		"timestamp": Time.get_unix_time_from_system(),
		"world_name": world_root.name,
		"map_metadata": _get_map_metadata(),
		"entities": _scan_all_detectables()
	}
	
	if not extra_info.is_empty():
		data["player_status"] = extra_info
	
	return JSON.stringify(data, "\t")

## 获取地图元数据：大小与导航区域
func _get_map_metadata() -> Dictionary:
	var meta = {
		"bounds": [0, 0, 0, 0],
		"nav_polygons": []
	}
	
	var total_rect = Rect2()
	# 改进：如果 layerMap 组为空，尝试搜索场景中所有的 TileMapLayer
	var layers = get_tree().get_nodes_in_group("layerMap")
	if layers.is_empty():
		for child in get_tree().current_scene.get_children():
			if child is TileMapLayer: layers.append(child)
	
	for layer in layers:
		if layer is TileMapLayer:
			var rect = _get_node_span_rect(layer)
			if total_rect == Rect2(): total_rect = rect
			else: total_rect = total_rect.merge(rect)
	
	meta["bounds"] = [
		round(total_rect.position.x), round(total_rect.position.y),
		round(total_rect.size.x), round(total_rect.size.y)
	]
	
	var nav_node = get_tree().current_scene.find_child("*NavigationRegion2D*", true, false)
	if nav_node and nav_node is NavigationRegion2D:
		var poly = nav_node.navigation_polygon
		if poly:
			for i in range(poly.get_outline_count()):
				var outline = poly.get_outline(i)
				var points = []
				for p in outline: points.append([round(p.x), round(p.y)])
				meta["nav_polygons"].append(points)
				
	return meta

## 内部扫描逻辑
func _scan_all_detectables() -> Array:
	var entities = []
	var targets = get_tree().get_nodes_in_group("detectable")
	var world_root = get_tree().current_scene
	
	for node in targets:
		if not node is Node2D: continue
		
		var global_rect = _get_node_span_rect(node)
		var local_top_left = world_root.to_local(global_rect.position)
		
		var info = {
			"id": _get_stable_id(node),
			"name": node.name,
			"type": _determine_type(node),
			"rect": [
				round(local_top_left.x), round(local_top_left.y), 
				round(global_rect.size.x), round(global_rect.size.y)
			],
			"center": [
				round(local_top_left.x + global_rect.size.x / 2.0),
				round(local_top_left.y + global_rect.size.y / 2.0)
			],
			"layer": node.z_index,
			"is_obstacle": node.is_in_group("obstacles")
		}
		if node is TileMapLayer:
			var tile_set = node.tile_set
			if tile_set:
				# 检查 TileSet 是否配置了物理层
				info["has_physics_layer"] = tile_set.get_physics_layers_count() > 0
				if info["has_physics_layer"]:
					info["is_obstacle"] = true # 如果有物理层，通常 AI 应该视为不可通行或需谨慎
					info["describe"] = "这是物理障碍区域: " + node.name
		info["can_interact"] = node.has_method("interactionFn")
		# 标记是否可以被攻击
		info["can_attack"] = node.has_method("beAttack")
		
		_append_dynamic_stats(node, info)
		entities.append(info)
	
	return entities

## 计算物体的占据范围
func _get_node_span_rect(node: Node2D) -> Rect2:
	if node is TileMapLayer:
		var used_rect = node.get_used_rect()
		if used_rect.size == Vector2i.ZERO:
			return Rect2(node.global_position, Vector2.ZERO)
		
		var cell_size = node.tile_set.tile_size
		var pos_px = node.map_to_local(used_rect.position) - (Vector2(cell_size) / 2.0)
		var size_px = Vector2(used_rect.size) * Vector2(cell_size)
		return Rect2(node.to_global(pos_px), size_px)
	
	for child in node.get_children():
		if child is Sprite2D and child.texture:
			var s = child.texture.get_size() * child.global_scale
			return Rect2(node.global_position - s/2.0, s)
		if child is CollisionShape2D and child.shape:
			if child.shape is RectangleShape2D:
				var s = child.shape.size * child.global_scale
				return Rect2(child.global_position - s/2.0, s)
	
	return Rect2(node.global_position, Vector2(1, 1))

## 辅助函数：ID/类型获取保持不变...
func _get_stable_id(node: Node) -> String:
	if node.has_meta("uid"): return str(node.get_meta("uid"))
	return str(node.get_instance_id())

func _determine_type(node: Node) -> String:
	if node.has_meta("type"): return str(node.get_meta("type"))
	var script = node.get_script()
	if script: return script.resource_path.get_file().get_basename()
	return node.get_class()

## 【核心改进】：处理 beAttack 逻辑和描述
func _append_dynamic_stats(node: Node, info: Dictionary):
	# 1. 描述抓取
	if node.has_meta("describe"):
		info["describe"] = str(node.get_meta("describe"))
	elif "describe" in node:
		info["describe"] = str(node.describe)
	
	# 2. 血量抓取核心逻辑
	# 如果是 beAttack 组成员，或者节点本身就有 hp 属性
	if node.is_in_group("beAttack") or "hp" in node:
		# 优先尝试从节点脚本获取 hp，如果没有则默认为 100（防止报错）
		info["hp"] = node.hp if "hp" in node else 100
		
		# 如果有最大血量，计算血量百分比给 AI 参考
		if "max_hp" in node:
			info["hp_max"] = node.max_hp
			var ratio = float(info["hp"]) / float(node.max_hp)
			info["hp_status"] = "健康" if ratio > 0.6 else ("受损" if ratio > 0.3 else "垂危")
	
	# 3. 特殊逻辑：农作物/层
	if "growth_stage" in node:
		info["growth"] = node.growth_stage 
	
	if node is TileMapLayer and not info.has("describe"):
		info["describe"] = "这是名为 " + node.name + " 的瓦片层。"

	if node.has_meta("interaction_hint"):
		info["hint"] = node.get_meta("interaction_hint")
	# 4. 【新增】：农作物生长逻辑 (seedGrow 组)
	
	# --- 针对 seedGrow 农作物逻辑的精准匹配 ---
	if node.is_in_group("seedGrow"):
		info["is_crop"] = true
		print('node',node)
		# 1. 阶段解析：将枚举索引转换为 AI 易懂的文字
		if "current_stage" in node:
			var stage_map = {0: "种子期", 1: "幼苗期", 2: "成熟期"}
			info["stage_index"] = node.current_stage
			info["stage_name"] = stage_map.get(node.current_stage, "生长中")
			
		# 2. 时间解析：获取 Timer 的剩余时间
		if "timer" in node and node.timer is Timer:
			if not node.timer.is_stopped():
				info["time_left_sec"] = round(node.timer.time_left)
			else:
				info["time_left_sec"] = 0
		
		# 3. 交互逻辑：告诉 AI 现在的交互动作意味着什么
		if node.has_method("interactionFn"):
			if info.get("stage_index") == 2: # GrowthStage.MATURE
				info["next_action_hint"] = "已成熟，可以收获"
				info["can_harvest"] = true
			else:
				info["next_action_hint"] = "未成熟，可使用纯净水加速"
				info["can_water"] = true

		# 4. 动态描述更新 (方便 AI 理解上下文)
		var desc_text = " [阶段: %s]" % info.get("stage_name", "未知")
		if info.has("time_left_sec") and info["time_left_sec"] > 0:
			desc_text += " (预计 %s秒后进入下阶段)" % info["time_left_sec"]
		
		if info.has("describe"):
			info["describe"] += desc_text
		else:
			info["describe"] = "一株" + node.name + desc_text
## 保存数据
func save_scene_data_to_local(extra_info: Dictionary = {}):
	var json_string = get_full_world_state_json(extra_info)
	var save_path = "user://map_dump.json" 
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("--- 场景全量数据导出完成 ---")
		return json_string
