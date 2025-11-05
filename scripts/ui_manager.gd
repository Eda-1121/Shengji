# ui_manager.gd - Phase 2 UI管理器
extends CanvasLayer

# UI元素引用
var info_panel: Panel
var level_label: Label
var trump_label: Label

var team1_score_label: Label
var team2_score_label: Label

var turn_label: Label

var play_button: Button
var bury_button: Button

var center_message: Label
var selected_count_label: Label

# 玩家头像框
var player_avatars: Array[Panel] = []
var player_name_labels: Array[Label] = []

# 新增：Phase 2 UI组件
var bidding_ui: Node
var game_over_ui: Node

# 信号
signal play_cards_pressed
signal bury_cards_pressed

func _ready():
	layer = 1
	create_ui()
	create_phase2_ui()

func create_ui():
	# =====================================
	# 左上角统一信息面板（紧凑型横向布局）
	# =====================================
	info_panel = Panel.new()
	info_panel.position = Vector2(10, 10)
	info_panel.size = Vector2(280, 100)  # 调整为更紧凑的大小
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info_panel)

	var info_container = VBoxContainer.new()
	info_container.position = Vector2(10, 8)
	info_container.add_theme_constant_override("separation", 8)
	info_panel.add_child(info_container)

	# 第一行：当前级别 + 主花色（横向排列）
	var level_trump_container = HBoxContainer.new()
	level_trump_container.add_theme_constant_override("separation", 15)
	info_container.add_child(level_trump_container)

	level_label = Label.new()
	level_label.text = "级别: 2"
	level_label.add_theme_font_size_override("font_size", 20)
	level_label.custom_minimum_size = Vector2(75, 0)  # 固定宽度，确保2位数时不影响布局
	level_trump_container.add_child(level_label)

	trump_label = Label.new()
	trump_label.text = "主: ♠"
	trump_label.add_theme_font_size_override("font_size", 20)
	level_trump_container.add_child(trump_label)

	# 分割线
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(260, 2)
	info_container.add_child(separator)

	# 第二行：队伍得分（横向排列）
	var teams_container = HBoxContainer.new()
	teams_container.add_theme_constant_override("separation", 20)
	info_container.add_child(teams_container)

	# 队伍1
	var team1_container = HBoxContainer.new()
	team1_container.add_theme_constant_override("separation", 5)
	teams_container.add_child(team1_container)

	var team1_title = Label.new()
	team1_title.text = "队1:"
	team1_title.add_theme_font_size_override("font_size", 18)
	team1_title.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	team1_container.add_child(team1_title)

	team1_score_label = Label.new()
	team1_score_label.text = "0"
	team1_score_label.add_theme_font_size_override("font_size", 22)
	team1_score_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	team1_score_label.custom_minimum_size = Vector2(40, 0)  # 固定宽度，避免分数变化时布局跳动
	team1_container.add_child(team1_score_label)

	# 队伍2
	var team2_container = HBoxContainer.new()
	team2_container.add_theme_constant_override("separation", 5)
	teams_container.add_child(team2_container)

	var team2_title = Label.new()
	team2_title.text = "队2:"
	team2_title.add_theme_font_size_override("font_size", 18)
	team2_title.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	team2_container.add_child(team2_title)

	team2_score_label = Label.new()
	team2_score_label.text = "0"
	team2_score_label.add_theme_font_size_override("font_size", 22)
	team2_score_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	team2_score_label.custom_minimum_size = Vector2(40, 0)  # 固定宽度
	team2_container.add_child(team2_score_label)
	
	# =====================================
	# 回合提示标签（左上角，info_panel下方）
	# =====================================
	turn_label = Label.new()
	turn_label.position = Vector2(10, 120)  # info_panel下方（y=10+100+10）
	turn_label.size = Vector2(280, 35)  # 与info_panel同宽
	turn_label.text = "轮到你出牌"
	turn_label.add_theme_font_size_override("font_size", 20)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT  # 左对齐
	turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(turn_label)
	
	# =====================================
	# 已选牌数标签
	# =====================================
	selected_count_label = Label.new()
	selected_count_label.position = Vector2(540, 60)
	selected_count_label.size = Vector2(200, 40)
	selected_count_label.text = "已选: 0/8"
	selected_count_label.add_theme_font_size_override("font_size", 20)
	selected_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_count_label.visible = false
	add_child(selected_count_label)
	
	# =====================================
	# 出牌按钮（居中，在手牌上方，出牌区下方）
	# =====================================
	var button_container = HBoxContainer.new()
	# 居中显示：屏幕宽度1280，按钮宽120，居中位置 (1280-120)/2 = 580
	# 按钮位置调整到y=530，在手牌上方，出牌区(y=560)下方
	button_container.position = Vector2(580, 530)
	button_container.add_theme_constant_override("separation", 20)
	add_child(button_container)

	# 出牌按钮
	play_button = Button.new()
	play_button.text = "出牌"
	play_button.custom_minimum_size = Vector2(120, 50)
	play_button.add_theme_font_size_override("font_size", 24)
	play_button.pressed.connect(_on_play_button_pressed)
	button_container.add_child(play_button)

	# 埋底按钮（与出牌按钮共用位置）
	bury_button = Button.new()
	bury_button.text = "确认埋底"
	bury_button.custom_minimum_size = Vector2(140, 50)
	bury_button.add_theme_font_size_override("font_size", 24)
	bury_button.pressed.connect(_on_bury_button_pressed)
	bury_button.visible = false
	# 埋底按钮独立定位，居中显示
	bury_button.position = Vector2(570, 530)  # 与出牌按钮相同高度
	add_child(bury_button)
	
	# =====================================
	# 中央消息标签
	# =====================================
	center_message = Label.new()
	center_message.position = Vector2(340, 350)
	center_message.size = Vector2(600, 80)
	center_message.text = ""
	center_message.add_theme_font_size_override("font_size", 32)
	center_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_message.visible = false
	add_child(center_message)
	
	# =====================================
	# 玩家头像框
	# =====================================
	create_player_avatars()

