extends Area2D

# 只要你的 Area2D 下有 CollisionShape2D，这个函数就会生效
func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			print("点中 Area2D 了！")
