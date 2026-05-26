# ui_manager.gd - UI管理
extends CanvasLayer

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

var player_avatars: Array[Panel] = []
var player_name_labels: Array[Label] = []
var player_card_count_labels: Array[Label] = []

var bidding_ui: Node
var game_over_ui: Node

var last_trick_panel: Panel
var last_trick_label: Label
var last_trick_button: Button
var last_trick_visible: bool = false

signal play_cards_pressed
signal bury_cards_pressed

const C_GOLD   = Color(0.941, 0.788, 0.416)
const C_BG     = Color(0.04,  0.09,  0.14,  0.92)
const C_BORDER = Color(0.941, 0.788, 0.416, 0.30)

func _ready():
	layer = 1
	create_ui()
	create_phase2_ui()

func make_panel_style(bg_color: Color, border_color: Color = C_BORDER) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left   = 10
	style.content_margin_right  = 10
	style.content_margin_top    = 8
	style.content_margin_bottom = 8
	return style

func style_panel(panel: Panel, bg_color: Color = C_BG):
	panel.add_theme_stylebox_override("panel", make_panel_style(bg_color))

func style_button(button: Button):
	button.add_theme_stylebox_override("normal",   make_panel_style(Color(0.06, 0.12, 0.20, 0.95), Color(C_GOLD, 0.38)))
	button.add_theme_stylebox_override("hover",    make_panel_style(Color(0.09, 0.17, 0.28, 0.98), Color(C_GOLD, 0.60)))
	button.add_theme_stylebox_override("pressed",  make_panel_style(Color(0.04, 0.08, 0.14, 1.00), Color(C_GOLD, 0.80)))
	button.add_theme_stylebox_override("disabled", make_panel_style(Color(0.05, 0.08, 0.12, 0.60), Color(C_GOLD, 0.15)))
	button.add_theme_color_override("font_color",          Color(C_GOLD, 0.90))
	button.add_theme_color_override("font_disabled_color", Color(C_GOLD, 0.35))

func style_play_button(button: Button):
	var mk = func(col: Color) -> StyleBoxFlat:
		var s = StyleBoxFlat.new()
		s.bg_color = col
		s.set_corner_radius_all(8)
		s.set_border_width_all(0)
		s.content_margin_left  = 6
		s.content_margin_right = 6
		return s
	button.add_theme_stylebox_override("normal",   mk.call(C_GOLD))
	button.add_theme_stylebox_override("hover",    mk.call(C_GOLD.lightened(0.15)))
	button.add_theme_stylebox_override("pressed",  mk.call(C_GOLD.darkened(0.12)))
	button.add_theme_stylebox_override("disabled", mk.call(Color(C_GOLD, 0.35)))
	button.add_theme_color_override("font_color",          Color(0.08, 0.06, 0.02))
	button.add_theme_color_override("font_disabled_color", Color(0.08, 0.06, 0.02, 0.50))

