extends TileMapLayer

func plant_seed(map_pos: Vector2i, seed_data: SeedItem) -> bool:
	# 1. 获取目标格子的数据
	var tile_data = get_cell_tile_data(map_pos)
	
	# 2. 判断：必须有瓦片且 CustomData "Seeded" 为 false 才能种
	if tile_data == null: 
		print("这里不能种地")
		return false
		
	if tile_data.get_custom_data("Seeded") == true:
		print("这里已经有种子了")
		return false
		
	# 3. 实例化植物
	var plant_scene = seed_data.plant_visual.instantiate()
	add_child(plant_scene)
	
	# 坐标对齐
	plant_scene.global_position = to_global(map_to_local(map_pos))
	
	# 4. 修改状态：标记此格已种植
	tile_data.set_custom_data("Seeded", true)
	
	# 5. 绑定自动清理：收获或销毁时，将 Seeded 设回 false
	plant_scene.tree_exiting.connect(func():
		var d = get_cell_tile_data(map_pos)
		if d: d.set_custom_data("Seeded", false)
	)
	
	# 6. 开启生长
	if plant_scene.has_method("start_growth"):
		plant_scene.start_growth(seed_data.growth_time)
		
	return true
