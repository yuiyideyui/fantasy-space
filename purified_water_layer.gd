extends TileMapLayer

@onready var water = load("res://resource/纯净水.tres")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
## 参数 source 代表是谁触发了交互（通常是玩家）
func interactionFn(source: Node2D):
	print(source.name, " 交互了 ", name)
	
	# 逻辑示例：如果是掉落物，就加进玩家背包
	if source.has_node("InventoryManager"):
		var inv = source.get_node("InventoryManager")
		inv.add_item(water, 1)
		# 交互完销毁自己
		#queue_free()
