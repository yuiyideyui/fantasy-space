extends Area2D

@export var tree_scene: PackedScene = preload("res://tree_body_1.tscn")
# 建议直接在编辑器里把 NavigationRegion2D 拖到这个变量上
@onready var nav_region: NavigationRegion2D = $"../.."

func _ready() -> void:
	# 如果没在编辑器赋值，尝试自动获取
	if not nav_region:
		nav_region = get_parent() as NavigationRegion2D # 假设它是父节点
	
	for child in get_children():
		if child.has_signal("tree_died"):
			child.tree_died.connect(_on_tree_died)

func _on_tree_died():
	# 补种
	spawn_tree_in_area()
	# 触发异步更新
	update_navigation_safe()

func spawn_tree_in_area():
	var shape_node = $CollisionShape2D
	var shape = shape_node.shape
	
	if shape is RectangleShape2D:
		var size = shape.size
		var random_pos = Vector2(
			randf_range(-size.x / 2.0, size.x / 2.0),
			randf_range(-size.y / 2.0, size.y / 2.0)
		)
		random_pos += shape_node.position
		
		var tree_instance = tree_scene.instantiate()
		tree_instance.tree_died.connect(_on_tree_died)
		
		add_child(tree_instance)
		tree_instance.position = random_pos

func update_navigation_safe():
	# 【关键修复 1】：等待两帧，确保旧节点彻底从物理服务器注销
	await get_tree().process_frame
	await get_tree().process_frame
	
	if nav_region:
		# 【关键修复 2】：重新烘焙
		# 确保你的 NavigationPolygon 里的 Agent Radius 不要设置得过大
		nav_region.bake_navigation_polygon()
		print("导航网格已刷新。")
