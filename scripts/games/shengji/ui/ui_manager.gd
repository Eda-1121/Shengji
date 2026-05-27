extends CanvasLayer

var info_panel: Panel
var level_label: Label
var trump_label: Label

var team1_score_label: Label
var team2_score_label: Label
var team1_title_label: Label
var team2_title_label: Label

var turn_panel: Panel
var turn_label: Label

var action_panel: Panel
var play_button: Button
var bury_button: Button
var action_hint_label: Label

var center_message_panel: Panel
var center_message: Label
var selected_count_label: Label

var player_avatars: Array[Panel] = []
var player_name_labels: Array[Label] = []
var player_team_labels: Array[Label] = []
var player_card_count_labels: Array[Label] = []

var bidding_ui: Node
var game_over_ui: Node

var last_trick_panel: Panel
var last_trick_label: Label
var last_trick_button: Button
var last_trick_visible: bool = false
var _current_level: int = 2
var _current_trump_symbol: String = "♠"
var _team1_score: int = 0
var _team2_score: int = 0
var _selected_count: int = 0
var _selected_max: int = 8

signal play_cards_pressed
signal bury_cards_pressed

const C_GOLD   = Color(0.918, 0.738, 0.312)
const C_BG     = Color(0.026, 0.060, 0.082, 0.92)
const C_BORDER = Color(0.918, 0.738, 0.312, 0.34)
const C_CYAN   = Color(0.55, 0.92, 1.00)
const C_JADE   = Color(0.32, 0.78, 0.48)
const C_RED    = Color(0.88, 0.32, 0.29)
const CENTER_MESSAGE_MIN_WIDTH = 552.0
const CENTER_MESSAGE_MIN_HEIGHT = 74.0
const CENTER_MESSAGE_X_PADDING = 56.0
const CENTER_MESSAGE_Y_PADDING = 22.0
const ACTION_PANEL_WIDTH = 260.0
const ACTION_PANEL_HEIGHT = 78.0
const ACTION_BUTTON_WIDTH = 160.0
const ACTION_BUTTON_HEIGHT = 46.0

func _ready():
	layer = 1
	if not GameConfig.language_changed.is_connected(_on_language_changed):
		GameConfig.language_changed.connect(_on_language_changed)
	create_ui()
	create_phase2_ui()
	apply_layout()
	if not get_viewport().size_changed.is_connected(apply_layout):
		get_viewport().size_changed.connect(apply_layout)

func make_panel_style(bg_color: Color, border_color: Color = C_BORDER) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 10
	style.content_margin_left   = 10
	style.content_margin_right  = 10
	style.content_margin_top    = 8
	style.content_margin_bottom = 8
	return style

func style_panel(panel: Panel, bg_color: Color = C_BG):
	panel.add_theme_stylebox_override("panel", make_panel_style(bg_color))

func style_button(button: Button):
	button.add_theme_stylebox_override("normal",   make_panel_style(Color(0.035, 0.080, 0.110, 0.95), Color(C_GOLD, 0.38)))
	button.add_theme_stylebox_override("hover",    make_panel_style(Color(0.055, 0.130, 0.170, 0.98), Color(C_CYAN, 0.55)))
	button.add_theme_stylebox_override("pressed",  make_panel_style(Color(0.025, 0.055, 0.075, 1.00), Color(C_GOLD, 0.80)))
	button.add_theme_stylebox_override("disabled", make_panel_style(Color(0.030, 0.050, 0.060, 0.60), Color(C_GOLD, 0.15)))
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
	button.add_theme_stylebox_override("hover",    mk.call(Color(0.98, 0.86, 0.42)))
	button.add_theme_stylebox_override("pressed",  mk.call(C_GOLD.darkened(0.12)))
	button.add_theme_stylebox_override("disabled", mk.call(Color(C_GOLD, 0.35)))
	button.add_theme_color_override("font_color",          Color(0.08, 0.06, 0.02))
	button.add_theme_color_override("font_disabled_color", Color(0.08, 0.06, 0.02, 0.50))

