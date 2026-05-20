# game_over_ui.gd - 游戏结束界面
extends Control
class_name GameOverUI

signal restart_game
signal quit_game
signal go_to_title

var panel: Panel
var title_label: Label
var winner_label: Label
var stats_label: Label
var restart_button: Button
var quit_button: Button
var title_button: Button

func _ready():
	create_game_over_panel()
	visible = false

func create_game_over_panel():
	"""创建游戏结束面板"""
	# 半透明背景
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.position = Vector2.ZERO
	background.size = Vector2(1280, 720)
	add_child(background)
	
	# 主面板
	panel = Panel.new()
	panel.position = Vector2(340, 180)
	panel.size = Vector2(600, 360)
	add_child(panel)
	
	# 标题
	title_label = Label.new()
	title_label.position = Vector2(50, 30)
	title_label.size = Vector2(500, 50)
	title_label.text = "游戏结束"
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title_label)
	
	# 胜利者信息
	winner_label = Label.new()
	winner_label.position = Vector2(50, 100)
	winner_label.size = Vector2(500, 60)
	winner_label.text = "队伍1 获胜!"
	winner_label.add_theme_font_size_override("font_size", 32)
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	panel.add_child(winner_label)
	
	# 统计信息
	stats_label = Label.new()
	stats_label.position = Vector2(50, 170)
	stats_label.size = Vector2(500, 80)
	stats_label.text = "队伍1: 等级A\n队伍2: 等级10"
	stats_label.add_theme_font_size_override("font_size", 22)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(stats_label)
	
	# 按钮容器
	var button_container = HBoxContainer.new()
	button_container.position = Vector2(60, 280)
	button_container.add_theme_constant_override("separation", 20)
	panel.add_child(button_container)
	
	# 重新开始按钮
	restart_button = Button.new()
	restart_button.text = "再来一局"
	restart_button.custom_minimum_size = Vector2(140, 50)
	restart_button.add_theme_font_size_override("font_size", 24)
	restart_button.pressed.connect(_on_restart_pressed)
	button_container.add_child(restart_button)
	
	# タイトルへ戻るボタン
	title_button = Button.new()
	title_button.text = "タイトルへ"
	title_button.custom_minimum_size = Vector2(140, 50)
	title_button.add_theme_font_size_override("font_size", 24)
	title_button.pressed.connect(_on_title_pressed)
	button_container.add_child(title_button)

	# 退出按钮
	quit_button = Button.new()
	quit_button.text = "退出游戏"
	quit_button.custom_minimum_size = Vector2(140, 50)
	quit_button.add_theme_font_size_override("font_size", 24)
	quit_button.pressed.connect(_on_quit_pressed)
	button_container.add_child(quit_button)

func show_game_over(winner_team: int, team1_level: int, team2_level: int, total_rounds: int = 0):
	"""显示游戏结束界面"""
	visible = true
	
	# 设置胜利者
	winner_label.text = "🏆 队伍%d 获胜! 🏆" % [winner_team + 1]
	
	# 设置统计信息
	var level_names = {
		2: "2", 3: "3", 4: "4", 5: "5", 6: "6", 7: "7", 8: "8",
		9: "9", 10: "10", 11: "J", 12: "Q", 13: "K", 14: "A"
	}
	
	var team1_level_str = level_names.get(team1_level, str(team1_level))
	var team2_level_str = level_names.get(team2_level, str(team2_level))
	
	stats_label.text = "最终等级\n队伍1: %s    队伍2: %s" % [team1_level_str, team2_level_str]
	
	if total_rounds > 0:
		stats_label.text += "\n\n总共进行了 %d 局" % total_rounds

func hide_game_over():
	"""隐藏游戏结束界面"""
	visible = false

func _on_restart_pressed():
	"""重新开始按钮"""
	restart_game.emit()

func _on_title_pressed():
	SoundManager.play_card_click()
	get_tree().change_scene_to_file("res://scenes/title.tscn")

func _on_quit_pressed():
	"""退出按钮"""
	quit_game.emit()
