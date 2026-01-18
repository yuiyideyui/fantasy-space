extends Area2D

@export var tree_scene: PackedScene = preload("res://tree_body_1.tscn")

func _ready() -> void:
	# 1. 找到你手动摆放在场景里的那三棵树
	# 假设你在编辑器里给它们起名叫 treeBody1, treeBody2, treeBody3
	# 或者是直接获取 Area2D 下所有的子节点
	for child in get_children():
		# 检查这个子节点是不是树（通过判断是否有 tree_died 信号）
		if child.has_signal("tree_died"):
			# 为这些已经存在的树连接信号
			child.tree_died.connect(_on_tree_died)
			print("已连接预设树木的信号: ", child.name)

func _on_tree_died():
	print("一棵预设树木倒下了，开始在区域内随机补种...")
	# 只有当树死了，才触发随机生成逻辑
	spawn_tree_in_area()

func spawn_tree_in_area():
	var shape = $CollisionShape2D.shape
	if shape is RectangleShape2D:
		var size = shape.size 
		var random_pos = Vector2(
			randf_range(-size.x / 2, size.y / 2), 
			randf_range(-size.y / 2, size.y / 2)
		)
		
		var tree_instance = tree_scene.instantiate()
		# 补种出来的树也要连上信号，这样它们被砍了还能继续补种
		tree_instance.tree_died.connect(_on_tree_died)
		
		tree_instance.position = random_pos
		add_child(tree_instance)
