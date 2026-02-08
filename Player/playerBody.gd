extends CharacterBody2D
@onready var player = $".."
# --- 1. 状态与核心变量 ---
enum State {IDLE, WALK, NAV_WALK, ATTACK, INTERACT}
var current_state = State.IDLE

# 记录角色当前的朝向（默认向下），用于攻击判定
var facing_direction: Vector2 = Vector2.DOWN

@export_group("Movement Settings")
@export var speed: float = 300.0

@export_group("Navigation Settings")
# 【关键修复】设大一点(如40)以避免卡在墙角
@export var nav_path_distance: float = 10.0
@export var nav_target_distance: float = 10.0

@export_group("Combat Settings")
# 攻击扇形角度的一半（45度 = 总共90度扇形）
@export var attack_angle_threshold: float = deg_to_rad(45)

# --- 2. 节点引用 ---
#@onready var animation_player = $AnimatedSprite2D
@onready var sprite = $AnimatedSprite2D # 假设你用的是 AnimatedSprite2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var interaction_area = $Area2D # 交互
@onready var attack_area = $attackArea # 攻击范围检测区域
@onready var inventory = $InventoryManager

func _ready() -> void:
	pass
	# 初始化导航设置
	# 【防卡死关键】判定半径要大于角色碰撞半径
	#nav_agent.path_desired_distance = nav_path_distance
	#nav_agent.target_desired_distance = nav_target_distance
	

func _physics_process(_delta: float) -> void:
	match current_state:
		State.IDLE:
			check_manual_input()
		State.WALK:
			handle_manual_move_logic()
		State.NAV_WALK:
			handle_nav_move_logic()
		State.ATTACK, State.INTERACT:
			pass # 动作执行中，禁止移动

func _input(event: InputEvent) -> void:
	# 攻击或交互状态下，不接受新指令
	if current_state == State.ATTACK or current_state == State.INTERACT:
		return

	# 1. 鼠标右键点击 -> 导航移动
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		set_nav_target(get_global_mouse_position())

	# 2. 交互键 (E)
	if event.is_action_pressed("interaction"):
		perform_interact()
		
	# 3. 攻击键 (Space/J)
	if event.is_action_pressed("attack"):
		perform_attack()

# --- 3. 移动逻辑 ---

# 手动移动 (WASD)
func handle_manual_move_logic():
	var direction := Input.get_vector("walkL", "walkR", "walkU", "walkD")
	velocity = direction * speed
	
	if velocity.length() > 0:
		move_and_slide()
		update_facing_direction(velocity)
	else:
		change_state(State.IDLE)

# 导航移动 (鼠标点击)
func handle_nav_move_logic():
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		change_state(State.IDLE)
		return

	var current_pos = global_position
	var next_path_pos = nav_agent.get_next_path_position()
	
	# 计算方向
	var direction = current_pos.direction_to(next_path_pos)
	velocity = direction * speed
	
	move_and_slide()
	
	# 导航时也要更新朝向
	if velocity.length() > 10:
		update_facing_direction(velocity)
		
	# 打断机制：如果玩家按了键盘，切回手动模式
	if Input.get_vector("walkL", "walkR", "walkU", "walkD") != Vector2.ZERO:
		change_state(State.WALK)

# 仅检查输入不移动 (用于 IDLE 转 WALK)
func check_manual_input():
	if Input.get_vector("walkL", "walkR", "walkU", "walkD").length() > 0:
		change_state(State.WALK)

# 设置导航目标
func set_nav_target(target_pos: Vector2):
	var map := nav_agent.get_navigation_map()

	# 1️⃣ 投影到 NavMesh
	var projected := NavigationServer2D.map_get_closest_point(map, target_pos)

	# 2️⃣ 计算路径
	var path := NavigationServer2D.map_get_path(
		map,
		global_position,
		projected,
		false
	)

	# 3️⃣ 路径不存在，直接放弃
	if path.is_empty():
		print("❌ no valid path")
		return

	# 4️⃣ 终点 = 真正可达的位置
	var final_pos := path[path.size() - 1]

	# 5️⃣ 距离偏差太大，说明目标在障碍深处
	if final_pos.distance_to(target_pos) > 48:
		print("⚠️ target too deep in obstacle")
		return
	print('final_pos',final_pos)
	nav_agent.target_position = final_pos
	change_state(State.NAV_WALK)

# wait:注意一下这里还没绑定->
func _on_navigation_agent_2d_target_reached():
	# 停止移动逻辑
	velocity = Vector2.ZERO 
	
	# 获取 AI 设置的原始目标
	var target_pos = nav_agent.target_position
	# 获取 NPC 当前的物理位置
	var current_pos = global_position
	# 计算欧几里得距离误差
	var distance_error = current_pos.distance_to(target_pos)
	
	print("--- 导航到达报告 ---")
	print("AI 要求去的目标点: ", target_pos)
	print("NPC 实际停下的点: ", current_pos)
	print("物理偏差距离: ", snapped(distance_error, 0.01), " 像素")
	player.chatActionText.append("移动到 {pos} 结束".format({"pos": target_pos}))
	change_state(State.IDLE)
	player.action_step_completed.emit()
