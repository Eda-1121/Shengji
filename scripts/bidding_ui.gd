# bidding_ui.gd - 叫牌界面组件
extends Control
class_name BiddingUI

signal bid_made(suit: Card.Suit, count: int)
signal bid_passed

var bid_panel: Panel
var button_container: HBoxContainer
var current_bid_label: Label

var suit_names = {
	Card.Suit.SPADE: "黑桃 ♠",
	Card.Suit.HEART: "红心 ♥",
	Card.Suit.CLUB: "梅花 ♣",
	Card.Suit.DIAMOND: "方片 ♦"
}

func _ready():
	create_bidding_panel()
	visible = false

func create_bidding_panel():
	"""创建叫牌面板"""
	# 主面板
	bid_panel = Panel.new()
	bid_panel.position = Vector2(400, 250)
	bid_panel.size = Vector2(480, 180)
	add_child(bid_panel)

	# 标题
	var title_label = Label.new()
	title_label.position = Vector2(20, 10)
	title_label.size = Vector2(440, 30)
	title_label.text = "叫牌阶段"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bid_panel.add_child(title_label)

	# 当前叫牌信息
	current_bid_label = Label.new()
	current_bid_label.position = Vector2(20, 50)
	current_bid_label.size = Vector2(440, 25)
	current_bid_label.text = "当前无人叫牌"
	current_bid_label.add_theme_font_size_override("font_size", 18)
	current_bid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bid_panel.add_child(current_bid_label)

	# 按钮容器（会根据可叫花色动态创建按钮）
	button_container = HBoxContainer.new()
	button_container.position = Vector2(40, 100)
	button_container.size = Vector2(400, 50)
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 15)
	bid_panel.add_child(button_container)

func show_bidding_options(available_suits: Array, suit_counts: Dictionary = {}):
	"""
	显示可以叫的花色选项
	available_suits: Array[Card.Suit] - 可以叫的花色列表
	suit_counts: Dictionary - 每个花色的等级牌数量 {Card.Suit: int}
	"""
	# 清空现有按钮
	for child in button_container.get_children():
		child.queue_free()

	visible = true

	# 为每个可叫的花色创建按钮
	for suit in available_suits:
		var btn = Button.new()
		# 如果提供了suit_counts，显示张数
		if suit_counts.has(suit):
			var count = suit_counts[suit]
			btn.text = "%s (%d张)" % [suit_names[suit], count]
		else:
			btn.text = suit_names[suit]
		btn.custom_minimum_size = Vector2(120, 40)
		btn.add_theme_font_size_override("font_size", 16)

		# 连接信号
		var suit_to_bid = suit
		var count_to_bid = suit_counts.get(suit, 1)
		btn.pressed.connect(func(): _on_suit_button_pressed(suit_to_bid, count_to_bid))

		button_container.add_child(btn)

	# 添加"不叫"按钮
	var pass_button = Button.new()
	pass_button.text = "不叫"
	pass_button.custom_minimum_size = Vector2(100, 40)
	pass_button.add_theme_font_size_override("font_size", 18)
	pass_button.pressed.connect(_on_pass_button_pressed)
	button_container.add_child(pass_button)

func hide_bidding_ui():
	"""隐藏叫牌界面"""
	visible = false

	# 清空按钮
	for child in button_container.get_children():
		child.queue_free()

func update_current_bid(message: String):
	"""更新当前叫牌信息"""
	current_bid_label.text = message

func _on_suit_button_pressed(suit: Card.Suit, count: int = 1):
	"""花色按钮被点击"""
	bid_made.emit(suit, count)
	hide_bidding_ui()

func _on_pass_button_pressed():
	"""不叫按钮被点击"""
	bid_passed.emit()
	hide_bidding_ui()

# 保留这些方法以兼容旧代码
func show_bidding_ui(can_bid: bool = true):
	"""显示叫牌界面（兼容方法）"""
	visible = can_bid

func enable_buttons(enabled: bool):
	"""启用/禁用所有按钮（兼容方法）"""
	for btn in button_container.get_children():
		if btn is Button:
			btn.disabled = not enabled
