extends Node2D
class_name InventoryManager
@onready var player = $"../.."
## 背包变更信号，用于通知 UI 刷新
signal inventory_changed

@export var max_slots: int = 20
@export var slots: Array[InventoryProduct] = []

## 默认初始物品配置
@export var default_items: Array[ItemData] = []
@export var default_quantities: Array[int] = []

func _ready() -> void:
	if slots.size() == 0:
		slots.resize(max_slots)
	
	if _is_inventory_empty():
		_load_default_items()

func _is_inventory_empty() -> bool:
	for s in slots:
		if s != null: return false
	return true

func _load_default_items():
	for i in range(default_items.size()):
		var qty = default_quantities[i] if i < default_quantities.size() else 1
		add_item(default_items[i], qty)
	refresh_ui() # 使用统一的刷新函数

## 添加物品逻辑
func add_item(new_item: ItemData, quantity: int = 1):
	player.chatActionText.append('获得：' + new_item.name + 'x' + str(quantity))
	if new_item.category == ItemData.ItemCategory.MATERIAL or new_item.category == ItemData.ItemCategory.SEED:
		for p in slots:
			if p and p.item_data.id == new_item.id:
				p.amount += quantity
				
				refresh_ui()
				return
	
	for i in range(slots.size()):
		if slots[i] == null:
			var new_product = InventoryProduct.new()
			new_product.item_data = new_item
			new_product.amount = quantity
			slots[i] = new_product
			refresh_ui()
			return

## 获取第一个种子物品
func get_first_seed_product() -> InventoryProduct:
	for p in slots:
		if p and p.item_data and p.item_data.category == ItemData.ItemCategory.SEED:
			if p.amount > 0: return p
	return null

## 消耗/移除指定数量
func remove_item_quantity(product: InventoryProduct, amount: int = 1):
	var index = slots.find(product)
	if index != -1:
		player.chatActionText.append('消耗：' + product.item_data.name + 'x' + str(product.amount))
		player.action_step_completed.emit()
		product.amount -= amount
		if product.amount <= 0:
			slots[index] = null
		refresh_ui()

# --- 新增/完善的方法 ---

## 刷新 UI 的统一接口
## 玩家脚本调用 inventory.refresh_ui() 时会触发信号
func refresh_ui():
	inventory_changed.emit()
	print("背包数据已更新，发送刷新信号")

## 移除整个格子 (对应你玩家脚本中的调用)
func remove_slot(product: InventoryProduct):
	var index = slots.find(product)
	if index != -1:
		slots[index] = null
		refresh_ui()