func create_ui():
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
	level_label.text = GameConfig.text("current_level") % "2"
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.add_theme_color_override("font_color", Color(C_GOLD, 0.90))
	info_container.add_child(level_label)

	trump_label = Label.new()
	trump_label.text = GameConfig.text("trump_suit") % "♠"
	trump_label.add_theme_font_size_override("font_size", 18)
	trump_label.add_theme_color_override("font_color", Color(C_CYAN, 0.96))
	info_container.add_child(trump_label)

	var separator1 = HSeparator.new()
	separator1.custom_minimum_size = Vector2(222, 2)
	info_container.add_child(separator1)

	var score_container = GridContainer.new()
	score_container.columns = 2
	score_container.add_theme_constant_override("h_separation", 28)
	score_container.add_theme_constant_override("v_separation", 4)
	info_container.add_child(score_container)

	team1_title_label = Label.new()
	team1_title_label.text = GameConfig.text("team_a")
	team1_title_label.add_theme_font_size_override("font_size", 16)
	team1_title_label.add_theme_color_override("font_color", Color(C_JADE, 0.95))
	score_container.add_child(team1_title_label)

	team2_title_label = Label.new()
	team2_title_label.text = GameConfig.text("team_b")
	team2_title_label.add_theme_font_size_override("font_size", 16)
	team2_title_label.add_theme_color_override("font_color", Color(C_RED, 0.95))
	score_container.add_child(team2_title_label)

	team1_score_label = Label.new()
	team1_score_label.text = GameConfig.text("points") % 0
	team1_score_label.add_theme_font_size_override("font_size", 20)
	score_container.add_child(team1_score_label)

	team2_score_label = Label.new()
	team2_score_label.text = GameConfig.text("points") % 0
	team2_score_label.add_theme_font_size_override("font_size", 20)
	score_container.add_child(team2_score_label)

	turn_panel = Panel.new()
	turn_panel.position = Vector2(354, 18)
	turn_panel.size = Vector2(572, 52)
	turn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_panel(turn_panel, Color(0.020, 0.055, 0.080, 0.86))
	add_child(turn_panel)

	turn_label = Label.new()
	turn_label.position = Vector2(12, 7)
	turn_label.size = Vector2(548, 38)
	turn_label.text = GameConfig.text("your_turn")
	turn_label.add_theme_font_size_override("font_size", 20)
	turn_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_panel.add_child(turn_label)

	# ── アクションパネル ────────────────────────────
	action_panel = Panel.new()
	action_panel.position = Vector2(560, 666)
	action_panel.size = Vector2(ACTION_PANEL_WIDTH, ACTION_PANEL_HEIGHT)
	action_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(action_panel)

	selected_count_label = Label.new()
	selected_count_label.position = Vector2(0, -34)
	selected_count_label.size = Vector2(ACTION_PANEL_WIDTH, 28)
	selected_count_label.text = GameConfig.text("selected") % [0, 8]
	selected_count_label.add_theme_font_size_override("font_size", 17)
	selected_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_count_label.visible = false
	action_panel.add_child(selected_count_label)

	var button_container = Control.new()
	button_container.position = Vector2((ACTION_PANEL_WIDTH - ACTION_BUTTON_WIDTH) * 0.5, 0)
	button_container.size = Vector2(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT)
	action_panel.add_child(button_container)

	play_button = Button.new()
	play_button.text = GameConfig.text("play")
	play_button.position = Vector2.ZERO
	play_button.size = Vector2(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT)
	play_button.add_theme_font_size_override("font_size", 18)
	style_play_button(play_button)
	play_button.pressed.connect(_on_play_button_pressed)
	button_container.add_child(play_button)

	bury_button = Button.new()
	bury_button.text = GameConfig.text("confirm_bury")
	bury_button.position = Vector2.ZERO
	bury_button.size = Vector2(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT)
	bury_button.add_theme_font_size_override("font_size", 17)
	style_play_button(bury_button)
	bury_button.pressed.connect(_on_bury_button_pressed)
	bury_button.visible = false
	button_container.add_child(bury_button)

	action_hint_label = Label.new()
	action_hint_label.position = Vector2(0, 50)
	action_hint_label.size = Vector2(ACTION_PANEL_WIDTH, 22)
	action_hint_label.text = GameConfig.text("action_hint_select_play")
	action_hint_label.add_theme_font_size_override("font_size", 13)
	action_hint_label.add_theme_color_override("font_color", Color(C_CYAN, 0.78))
	action_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_panel.add_child(action_hint_label)

	# ── centerメッセージ ──────────────────────────────
	center_message_panel = Panel.new()
	center_message_panel.position = Vector2(364, 302)
	center_message_panel.size = Vector2(552, 74)
	center_message_panel.visible = false
	center_message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_panel(center_message_panel, Color(0.025, 0.052, 0.070, 0.93))
	add_child(center_message_panel)

	center_message = Label.new()
	center_message.position = Vector2(14, 8)
	center_message.size = Vector2(524, 58)
	center_message.text = ""
	center_message.add_theme_font_size_override("font_size", 28)
	center_message.add_theme_color_override("font_color", Color(C_GOLD, 0.98))
	center_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_message_panel.add_child(center_message)

	last_trick_button = Button.new()
	last_trick_button.text = GameConfig.text("previous_trick")
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
	var BiddingUIScript = load("res://scripts/games/shengji/ui/bidding_ui.gd")
	if BiddingUIScript:
		bidding_ui = Control.new()
		bidding_ui.name = "BiddingUI"
		bidding_ui.set_script(BiddingUIScript)
		add_child(bidding_ui)

	var GameOverUIScript = load("res://scripts/games/shengji/ui/game_over_ui.gd")
	if GameOverUIScript:
		game_over_ui = Control.new()
		game_over_ui.name = "GameOverUI"
		game_over_ui.set_script(GameOverUIScript)
		add_child(game_over_ui)

