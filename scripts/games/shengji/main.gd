# main.gd - Shengji main scene
extends Node2D

var game_manager: Node
var ui_manager: CanvasLayer
var background: ColorRect

func _ready():
	get_window().title = GameConfig.text("shengji_title")
	if not GameConfig.language_changed.is_connected(_on_language_changed):
		GameConfig.language_changed.connect(_on_language_changed)
	var window_size = get_target_window_size()
	get_window().size = window_size
	get_window().min_size = window_size
	center_window(window_size)
	
	background = ColorRect.new()
	background.color = Color(0.018, 0.055, 0.035)
	background.position = Vector2.ZERO
	background.size = Vector2(window_size)
	background.z_index = -10
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	if not get_viewport().size_changed.is_connected(apply_layout):
		get_viewport().size_changed.connect(apply_layout)

	ui_manager = CanvasLayer.new()
	ui_manager.name = "UIManager"
	var ui_script = load("res://scripts/games/shengji/ui/ui_manager.gd")
	ui_manager.set_script(ui_script)
	add_child(ui_manager)
	await get_tree().process_frame

	game_manager = Node.new()
	game_manager.name = "GameManager"
	var game_script = load("res://scripts/games/shengji/flow/game_manager.gd")
	game_manager.set_script(game_script)
	game_manager.ui_manager = ui_manager
	
	ui_manager.play_cards_pressed.connect(game_manager._on_play_cards_pressed)
	ui_manager.bury_cards_pressed.connect(game_manager._on_bury_cards_pressed)

	if ui_manager.has_node("BiddingUI"):
		var bidding_ui = ui_manager.get_node("BiddingUI")
		bidding_ui.bid_made.connect(game_manager._on_player_bid_made)
		bidding_ui.bid_passed.connect(game_manager._on_player_bid_passed)

	if ui_manager.has_node("GameOverUI"):
		var game_over_ui = ui_manager.get_node("GameOverUI")
		game_over_ui.restart_game.connect(game_manager.restart_game)
		game_over_ui.quit_game.connect(_on_quit_game)

	add_child(game_manager)

	await get_tree().process_frame
	if game_manager.players.size() > 0:
		var player1 = game_manager.players[0]
		if player1.has_signal("selection_changed"):
			player1.selection_changed.connect(_on_player_selection_changed)

func _on_player_selection_changed(count: int):
	"""Handle selection count changes."""
	if game_manager and game_manager.has_method("on_human_selection_changed"):
		game_manager.on_human_selection_changed(count)
	elif ui_manager:
		ui_manager.update_selected_count(count, 8)

func _on_quit_game():
	"""Exit the game."""
	get_tree().quit()

func _on_language_changed(_language: String):
	get_window().title = GameConfig.text("shengji_title")

func apply_layout():
	var viewport_size = get_viewport().get_visible_rect().size
	if background:
		background.size = viewport_size

func get_target_window_size() -> Vector2i:
	var screen = DisplayServer.window_get_current_screen()
	var usable_rect = DisplayServer.screen_get_usable_rect(screen)
	var target = Vector2i(
		max(1280, int(float(usable_rect.size.x) * 0.8)),
		max(720, int(float(usable_rect.size.y) * 0.8))
	)
	return target

func center_window(window_size: Vector2i):
	var screen = DisplayServer.window_get_current_screen()
	var usable_rect = DisplayServer.screen_get_usable_rect(screen)
	get_window().position = usable_rect.position + (usable_rect.size - window_size) / 2

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