# 辅助：更新朝向和Sprite翻转
func update_facing_direction(move_velocity: Vector2):
	if velocity.length() > 0:
		facing_direction = velocity.normalized()
	if move_velocity.x != 0:
		sprite.flip_h = move_velocity.x < 0

# --- 4. 动作逻辑 ---

# 交互逻辑 (改为独立函数，更清晰)
func perform_interact():
	change_state(State.INTERACT)
	getSideStatus() # 执行交互
	# 简单的交互通常只有一瞬间，如果有动画可以加 await
	change_state(State.IDLE)
	#player.action_step_completed.emit()
	#print('perform_interact')

# 攻击逻辑 (带扇形判定)
func perform_attack():
	change_state(State.ATTACK)
	velocity = Vector2.ZERO
	
	#print("执行攻击，朝向: ", facing_direction)
	# animation_player.play("attack")
	
	# 1. 获取范围内所有物体 (Body + Area)
	var bodies = attack_area.get_overlapping_bodies()
	var areas = attack_area.get_overlapping_areas()
	var all_targets = bodies + areas
	
	for target in all_targets:
		# A. 排除自己
		if target == self: continue
		# B. 必须有受击方法
		if not target.has_method("beAttack"): continue
		
		# C. 【扇形判定】计算夹角
		# 1. 计算指向敌人的向量
		var dir_to_target = global_position.direction_to(target.global_position)

		# 2. 【简单写法】使用点积判断
		# dot() 的结果是一个 -1 到 1 之间的数：
		# 1.0  = 完全正前方
		# 0.7  ≈ 前方 45 度范围内 (总共90度扇形)
		# 0.5  = 前方 60 度范围内 (总共120度扇形)
		# 0.0  = 侧面 (90度)
		# -1.0 = 正后方
		if facing_direction.dot(dir_to_target) > 0.7:
			target.beAttack(player, 10)
			#print("命中目标: ", target.name)
			#player.chatActionText.append('命中目标：'+target.name)
		else:
			pass
	
	# 模拟攻击硬直时间
	await get_tree().create_timer(0.3).timeout
	change_state(State.IDLE)
	player.action_step_completed.emit()

# 获取交互对象
func getSideStatus():
	# 1. 获取交互范围内的对象
	var bodies = interaction_area.get_overlapping_bodies()
	var areas = interaction_area.get_overlapping_areas()
	var all_targets = bodies + areas
	
	# 假设你的 inventory 脚本里有一个 slots 数组
	for slot in inventory.slots:
		if slot and slot.item_data and slot.item_data.category == ItemData.ItemCategory.SEED:
			var isSeed = _perform_planting(slot)
			if isSeed == true:
				player.chatActionText.append(GameTime.get_timestamp()+'完成了种植')
				return
			#return # 种下一个就停止，不循环种一排
	
	# 2. 优先执行物体交互（如收获成熟植物、对话等）
	for obj in all_targets:
		if obj == self: continue
		if obj.has_method("interactionFn"):
			obj.interactionFn(self, player)
			return # 交互成功即跳出

## 具体的种植执行函数
func _perform_planting(slot):
	# 1. 尝试获取图层
	var seed_layer = get_tree().get_first_node_in_group("seed_layers")
	
	# 2. 【核心修复】空值保护
	if not seed_layer:
		print("警告：未在当前场景找到 seed_layers 组中的节点，请检查节点是否已加入组！")
		return

	# 3. 正常执行逻辑
	var target_pos = global_position # 建议如果是点击种植，改用 get_global_mouse_position()
	
	# 如果 seed_layer 是 null，下面这行就会报你遇到的那个错
	var local_pos = seed_layer.to_local(target_pos)
	var map_pos = seed_layer.local_to_map(local_pos)
	
	if seed_layer.plant_seed(map_pos, slot.item_data.item_logic):
		slot.amount -= 1
		# 这里注意：如果 inventory 是全局单例，首字母记得大写 Inventory
		if slot.amount <= 0:
			inventory.remove_slot(slot)
		inventory.refresh_ui()
		return true
	return false
# --- 5. 状态机管理 ---
func change_state(new_state):
	if current_state == new_state:
		return
	current_state = new_state
	
	match current_state:
		State.IDLE:
			pass # animation_player.play("idle")
		State.WALK, State.NAV_WALK:
			pass # animation_player.play("walk")
		State.ATTACK:
			pass # animation_player.play("attack")