func create_player_avatars():
	for i in range(4):
		var avatar_panel = Panel.new()
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
		name_label.text = GameConfig.text("player_name") % [i + 1]
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_panel.add_child(name_label)
		player_name_labels.append(name_label)

		var status_label = Label.new()
		status_label.position = Vector2(10, 33)
		status_label.size = Vector2(66, 20)
		status_label.text = GameConfig.text("team_a") if i % 2 == 0 else GameConfig.text("team_b")
		status_label.add_theme_font_size_override("font_size", 13)
		status_label.add_theme_color_override("font_color",
			Color(0.35, 0.85, 0.45) if i % 2 == 0 else Color(0.95, 0.42, 0.42))
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_panel.add_child(status_label)
		player_team_labels.append(status_label)

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

func apply_layout():
	var viewport_size = get_viewport().get_visible_rect().size
	var w = viewport_size.x
	var h = viewport_size.y
	var margin = max(18.0, w * 0.014)

	if info_panel:
		info_panel.position = Vector2(margin, margin)

	if turn_panel:
		turn_panel.size = Vector2(min(720.0, w * 0.46), 52)
		turn_panel.position = Vector2((w - turn_panel.size.x) * 0.5, margin)
		if turn_label:
			turn_label.size = Vector2(turn_panel.size.x - 24, 38)

	if action_panel:
		action_panel.position = Vector2((w - action_panel.size.x) * 0.5, h - 98)

	if center_message_panel:
		center_message_panel.position = Vector2((w - center_message_panel.size.x) * 0.5, h * 0.42)
		if center_message:
			center_message.position = Vector2(14, 8)
			center_message.size = center_message_panel.size - Vector2(28, 16)

	if last_trick_button:
		last_trick_button.position = Vector2(w - margin - last_trick_button.size.x, margin)

	if last_trick_panel:
		last_trick_panel.position = Vector2(w - margin - last_trick_panel.size.x, margin + last_trick_button.size.y + 8)

	if player_avatars.size() == 4:
		player_avatars[0].position = Vector2((w - player_avatars[0].size.x) * 0.5, h - 112)
		player_avatars[1].position = Vector2(margin + 6, h * 0.48 - player_avatars[1].size.y * 0.5)
		player_avatars[2].position = Vector2((w - player_avatars[2].size.x) * 0.5, h * 0.13)
		player_avatars[3].position = Vector2(w - margin - 6 - player_avatars[3].size.x, h * 0.48 - player_avatars[3].size.y * 0.5)

# ── ボタンコールバック ──────────────────────────────

func _on_play_button_pressed():
	play_cards_pressed.emit()

func _on_bury_button_pressed():
	bury_cards_pressed.emit()

# ── UIupdateメソッド ──────────────────────────────────

func update_level(level: int):
	_current_level = level
	var level_names = {
		2: "2", 3: "3", 4: "4", 5: "5", 6: "6", 7: "7", 8: "8",
		9: "9", 10: "10", 11: "J", 12: "Q", 13: "K", 14: "A"
	}
	level_label.text = GameConfig.text("current_level") % level_names.get(level, str(level))

func update_trump_suit(suit_symbol: String):
	_current_trump_symbol = suit_symbol
	trump_label.text = GameConfig.text("trump_suit") % suit_symbol

func update_team_scores(team1_score: int, team2_score: int):
	var old_team1 = _team1_score
	var old_team2 = _team2_score
	_team1_score = team1_score
	_team2_score = team2_score
	team1_score_label.text = GameConfig.text("points") % team1_score
	team2_score_label.text = GameConfig.text("points") % team2_score
	if team1_score > old_team1:
		pulse_label(team1_score_label, C_JADE)
	if team2_score > old_team2:
		pulse_label(team2_score_label, C_RED)

func update_turn_message(message: String):
	turn_label.text = message

func show_center_message(message: String, duration: float = 2.0):
	center_message.text = message
	fit_center_message_to_text(message)
	center_message_panel.visible = true
	await get_tree().create_timer(duration).timeout
	center_message_panel.visible = false