func create_phase2_ui():
	"""创建Phase 2的UI组件"""
	# 叫牌UI
	var BiddingUIScript = load("res://scripts/bidding_ui.gd")
	if BiddingUIScript:
		bidding_ui = Control.new()
		bidding_ui.name = "BiddingUI"
		bidding_ui.set_script(BiddingUIScript)
		add_child(bidding_ui)

	# 游戏结束UI
	var GameOverUIScript = load("res://scripts/game_over_ui.gd")
	if GameOverUIScript:
		game_over_ui = Control.new()
		game_over_ui.name = "GameOverUI"
		game_over_ui.set_script(GameOverUIScript)
		add_child(game_over_ui)

func create_player_avatars():
	"""创建4个玩家的头像框 - 与玩家位置对应"""
	var avatar_positions = [
		Vector2(540, 680),   # 玩家1（不显示）
		Vector2(10, 320),    # 玩家2 - 左侧垂直居中
		Vector2(540, 10),    # 玩家3 - 上方水平居中
		Vector2(1150, 320)   # 玩家4 - 右侧垂直居中
	]
	
	var player_names = ["玩家1", "玩家2", "玩家3", "玩家4"]
	
	for i in range(4):
		var avatar_panel = Panel.new()
		avatar_panel.position = avatar_positions[i]
		avatar_panel.size = Vector2(120, 80)
		avatar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# 玩家1（索引0）不显示头像框
		if i == 0:
			avatar_panel.visible = false

		add_child(avatar_panel)
		player_avatars.append(avatar_panel)
		
		var name_label = Label.new()
		name_label.position = Vector2(10, 10)
		name_label.size = Vector2(100, 30)
		name_label.text = player_names[i]
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_panel.add_child(name_label)
		player_name_labels.append(name_label)
		
		var status_label = Label.new()
		status_label.position = Vector2(10, 45)
		status_label.size = Vector2(100, 25)
		status_label.text = ""
		status_label.add_theme_font_size_override("font_size", 16)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_panel.add_child(status_label)

# =====================================
# 按钮回调
# =====================================

func _on_play_button_pressed():
	play_cards_pressed.emit()

func _on_bury_button_pressed():
	bury_cards_pressed.emit()

# =====================================
# 更新UI的方法
# =====================================

func update_level(level: int):
	var level_names = {
		2: "2", 3: "3", 4: "4", 5: "5", 6: "6", 7: "7", 8: "8",
		9: "9", 10: "10", 11: "J", 12: "Q", 13: "K", 14: "A"
	}
	var level_str = level_names.get(level, str(level))
	level_label.text = "级别: %s" % level_str

func update_trump_suit(suit_symbol: String):
	trump_label.text = "主: %s" % suit_symbol

func update_team_scores(team1_score: int, team2_score: int):
	team1_score_label.text = "%d" % team1_score
	team2_score_label.text = "%d" % team2_score

func update_turn_message(message: String):
	turn_label.text = message

func show_center_message(message: String, duration: float = 2.0):
	"""显示中央临时消息"""
	center_message.text = message
	center_message.visible = true
	
	await get_tree().create_timer(duration).timeout
	center_message.visible = false

func set_buttons_enabled(enabled: bool):
	"""启用/禁用按钮"""
	play_button.disabled = not enabled

func highlight_current_player(player_id: int):
	"""高亮当前出牌的玩家"""
	for i in range(player_avatars.size()):
		if i == player_id:
			player_avatars[i].modulate = Color(1.2, 1.2, 1.0)
		else:
			player_avatars[i].modulate = Color.WHITE

# =====================================
# 埋底相关
# =====================================

func show_bury_button(visible: bool):
	"""显示/隐藏埋底按钮"""
	bury_button.visible = visible
	selected_count_label.visible = visible

	play_button.visible = not visible

func set_bury_button_enabled(enabled: bool):
	"""启用/禁用埋底按钮"""
	bury_button.disabled = not enabled

func update_selected_count(count: int, max_count: int = 8):
	"""更新已选牌数显示"""
	selected_count_label.text = "已选: %d/%d" % [count, max_count]
	
	if count == max_count:
		set_bury_button_enabled(true)
		selected_count_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	else:
		set_bury_button_enabled(false)
		if count > max_count:
			selected_count_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
		else:
			selected_count_label.add_theme_color_override("font_color", Color.WHITE)
