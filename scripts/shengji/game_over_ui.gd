# game_over_ui.gd - ゲーム終了画面
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

const C_GOLD = Color(0.941, 0.788, 0.416)

func _ready():
	create_game_over_panel()
	visible = false

func create_game_over_panel():
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.72)
	background.position = Vector2.ZERO
	background.size = Vector2(1280, 720)
	add_child(background)

	panel = Panel.new()
	panel.position = Vector2(340, 170)
	panel.size = Vector2(600, 380)

	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.051, 0.106, 0.165)
	ps.border_color = Color(C_GOLD, 0.50)
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	# ゴールド区切りライン
	var accent_line = ColorRect.new()
	accent_line.position = Vector2(0, 0)
	accent_line.size = Vector2(600, 4)
	accent_line.color = C_GOLD
	panel.add_child(accent_line)

	title_label = Label.new()
	title_label.position = Vector2(50, 22)
	title_label.size = Vector2(500, 50)
	title_label.text = "ゲーム終了"
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(C_GOLD, 0.95))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title_label)

	winner_label = Label.new()
	winner_label.position = Vector2(50, 100)
	winner_label.size = Vector2(500, 60)
	winner_label.text = "チームA が勝利!"
	winner_label.add_theme_font_size_override("font_size", 32)
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_color_override("font_color", Color(C_GOLD))
	panel.add_child(winner_label)

	# 区切り線
	var sep = ColorRect.new()
	sep.position = Vector2(60, 170)
	sep.size = Vector2(480, 1)
	sep.color = Color(C_GOLD, 0.25)
	panel.add_child(sep)

	stats_label = Label.new()
	stats_label.position = Vector2(50, 182)
	stats_label.size = Vector2(500, 80)
	stats_label.text = "チームA: レベルA\nチームB: レベル10"
	stats_label.add_theme_font_size_override("font_size", 22)
	stats_label.add_theme_color_override("font_color", Color(0.75, 0.87, 1.00))
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(stats_label)

	var button_container = HBoxContainer.new()
	button_container.position = Vector2(40, 295)
	button_container.add_theme_constant_override("separation", 16)
	panel.add_child(button_container)

	restart_button = _make_btn("もう一度", true)
	restart_button.pressed.connect(_on_restart_pressed)
	button_container.add_child(restart_button)

	title_button = _make_btn("タイトルへ", false)
	title_button.pressed.connect(_on_title_pressed)
	button_container.add_child(title_button)

	quit_button = _make_btn("ゲームを終了", false)
	quit_button.pressed.connect(_on_quit_pressed)
	button_container.add_child(quit_button)

func _make_btn(text: String, primary: bool) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(152, 52)
	btn.add_theme_font_size_override("font_size", 20)
	if primary:
		var mk = func(col: Color) -> StyleBoxFlat:
			var s = StyleBoxFlat.new()
			s.bg_color = col
			s.set_corner_radius_all(8)
			s.set_border_width_all(0)
			return s
		btn.add_theme_stylebox_override("normal",  mk.call(C_GOLD))
		btn.add_theme_stylebox_override("hover",   mk.call(C_GOLD.lightened(0.15)))
		btn.add_theme_stylebox_override("pressed", mk.call(C_GOLD.darkened(0.12)))
		btn.add_theme_color_override("font_color", Color(0.08, 0.06, 0.02))
	else:
		var mk = func(alpha: float) -> StyleBoxFlat:
			var s = StyleBoxFlat.new()
			s.bg_color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, alpha)
			s.border_color = Color(C_GOLD, 0.50)
			s.set_border_width_all(1)
			s.set_corner_radius_all(8)
			return s
		btn.add_theme_stylebox_override("normal",  mk.call(0.0))
		btn.add_theme_stylebox_override("hover",   mk.call(0.12))
		btn.add_theme_stylebox_override("pressed", mk.call(0.22))
		btn.add_theme_color_override("font_color", Color(C_GOLD, 0.85))
	return btn

func show_game_over(winner_team: int, team1_level: int, team2_level: int, total_rounds: int = 0):
	visible = true

	winner_label.text = "🏆 チーム%s が勝利! 🏆" % ("A" if winner_team == 0 else "B")

	var level_names = {
		2: "2", 3: "3", 4: "4", 5: "5", 6: "6", 7: "7", 8: "8",
		9: "9", 10: "10", 11: "J", 12: "Q", 13: "K", 14: "A"
	}
	var l1 = level_names.get(team1_level, str(team1_level))
	var l2 = level_names.get(team2_level, str(team2_level))
	stats_label.text = "最終レベル\nチームA: %s　　チームB: %s" % [l1, l2]
	if total_rounds > 0:
		stats_label.text += "\n\n合計 %d ラウンド" % total_rounds

func hide_game_over():
	visible = false

func _on_restart_pressed():
	restart_game.emit()

func _on_title_pressed():
	SoundManager.play_card_click()
	get_tree().change_scene_to_file("res://scenes/title.tscn")

func _on_quit_pressed():
	quit_game.emit()