func fit_center_message_to_text(message: String):
	var viewport_size = get_viewport().get_visible_rect().size
	var max_width = max(CENTER_MESSAGE_MIN_WIDTH, viewport_size.x - 120.0)
	var font = center_message.get_theme_font("font")
	var font_size = center_message.get_theme_font_size("font_size")
	var text_width = font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var panel_width = clamp(text_width + CENTER_MESSAGE_X_PADDING, CENTER_MESSAGE_MIN_WIDTH, max_width)
	var wraps = text_width + CENTER_MESSAGE_X_PADDING > max_width
	center_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wraps else TextServer.AUTOWRAP_OFF

	var label_width = panel_width - 28.0
	var text_height = font.get_multiline_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, label_width, font_size).y if wraps else font_size + 8.0
	var panel_height = max(CENTER_MESSAGE_MIN_HEIGHT, text_height + CENTER_MESSAGE_Y_PADDING)

	center_message_panel.size = Vector2(panel_width, panel_height)
	center_message.position = Vector2(14, 8)
	center_message.size = Vector2(panel_width - 28.0, panel_height - 16.0)
	apply_layout()

func set_buttons_enabled(enabled: bool):
	play_button.disabled = not enabled
	update_action_hint()

func highlight_current_player(player_id: int):
	for i in range(player_avatars.size()):
		if i == player_id:
			player_avatars[i].modulate = Color(1.3, 1.2, 0.9)
			pulse_panel(player_avatars[i], Color(C_GOLD, 1.0), Color(1.3, 1.2, 0.9))
		else:
			player_avatars[i].modulate = Color.WHITE

func show_trick_result(winner_player_id: int, message: String, duration: float = 2.0):
	if winner_player_id >= 0 and winner_player_id < player_avatars.size():
		pulse_panel(player_avatars[winner_player_id], Color(C_CYAN, 1.0), player_avatars[winner_player_id].modulate)
	show_center_message(message, duration)

func pulse_panel(panel: Panel, color: Color, restore_color: Color = Color.WHITE):
	if panel == null:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "modulate", color, 0.12)
	tween.tween_property(panel, "modulate", restore_color, 0.34)

func pulse_label(label: Label, color: Color):
	if label == null:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "scale", Vector2(1.14, 1.14), 0.12)
	tween.parallel().tween_property(label, "modulate", color, 0.12)
	tween.tween_property(label, "scale", Vector2.ONE, 0.28)
	tween.parallel().tween_property(label, "modulate", Color.WHITE, 0.28)

func show_bury_button(visible: bool):
	bury_button.visible = visible
	selected_count_label.visible = visible
	play_button.visible = not visible
	update_action_hint()

func set_bury_button_enabled(enabled: bool):
	bury_button.disabled = not enabled
	update_action_hint()

func update_selected_count(count: int, max_count: int = 8):
	_selected_count = count
	_selected_max = max_count
	selected_count_label.text = GameConfig.text("selected") % [count, max_count]
	if count == max_count:
		set_bury_button_enabled(true)
		selected_count_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))
	else:
		set_bury_button_enabled(false)
		if count > max_count:
			selected_count_label.add_theme_color_override("font_color", Color(0.95, 0.42, 0.42))
		else:
			selected_count_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	update_action_hint()

func update_action_hint():
	if action_hint_label == null:
		return
	if bury_button and bury_button.visible:
		action_hint_label.text = GameConfig.text("action_hint_ready_bury") if not bury_button.disabled else GameConfig.text("action_hint_select_bury")
	elif play_button:
		action_hint_label.text = GameConfig.text("action_hint_ready_play") if not play_button.disabled else GameConfig.text("action_hint_select_play")

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
	last_trick_button.text = GameConfig.text("close") if last_trick_visible else GameConfig.text("previous_trick")

func _on_language_changed(_language: String):
	if level_label:
		update_level(_current_level)
	if trump_label:
		update_trump_suit(_current_trump_symbol)
	if team1_score_label and team2_score_label:
		update_team_scores(_team1_score, _team2_score)
	if selected_count_label:
		update_selected_count(_selected_count, _selected_max)
	if team1_title_label:
		team1_title_label.text = GameConfig.text("team_a")
	if team2_title_label:
		team2_title_label.text = GameConfig.text("team_b")
	if play_button:
		play_button.text = GameConfig.text("play")
	if bury_button:
		bury_button.text = GameConfig.text("confirm_bury")
	if action_hint_label:
		update_action_hint()
	if last_trick_button:
		last_trick_button.text = GameConfig.text("close") if last_trick_visible else GameConfig.text("previous_trick")
	for i in range(player_name_labels.size()):
		player_name_labels[i].text = GameConfig.text("player_name") % [i + 1]
	for i in range(player_team_labels.size()):
		player_team_labels[i].text = GameConfig.text("team_a") if i % 2 == 0 else GameConfig.text("team_b")
