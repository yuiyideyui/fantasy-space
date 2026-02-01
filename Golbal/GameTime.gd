# GameTime.gd
extends Node
signal tick(game_delta) # 定义信号，传递游戏内流逝的时间（秒）
# 初始设定
const START_YEAR = 153
const TIME_SCALE = 20.0 # 20倍速

# 游戏启动时的系统时间
var os_start_time: float = 0.0
var last_total_seconds: float = 0.0 # 用于计算上一帧到这一帧流逝的游戏时间
func _ready():
	os_start_time = Time.get_unix_time_from_system()
	last_total_seconds = get_game_total_seconds()
func _process(_delta):
	var current_total = get_game_total_seconds()
	var game_delta = current_total - last_total_seconds
	
	# 每帧发送 tick 信号，game_delta 就是这一帧内实际过去的游戏秒数
	if game_delta > 0:
		tick.emit(game_delta)
	
	last_total_seconds = current_total

# 获取游戏内的总秒数
func get_game_total_seconds() -> float:
	var current_os_time = Time.get_unix_time_from_system()
	var elapsed_real_seconds = current_os_time - os_start_time
	return elapsed_real_seconds * TIME_SCALE

# 获取格式化的游戏日期时间
func get_timestamp() -> String:
	var total_seconds = get_game_total_seconds()
	
	# 简单的日期换算（假设每月30天，每年360天，简化AI理解）
	var minute = int(total_seconds / 60) % 60
	var hour = int(total_seconds / 3600) % 24
	var day = (int(total_seconds / 86400) % 30) + 1
	var month = (int(total_seconds / 2592000) % 12) + 1
	var year = START_YEAR + int(total_seconds / 31104000)
	
	return "%d年%02d月%02d日 %02d:%02d" % [year, month, day, hour, minute]

# 获取纯时间戳（用于计算差值）
func get_unix_timestamp() -> float:
	return get_game_total_seconds()

# 设置游戏时间（用于读取存档）
func set_game_time(saved_seconds: float):
	var current_os_time = Time.get_unix_time_from_system()
	# 把 os_start_time 倒推回去，使得 (current - start) * scale == saved_seconds
	# saved_seconds = (current - start) * scale
	# saved_seconds / scale = current - start
	# start = current - (saved_seconds / scale)
	os_start_time = current_os_time - (saved_seconds / TIME_SCALE)
	print("游戏时间已重置为: ", get_timestamp())
