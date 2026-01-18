extends Resource
class_name SeedItem

@export_group("种植设置")
## 生长总时长
@export var growth_time: float = 60.0    
## 土地上长出来的样子 (场景文件)
@export var plant_visual: PackedScene    
## 成熟后捡起来得到的 ItemData
#@export var harvested_item: Resource     

# 可以在这里写一个检查是否可以种植的函数
func can_plant(soil_type: String) -> bool:
	return true