func create_ui():
	# ── 左上情報パネル ──────────────────────────────
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

	level_label = Label.new()
	level_label.text = "現在レベル: 2"
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.add_theme_color_override("font_color", Color(C_GOLD, 0.90))
	info_container.add_child(level_label)

	trump_label = Label.new()
	trump_label.text = "主スート: ♠"
	trump_label.add_theme_font_size_override("font_size", 18)
	trump_label.add_theme_color_override("font_color", Color(0.75, 0.87, 1.00))
	info_container.add_child(trump_label)

	var separator1 = HSeparator.new()
	separator1.custom_minimum_size = Vector2(222, 2)
	info_container.add_child(separator1)

	var score_container = GridContainer.new()
	score_container.columns = 2
	score_container.add_theme_constant_override("h_separation", 28)
	score_container.add_theme_constant_override("v_separation", 4)
	info_container.add_child(score_container)

	var team1_title = Label.new()
	team1_title.text = "チームA"
	team1_title.add_theme_font_size_override("font_size", 16)
	team1_title.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))
	score_container.add_child(team1_title)

	var team2_title = Label.new()
	team2_title.text = "チームB"
	team2_title.add_theme_font_size_override("font_size", 16)
	team2_title.add_theme_color_override("font_color", Color(0.95, 0.42, 0.42))
	score_container.add_child(team2_title)

	team1_score_label = Label.new()
	team1_score_label.text = "0点"
	team1_score_label.add_theme_font_size_override("font_size", 20)
	score_container.add_child(team1_score_label)

	team2_score_label = Label.new()
	team2_score_label.text = "0点"
	team2_score_label.add_theme_font_size_override("font_size", 20)
	score_container.add_child(team2_score_label)

	# ── ターン表示 ──────────────────────────────────
	turn_panel = Panel.new()
	turn_panel.position = Vector2(354, 18)
	turn_panel.size = Vector2(572, 52)
	turn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_panel(turn_panel, Color(0.03, 0.07, 0.12, 0.85))
	add_child(turn_panel)

	turn_label = Label.new()
	turn_label.position = Vector2(12, 7)
	turn_label.size = Vector2(548, 38)
	turn_label.text = "あなたの番"
	turn_label.add_theme_font_size_override("font_size", 20)
	turn_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_panel.add_child(turn_label)

	# ── アクションパネル ────────────────────────────
	action_panel = Panel.new()
	action_panel.position = Vector2(560, 666)
	action_panel.size = Vector2(160, 50)
	action_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(action_panel)

	selected_count_label = Label.new()
	selected_count_label.position = Vector2(-20, -34)
	selected_count_label.size = Vector2(200, 28)
	selected_count_label.text = "選択: 0/8"
	selected_count_label.add_theme_font_size_override("font_size", 17)
	selected_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_count_label.visible = false
	action_panel.add_child(selected_count_label)

	var button_container = Control.new()
	button_container.position = Vector2(10, 1)
	button_container.size = Vector2(140, 48)
	action_panel.add_child(button_container)

	play_button = Button.new()
	play_button.text = "出す"
	play_button.position = Vector2.ZERO
	play_button.size = Vector2(140, 48)
	play_button.add_theme_font_size_override("font_size", 20)
	style_play_button(play_button)
	play_button.pressed.connect(_on_play_button_pressed)
	button_container.add_child(play_button)

	bury_button = Button.new()
	bury_button.text = "埋底確定"
	bury_button.position = Vector2.ZERO
	bury_button.size = Vector2(140, 48)
	bury_button.add_theme_font_size_override("font_size", 20)
	style_play_button(bury_button)
	bury_button.pressed.connect(_on_bury_button_pressed)
	bury_button.visible = false
	button_container.add_child(bury_button)

	# ── 中央メッセージ ──────────────────────────────
	center_message_panel = Panel.new()
	center_message_panel.position = Vector2(364, 302)
	center_message_panel.size = Vector2(552, 74)
	center_message_panel.visible = false
	center_message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_panel(center_message_panel, Color(0.03, 0.07, 0.12, 0.90))
	add_child(center_message_panel)

	center_message = Label.new()
	center_message.position = Vector2(14, 8)
	center_message.size = Vector2(524, 58)
	center_message.text = ""
	center_message.add_theme_font_size_override("font_size", 28)
	center_message.add_theme_color_override("font_color", Color(C_GOLD, 0.95))
	center_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_message_panel.add_child(center_message)

	# ── 前トリック ──────────────────────────────────
	last_trick_button = Button.new()
	last_trick_button.text = "前の手"
	last_trick_button.position = Vector2(1090, 18)
	last_trick_button.size = Vector2(172, 36)
	last_trick_button.add_theme_font_size_override("font_size", 15)
	style_button(last_trick_button)
	last_trick_button.visible = false
	last_trick_button.pressed.connect(_on_last_trick_button_pressed)
	add_child(last_trick_button)

	last_trick_panel = Panel.new()
	last_trick_panel.position = Vector2(870, 62)
	last_trick_panel.size = Vector2(392, 150)
	last_trick_panel.visible = false
	last_trick_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	style_panel(last_trick_panel, Color(0.03, 0.07, 0.12, 0.97))
	add_child(last_trick_panel)

	last_trick_label = Label.new()
	last_trick_label.position = Vector2(10, 8)
	last_trick_label.size = Vector2(372, 134)
	last_trick_label.add_theme_font_size_override("font_size", 14)
	last_trick_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90))
	last_trick_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	last_trick_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	last_trick_panel.add_child(last_trick_label)

	create_player_avatars()

func create_phase2_ui():
	var BiddingUIScript = load("res://scripts/shengji/bidding_ui.gd")
	if BiddingUIScript:
		bidding_ui = Control.new()
		bidding_ui.name = "BiddingUI"
		bidding_ui.set_script(BiddingUIScript)
		add_child(bidding_ui)

	var GameOverUIScript = load("res://scripts/shengji/game_over_ui.gd")
	if GameOverUIScript:
		game_over_ui = Control.new()
		game_over_ui.name = "GameOverUI"
		game_over_ui.set_script(GameOverUIScript)
		add_child(game_over_ui)

