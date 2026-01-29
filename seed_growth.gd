extends Area2D

enum GrowthStage {SEED, SPROUT, MATURE}
var current_stage = GrowthStage.SEED

@onready var sprite = $AnimatedSprite2D
@onready var timer = $Timer
@export var water_boost_sec: float = 2.0 

var stage_time: float = 0.0
var total_growth_time: float = 0.0

# 核心变量：保存引用和坐标 Key
var my_cell_key: String = ""
var my_data_ref: Dictionary = {}

func _ready():
	sprite.frame = current_stage
	sprite.stop()
	timer.one_shot = true 
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

# --- 严谨同步：利用 _process 确保 time_left 随时是最新值 ---
func _process(_delta: float) -> void:
	if not my_data_ref.is_empty() and current_stage < GrowthStage.MATURE:
		my_data_ref["time_left"] = timer.time_left
		my_data_ref["stage"] = current_stage

func load_state(stage: int, total_time: float, time_left: float, cell_key: String, data_ref: Dictionary):
	my_cell_key = cell_key
	my_data_ref = data_ref
	total_growth_time = total_time
	stage_time = total_time / 3.0
	
	current_stage = stage
	sprite.frame = current_stage
	
	if current_stage < GrowthStage.MATURE:
		timer.start(time_left if time_left > 0 else stage_time)

func start_growth(total_time: float, cell_key: String, data_ref: Dictionary):
	my_cell_key = cell_key
	my_data_ref = data_ref
	total_growth_time = total_time
	stage_time = total_time / 3.0
	
	timer.start(stage_time)
	# 初始同步
	my_data_ref["growth_time"] = total_time
	my_data_ref["stage"] = current_stage

func _on_timer_timeout():
	if current_stage < GrowthStage.MATURE:
		current_stage += 1
		sprite.frame = current_stage
		if current_stage < GrowthStage.MATURE:
			timer.start(stage_time)
		# 状态变更同步
		my_data_ref["stage"] = current_stage

func apply_water_boost():
	if current_stage == GrowthStage.MATURE: return
	if not timer.is_stopped():
		var new_time = timer.time_left - water_boost_sec
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.AQUA, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		
		if new_time <= 0:
			timer.stop()
			_on_timer_timeout() 
		else:
			timer.start(new_time)
			my_data_ref["time_left"] = timer.time_left

func harvest(last_interacted_source, _player):
	if last_interacted_source:
		var inv = last_interacted_source.get_node_or_null("InventoryManager")
		if inv:
			inv.add_item(preload("res://resource/胡萝卜.tres"), 1)
	queue_free()
func interactionFn(source, _player):
	if current_stage == GrowthStage.MATURE:
		harvest(source, _player)
	else:
		var inv = source.get_node_or_null("InventoryManager")
		if inv:
			var water_slot = null
			for slot in inv.slots:
				if slot and slot.item_data and slot.item_data.name == "纯净水":
					water_slot = slot
					break
			if water_slot:
				inv.remove_item_quantity(water_slot, 1)
				apply_water_boost()
