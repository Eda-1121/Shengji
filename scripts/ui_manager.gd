# ui_manager.gd - Phase 2 UI管理器
extends CanvasLayer

# UI元素引用
var info_panel: Panel
var level_label: Label
var trump_label: Label

var team1_score_label: Label
var team2_score_label: Label

var turn_panel: Panel
var turn_label: Label

var action_panel: Panel
var play_button: Button
var bury_button: Button

var center_message_panel: Panel
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

func make_panel_style(bg_color: Color, border_color: Color = Color(1, 1, 1, 0.15)) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func style_panel(panel: Panel, bg_color: Color = Color(0.02, 0.10, 0.07, 0.86)):
	panel.add_theme_stylebox_override("panel", make_panel_style(bg_color))

func style_button(button: Button):
	button.add_theme_stylebox_override("normal", make_panel_style(Color(0.12, 0.19, 0.15, 0.95), Color(0.65, 0.75, 0.55, 0.35)))
	button.add_theme_stylebox_override("hover", make_panel_style(Color(0.18, 0.27, 0.20, 0.98), Color(0.78, 0.88, 0.62, 0.55)))
	button.add_theme_stylebox_override("pressed", make_panel_style(Color(0.08, 0.15, 0.11, 1.0), Color(0.9, 0.82, 0.55, 0.7)))
	button.add_theme_stylebox_override("disabled", make_panel_style(Color(0.08, 0.10, 0.09, 0.70), Color(0.35, 0.40, 0.35, 0.25)))