func create_player_avatars():
	var avatar_positions = [
		Vector2(570, 632),
		Vector2(24,  300),
		Vector2(570, 84),
		Vector2(1126, 300)
	]
	var player_names = ["あなた", "左", "向かい", "右"]

	for i in range(4):
		var avatar_panel = Panel.new()
		avatar_panel.position = avatar_positions[i]
		avatar_panel.size = Vector2(136, 64)
		avatar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		style_panel(avatar_panel, Color(0.03, 0.07, 0.12, 0.85))

		if i == 0:
			avatar_panel.visible = false

		add_child(avatar_panel)
		player_avatars.append(avatar_panel)

		var name_label = Label.new()
		name_label.position = Vector2(10, 7)
		name_label.size = Vector2(116, 26)
		name_label.text = player_names[i]
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_panel.add_child(name_label)
		player_name_labels.append(name_label)

		var status_label = Label.new()
		status_label.position = Vector2(10, 33)
		status_label.size = Vector2(66, 20)
		status_label.text = "チーム%s" % ("A" if i % 2 == 0 else "B")
		status_label.add_theme_font_size_override("font_size", 13)
		status_label.add_theme_color_override("font_color",
			Color(0.35, 0.85, 0.45) if i % 2 == 0 else Color(0.95, 0.42, 0.42))
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_panel.add_child(status_label)

		var count_label = Label.new()
		count_label.position = Vector2(76, 33)
		count_label.size = Vector2(50, 20)
		count_label.text = "🂠 --"
		count_label.add_theme_font_size_override("font_size", 13)
		count_label.add_theme_color_override("font_color", Color(C_GOLD, 0.80))
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_panel.add_child(count_label)
		player_card_count_labels.append(count_label)

# ── ボタンコールバック ──────────────────────────────

func _on_play_button_pressed():
	play_cards_pressed.emit()

func _on_bury_button_pressed():
	bury_cards_pressed.emit()

# ── UI更新メソッド ──────────────────────────────────

func update_level(level: int):
	var level_names = {
		2: "2", 3: "3", 4: "4", 5: "5", 6: "6", 7: "7", 8: "8",
		9: "9", 10: "10", 11: "J", 12: "Q", 13: "K", 14: "A"
	}
	level_label.text = "現在レベル: %s" % level_names.get(level, str(level))

func update_trump_suit(suit_symbol: String):
	trump_label.text = "主スート: %s" % suit_symbol

func update_team_scores(team1_score: int, team2_score: int):
	team1_score_label.text = "%d点" % team1_score
	team2_score_label.text = "%d点" % team2_score

func update_turn_message(message: String):
	turn_label.text = message

func show_center_message(message: String, duration: float = 2.0):
	center_message.text = message
	center_message_panel.visible = true
	await get_tree().create_timer(duration).timeout
	center_message_panel.visible = false

func set_buttons_enabled(enabled: bool):
	play_button.disabled = not enabled

func highlight_current_player(player_id: int):
	for i in range(player_avatars.size()):
		if i == player_id:
			player_avatars[i].modulate = Color(1.3, 1.2, 0.9)
		else:
			player_avatars[i].modulate = Color.WHITE

func show_bury_button(visible: bool):
	bury_button.visible = visible
	selected_count_label.visible = visible
	play_button.visible = not visible

func set_bury_button_enabled(enabled: bool):
	bury_button.disabled = not enabled

func update_selected_count(count: int, max_count: int = 8):
	selected_count_label.text = "選択: %d/%d" % [count, max_count]
	if count == max_count:
		set_bury_button_enabled(true)
		selected_count_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))
	else:
		set_bury_button_enabled(false)
		if count > max_count:
			selected_count_label.add_theme_color_override("font_color", Color(0.95, 0.42, 0.42))
		else:
			selected_count_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

func update_player_card_count(player_id: int, count: int):
	if player_id < player_card_count_labels.size():
		player_card_count_labels[player_id].text = "🂠 %d" % count

func update_last_trick(summary: Array):
	if summary.is_empty():
		last_trick_button.visible = false
		return
	last_trick_button.visible = true
	last_trick_visible = false
	last_trick_panel.visible = false
	var lines = []
	for entry in summary:
		var marker = "★ " if entry["is_winner"] else "  "
		lines.append("%s%s: %s" % [marker, entry["player_name"], entry["cards_text"]])
	last_trick_label.text = "\n".join(lines)

func _on_last_trick_button_pressed():
	last_trick_visible = not last_trick_visible
	last_trick_panel.visible = last_trick_visible
	last_trick_button.text = "閉じる" if last_trick_visible else "前の手"
