extends Control

@onready var inventory_manager: InventoryManager = $"../../playerBody/InventoryManager"
@onready var slot_scene: PackedScene = preload("res://shopPg.tscn")
@onready var grid = $ScrollContainer/PanelContainer/GridContainer

func _ready():
	if inventory_manager:
		# 确保连接了信号，当背包数据变化时自动刷新
		if not inventory_manager.inventory_changed.is_connected(refresh):
			inventory_manager.inventory_changed.connect(refresh)
		refresh()

## 核心刷新函数：带合并逻辑
func refresh():
	if not grid: return
	
	# 1. 清空当前所有 UI 格子
	for child in grid.get_children():
		child.queue_free()
	
	# 2. 使用字典合并相同物品
	# key 是物品的资源路径（唯一），value 是临时生成的 InventoryProduct
	var combined_items = {}

	for product in inventory_manager.slots:
		if product and product.item_data:
			var path = product.item_data.resource_path # 使用路径作为唯一标识
			
			if combined_items.has(path):
				# 累加数量
				combined_items[path].amount += product.amount
			else:
				# 创建一个 UI 专用的临时副本，防止修改背包原始数据
				var temp = InventoryProduct.new()
				temp.item_data = product.item_data
				temp.amount = product.amount
				combined_items[path] = temp

	# 3. 渲染合并后的物品
	for path in combined_items:
		var display_product = combined_items[path]
		var new_slot = slot_scene.instantiate()
		
		# 必须先添加进场景树，再调用更新函数
		grid.add_child(new_slot)
		
		if new_slot.has_method("update_slot"):
			new_slot.update_slot(display_product)
		
		# 连接点击信号
		if new_slot.has_signal("slot_pressed"):
			new_slot.slot_pressed.connect(_on_slot_clicked)

## 点击后的逻辑处理
func _on_slot_clicked(product: InventoryProduct):
	if product and product.item_data:
		print("选中的物品名称: ", product.item_data.item_name)
		print("当前合并后的显示总数: ", product.amount)
		# 在这里写后续逻辑，比如：通知玩家装备该种子
