# seed_layer.gd
extends TileMapLayer

# 建议在主控脚本 mapLayer.gd 中把自身实例传给子层，或者这样寻找：
@onready var map_manager = _find_map_manager()

func _find_map_manager():
	var p = get_parent()
	while p != null:
		if "dynamic_tile_data" in p: return p
		p = p.get_parent()
	return null

func plant_seed(map_pos: Vector2i, seed_data: SeedItem) -> bool:
	if not map_manager: return false
	
	var tile_data = get_cell_tile_data(map_pos)
	if tile_data == null: return false
	
	var cell_key = name + ":" + str(map_pos)
	if map_manager.dynamic_tile_data.get(cell_key, {}).get("Seeded", false):
		return false
		
	var plant_scene = seed_data.plant_visual.instantiate()
	add_child(plant_scene)
	plant_scene.global_position = to_global(map_to_local(map_pos))
	
	if not map_manager.dynamic_tile_data.has(cell_key):
		map_manager.dynamic_tile_data[cell_key] = {}
	
	var data_ref = map_manager.dynamic_tile_data[cell_key]
	data_ref["Seeded"] = true
	data_ref["plant_path"] = seed_data.plant_visual.resource_path
	
	if plant_scene.has_method("start_growth"):
		# 传入 key 和 字典引用
		plant_scene.start_growth(seed_data.growth_time, cell_key, data_ref)
		
	return true
