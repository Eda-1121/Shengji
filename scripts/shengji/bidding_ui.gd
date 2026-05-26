# bidding_ui.gd - 宣言UIコンポーネント
extends Control
class_name BiddingUI

signal bid_made(suit: Card.Suit, count: int)
signal bid_passed

var bid_panel: Panel
var button_container: HBoxContainer
var current_bid_label: Label

const C_GOLD = Color(0.941, 0.788, 0.416)

var suit_names = {
	Card.Suit.SPADE:   "スペード ♠",
	Card.Suit.HEART:   "ハート ♥",
	Card.Suit.CLUB:    "クラブ ♣",
	Card.Suit.DIAMOND: "ダイヤ ♦"
}

func _ready():
	create_bidding_panel()
	visible = false

func create_bidding_panel():
	bid_panel = Panel.new()
	bid_panel.position = Vector2(280, 238)
	bid_panel.size = Vector2(720, 190)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.09, 0.14, 0.95)
	panel_style.border_color = Color(C_GOLD, 0.50)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	bid_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(bid_panel)

	var title_label = Label.new()
	title_label.position = Vector2(20, 10)
	title_label.size = Vector2(680, 30)
	title_label.text = "宣言フェーズ"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(C_GOLD, 0.95))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bid_panel.add_child(title_label)

	current_bid_label = Label.new()
	current_bid_label.position = Vector2(20, 50)
	current_bid_label.size = Vector2(680, 25)
	current_bid_label.text = "まだ宣言なし"
	current_bid_label.add_theme_font_size_override("font_size", 18)
	current_bid_label.add_theme_color_override("font_color", Color(0.75, 0.87, 1.00))
	current_bid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bid_panel.add_child(current_bid_label)

	button_container = HBoxContainer.new()
	button_container.position = Vector2(30, 105)
	button_container.size = Vector2(660, 50)
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 10)
	bid_panel.add_child(button_container)

func _make_bid_btn_style(active: bool) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color     = C_GOLD if active else Color(0.06, 0.12, 0.20, 0.95)
	s.border_color = Color(C_GOLD, 0.80 if active else 0.40)
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	return s

func show_bidding_options(available_suits: Array, suit_counts: Dictionary = {}):
	for child in button_container.get_children():
		child.queue_free()

	visible = true

	for suit in available_suits:
		var btn = Button.new()
		if suit_counts.has(suit):
			var count = suit_counts[suit]
			btn.text = "%s (%d枚)" % [suit_names[suit], count]
		else:
			btn.text = suit_names[suit]
		btn.custom_minimum_size = Vector2(130, 44)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_stylebox_override("normal",  _make_bid_btn_style(false))
		btn.add_theme_stylebox_override("hover",   _make_bid_btn_style(true))
		btn.add_theme_color_override("font_color", Color(C_GOLD, 0.90))

		var suit_to_bid  = suit
		var count_to_bid = suit_counts.get(suit, 1)
		btn.pressed.connect(func(): _on_suit_button_pressed(suit_to_bid, count_to_bid))
		button_container.add_child(btn)

	var pass_button = Button.new()
	pass_button.text = "パス"
	pass_button.custom_minimum_size = Vector2(100, 44)
	pass_button.add_theme_font_size_override("font_size", 18)
	var ps = StyleBoxFlat.new()
	ps.bg_color     = Color(0.06, 0.10, 0.16, 0.90)
	ps.border_color = Color(0.60, 0.74, 0.90, 0.40)
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(8)
	pass_button.add_theme_stylebox_override("normal", ps)
	var psh = ps.duplicate()
	psh.bg_color = Color(0.09, 0.14, 0.22)
	pass_button.add_theme_stylebox_override("hover", psh)
	pass_button.add_theme_color_override("font_color", Color(0.75, 0.87, 1.00))
	pass_button.pressed.connect(_on_pass_button_pressed)
	button_container.add_child(pass_button)

func hide_bidding_ui():
	visible = false
	for child in button_container.get_children():
		child.queue_free()

func update_current_bid(message: String):
	current_bid_label.text = message

func _on_suit_button_pressed(suit: Card.Suit, count: int = 1):
	bid_made.emit(suit, count)
	hide_bidding_ui()

func _on_pass_button_pressed():
	bid_passed.emit()
	hide_bidding_ui()

func show_bidding_ui(can_bid: bool = true):
	visible = can_bid

func enable_buttons(enabled: bool):
	for btn in button_container.get_children():
		if btn is Button:
			btn.disabled = not enabled
