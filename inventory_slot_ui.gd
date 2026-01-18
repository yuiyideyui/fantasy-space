extends Button # 或者 TextureRect
class_name InventorySlotUI

var current_product: InventoryProduct

func update_slot(product: InventoryProduct):
	current_product = product
	if product == null:
		$Icon.texture = null
		$AmountLabel.text = ""
	else:
		$Icon.texture = product.item_data.texture
		$AmountLabel.text = str(product.amount) if product.amount > 1 else ""

# 当玩家点击这个格子
func _on_pressed():
	if current_product and current_product.item_data.category == ItemData.ItemCategory.USEABLE:
		# 这里的 stats 需要从 Player 节点获取
		var stats = get_tree().get_first_node_in_group("player").stats
		current_product.item_data.item_logic.use(stats)
		
		# 如果是消耗品，减少数量
		current_product.amount -= 1
		if current_product.amount <= 0:
			# 通知背包管理器移除该物品
			pass
