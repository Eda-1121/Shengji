# main.gd - Phase 2 主场景脚本
extends Node2D

var game_manager: Node
var ui_manager: CanvasLayer

func _ready():
	# 设置窗口
	get_window().title = "升级 - 拖拉机 (Phase 2)"
	get_window().size = Vector2i(1280, 720)
	
	# 添加全屏绿色背景
	var background = ColorRect.new()
	background.color = Color(0.05, 0.37, 0.14)
	background.position = Vector2.ZERO
	background.size = Vector2(1280, 720)
	background.z_index = -10
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# 创建UI管理器
	ui_manager = CanvasLayer.new()
	ui_manager.name = "UIManager"
	var ui_script = load("res://scripts/ui_manager.gd")
	ui_manager.set_script(ui_script)
	add_child(ui_manager)

	# 创建游戏管理器
	game_manager = Node.new()
	game_manager.name = "GameManager"
	var game_script = load("res://scripts/game_manager.gd")
	game_manager.set_script(game_script)
	add_child(game_manager)
	
	# 连接基础UI信号
	ui_manager.play_cards_pressed.connect(game_manager._on_play_cards_pressed)
	ui_manager.bury_cards_pressed.connect(game_manager._on_bury_cards_pressed)
	game_manager.ui_manager = ui_manager
	
	# 等待UI组件创建完成
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 连接叫牌UI信号
	if ui_manager.has_node("BiddingUI"):
		var bidding_ui = ui_manager.get_node("BiddingUI")
		bidding_ui.bid_made.connect(game_manager._on_player_bid_made)
		bidding_ui.bid_passed.connect(game_manager._on_player_bid_passed)

	# 连接游戏结束UI信号
	if ui_manager.has_node("GameOverUI"):
		var game_over_ui = ui_manager.get_node("GameOverUI")
		game_over_ui.restart_game.connect(game_manager.restart_game)
		game_over_ui.quit_game.connect(_on_quit_game)

	# 连接玩家1的选牌信号
	await get_tree().process_frame
	if game_manager.players.size() > 0:
		var player1 = game_manager.players[0]
		if player1.has_signal("selection_changed"):
			player1.selection_changed.connect(_on_player_selection_changed)

func _on_player_selection_changed(count: int):
	"""当玩家选牌数量变化时"""
	if ui_manager:
		ui_manager.update_selected_count(count, 8)

func _on_quit_game():
	"""退出游戏"""
	get_tree().quit()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
