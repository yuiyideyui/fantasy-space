extends PanelContainer

# 信号：点击时把物品数据传出去
signal slot_pressed(product)

var current_product: InventoryProduct = null

# 预先获取节点，使用 get_node 防止实例化瞬间的 null 报错
@onready var icon_rect = get_node_or_null("Icon")
@onready var count_label = get_node_or_null("Count")

## 供外部调用的刷新方法
func update_slot(product: InventoryProduct):
	current_product = product
	
	# 如果没有节点，说明场景树路径写错了，打印提示
	if not icon_rect:
		print("错误：shopPg 内部找不到名为 Icon 的节点")
		return

	if product and product.item_data:
		icon_rect.texture = product.item_data.texture # 使用你定义的 texture 变量名
		if count_label:
			count_label.text = str(product.amount)
		self.visible = true
	else:
		# 如果没有物品，可以选择隐藏格子或者显示为空
		icon_rect.texture = null
		if count_label: count_label.text = ""
		# self.visible = false # 如果不想显示空格子就取消注释

## 处理鼠标点击
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# 发出信号，通知 UI 层
			slot_pressed.emit(current_product)