func create_ui():
	# =====================================
	# 左上角统一信息面板
	# =====================================
	info_panel = Panel.new()
	info_panel.position = Vector2(18, 18)
	info_panel.size = Vector2(250, 156)
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_panel(info_panel)
	add_child(info_panel)
	
	var info_container = VBoxContainer.new()
	info_container.position = Vector2(14, 10)
	info_container.size = Vector2(222, 136)
	info_container.add_theme_constant_override("separation", 4)
	info_panel.add_child(info_container)
	
	# 当前级别
	level_label = Label.new()
	level_label.text = "当前级别: 2"
	level_label.add_theme_font_size_override("font_size", 18)
	info_container.add_child(level_label)
	
	# 主花色
	trump_label = Label.new()
	trump_label.text = "主花色: ♠"
	trump_label.add_theme_font_size_override("font_size", 18)
	info_container.add_child(trump_label)
	
	# 分割线
	var separator1 = HSeparator.new()
	separator1.custom_minimum_size = Vector2(222, 2)
	info_container.add_child(separator1)
	
	var score_container = GridContainer.new()
	score_container.columns = 2
	score_container.add_theme_constant_override("h_separation", 28)
	score_container.add_theme_constant_override("v_separation", 4)
	info_container.add_child(score_container)
	
	var team1_title = Label.new()
	team1_title.text = "队伍1"
	team1_title.add_theme_font_size_override("font_size", 16)
	team1_title.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	score_container.add_child(team1_title)

	var team2_title = Label.new()
	team2_title.text = "队伍2"
	team2_title.add_theme_font_size_override("font_size", 16)
	team2_title.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))
	score_container.add_child(team2_title)

	team1_score_label = Label.new()
	team1_score_label.text = "得分 0"
	team1_score_label.add_theme_font_size_override("font_size", 20)
	score_container.add_child(team1_score_label)
	
	team2_score_label = Label.new()
	team2_score_label.text = "得分 0"
	team2_score_label.add_theme_font_size_override("font_size", 20)
	score_container.add_child(team2_score_label)
	
	# =====================================
	# 回合提示标签
	# =====================================
	turn_panel = Panel.new()
	turn_panel.position = Vector2(354, 18)
	turn_panel.size = Vector2(572, 52)
	turn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_panel(turn_panel, Color(0.03, 0.11, 0.09, 0.78))
	add_child(turn_panel)

	turn_label = Label.new()
	turn_label.position = Vector2(12, 7)
	turn_label.size = Vector2(548, 38)
	turn_label.text = "轮到你出牌"
	turn_label.add_theme_font_size_override("font_size", 20)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_panel.add_child(turn_label)
	
	# =====================================
	# 已选牌数标签
	# =====================================
	action_panel = Panel.new()
	action_panel.position = Vector2(560, 666)
	action_panel.size = Vector2(160, 50)
	action_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(action_panel)

	selected_count_label = Label.new()
	selected_count_label.position = Vector2(-20, -34)
	selected_count_label.size = Vector2(200, 28)
	selected_count_label.text = "已选: 0/8"
	selected_count_label.add_theme_font_size_override("font_size", 17)
	selected_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_count_label.visible = false
	action_panel.add_child(selected_count_label)
	
	# =====================================
	# 出牌按钮（居中，在手牌下方）
	# =====================================
	var button_container = Control.new()
	button_container.position = Vector2(10, 1)
	button_container.size = Vector2(140, 48)
	action_panel.add_child(button_container)

	# 出牌按钮
	play_button = Button.new()
	play_button.text = "出牌"
	play_button.position = Vector2.ZERO
	play_button.size = Vector2(140, 48)
	play_button.add_theme_font_size_override("font_size", 20)
	style_button(play_button)
	play_button.pressed.connect(_on_play_button_pressed)
	button_container.add_child(play_button)

	# 埋底按钮（与出牌按钮共用位置）
	bury_button = Button.new()
	bury_button.text = "确认埋底"
	bury_button.position = Vector2.ZERO
	bury_button.size = Vector2(140, 48)
	bury_button.add_theme_font_size_override("font_size", 20)
	style_button(bury_button)
	bury_button.pressed.connect(_on_bury_button_pressed)
	bury_button.visible = false
	button_container.add_child(bury_button)
	
	# =====================================
	# 中央消息标签
	# =====================================
	center_message_panel = Panel.new()
	center_message_panel.position = Vector2(364, 302)
	center_message_panel.size = Vector2(552, 74)
	center_message_panel.visible = false
	center_message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_panel(center_message_panel, Color(0.01, 0.08, 0.06, 0.82))
	add_child(center_message_panel)

	center_message = Label.new()
	center_message.position = Vector2(14, 8)
	center_message.size = Vector2(524, 58)
	center_message.text = ""
	center_message.add_theme_font_size_override("font_size", 28)
	center_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_message_panel.add_child(center_message)
	
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
	"""创建4个玩家的头像框"""
	var avatar_positions = [
		Vector2(570, 632),
		Vector2(24, 300),
		Vector2(570, 84),
		Vector2(1126, 300)
	]
	
	var player_names = ["玩家1", "玩家2", "玩家3", "玩家4"]
	
	for i in range(4):
		var avatar_panel = Panel.new()
		avatar_panel.position = avatar_positions[i]
		avatar_panel.size = Vector2(136, 64)
		avatar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		style_panel(avatar_panel, Color(0.03, 0.11, 0.09, 0.78))

		# 玩家1（索引0）不显示头像框
		if i == 0:
			avatar_panel.visible = false

		add_child(avatar_panel)
		player_avatars.append(avatar_panel)
		
		var name_label = Label.new()
		name_label.position = Vector2(10, 7)
		name_label.size = Vector2(116, 26)
		name_label.text = player_names[i]
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_panel.add_child(name_label)
		player_name_labels.append(name_label)
		
		var status_label = Label.new()
		status_label.position = Vector2(10, 35)
		status_label.size = Vector2(116, 22)
		status_label.text = "队伍%d" % [(i % 2) + 1]
		status_label.add_theme_font_size_override("font_size", 14)
		status_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.35) if i % 2 == 0 else Color(0.95, 0.42, 0.42))
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
	level_label.text = "当前级别: %s" % level_str

func update_trump_suit(suit_symbol: String):
	trump_label.text = "主花色: %s" % suit_symbol

func update_team_scores(team1_score: int, team2_score: int):
	team1_score_label.text = "得分 %d" % team1_score
	team2_score_label.text = "得分 %d" % team2_score

func update_turn_message(message: String):
	turn_label.text = message

func show_center_message(message: String, duration: float = 2.0):
	"""显示中央临时消息"""
	center_message.text = message
	center_message_panel.visible = true
	
	await get_tree().create_timer(duration).timeout
	center_message_panel.visible = false

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
