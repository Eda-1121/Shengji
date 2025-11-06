# player.gd - 玩家类（唯一卡牌对象架构）
#
# 架构核心原则：
# 1. hand: Array[Card] 是唯一数据源（Single Source of Truth）
# 2. 每张 Card 对象从 Deck 创建后，在整个游戏流程中保持同一对象实例
# 3. 所有数组操作（append, erase, pop等）都是引用传递，不复制对象
# 4. Card.is_selected 属性直接存储选择状态，不使用独立数组
# 5. UI 层 (hand_container) 纯粹用于显示，从 hand 数组同步
#
extends Node2D
class_name Player

signal cards_played(cards: Array[Card])
signal card_selected(card: Card)
signal selection_changed(count: int)  # 新增:选牌数量变化信号

enum PlayerType { HUMAN, AI }

var player_id: int = 0
var player_name: String = "玩家"
var player_type: PlayerType = PlayerType.HUMAN
var team: int = 0
var current_rank: int = 2

var hand: Array[Card] = []  # 唯一数据源：存储 Card 对象引用（不是副本）
var is_dealer: bool = false

# UI相关
var hand_container: Node2D
var card_spacing: float = 35.0  # 卡牌间距（恢复原始值）
# 移除 selected_cards 数组 - 改用计算属性，从 hand 数组中筛选 is_selected=true 的卡牌

func _ready():
	hand_container = Node2D.new()
	hand_container.name = "HandContainer"
	add_child(hand_container)

func center_hand_container():
	"""将手牌容器居中显示在屏幕中央（仅对人类玩家）"""
	if player_type == PlayerType.HUMAN:
		# 获取屏幕大小
		var viewport_size = get_viewport_rect().size
		var screen_center_x = viewport_size.x / 2.0

		# hand_container 的位置是相对于 player 的
		# 要让手牌显示在屏幕中央，需要偏移
		# 例如：屏幕中心是640，玩家位置是200，所以需要偏移440
		hand_container.position.x = screen_center_x - position.x

		print("手牌容器居中设置：")
		print("  - 屏幕宽度: %d" % viewport_size.x)
		print("  - 屏幕中心X: %d" % screen_center_x)
		print("  - 玩家位置X: %d" % position.x)
		print("  - hand_container偏移X: %d" % hand_container.position.x)

# =====================================
# 卡牌选择管理（新架构：单一数据源）
# =====================================

func get_selected_cards() -> Array[Card]:
	"""获取所有选中的卡牌（计算属性，从 hand 数组筛选）"""
	var selected: Array[Card] = []
	for card in hand:
		if card.is_selected:
			selected.append(card)
	return selected

func get_selected_count() -> int:
	"""获取选中卡牌的数量"""
	var count = 0
	for card in hand:
		if card.is_selected:
			count += 1
	return count

func clear_selection():
	"""清除所有卡牌的选中状态（新架构）"""
	for card in hand:
		if card.is_selected:
			card.set_selected(false)
	selection_changed.emit(0)

# =====================================
# 卡牌管理
# =====================================

func receive_cards(cards: Array[Card]):
	"""接收卡牌（唯一对象架构：确保接收的是原始对象引用）"""
	for card in cards:
		# 验证：记录收到的卡牌对象ID
		if player_type == PlayerType.HUMAN and hand.size() < 3:  # 只在前3张时打印
			print("[receive_cards] %s 收到卡牌: %s 对象ID=%s" % [player_name, card.get_card_name(), card.get_instance_id()])

		# 验证卡牌对象唯一性（检查是否重复添加）
		if hand.has(card):
			print("⚠ 警告：尝试添加已存在的卡牌！%s (对象ID=%s)" % [card.get_card_name(), card.get_instance_id()])
			continue

		hand.append(card)  # 存储对象引用（不复制）

		if card.get_parent():
			card.get_parent().remove_child(card)
		hand_container.add_child(card)

		# 验证：确认卡牌已添加到hand_container
		if player_type == PlayerType.HUMAN and hand.size() <= 3:
			print("  → 已添加到hand数组，大小=%d，已添加到hand_container，parent=%s" % [hand.size(), card.get_parent().name if card.get_parent() else "无"])

		# 不在这里设置visible，由调用者控制
		# card.visible = true

		# 人类玩家的牌表面朝上显示
		if player_type == PlayerType.HUMAN:
			card.set_face_up(true, true)
			# 只有人类玩家的牌才可以点击
			if not card.card_clicked.is_connected(_on_card_clicked):
				card.card_clicked.connect(_on_card_clicked)

	sort_hand()
	update_hand_display()

func sort_hand(trump_last: bool = false, trump_suit: Card.Suit = Card.Suit.SPADE, current_rank: int = 2):
	"""
	排序手牌（验证：排序不会改变对象，只是重新排列顺序）
	trump_last: true = 主牌放最后（出牌阶段），false = 主牌放最前（默认）
	trump_suit: 主花色
	current_rank: 当前等级
	"""
	# 验证：记录排序前的对象ID（仅人类玩家，前3张）
	var before_ids = []
	if player_type == PlayerType.HUMAN and hand.size() > 0:
		for i in range(min(3, hand.size())):
			before_ids.append(hand[i].get_instance_id())

	hand.sort_custom(func(a, b):
		# 如果主牌放最后
		if trump_last:
			# 非主牌在前，主牌在后
			if a.is_trump != b.is_trump:
				return not a.is_trump  # 非主牌返回true，排在前面

			# 如果都不是主牌，按花色和点数排序
			if not a.is_trump:
				if a.suit != b.suit:
					return a.suit < b.suit
				return a.rank < b.rank

			# 都是主牌，需要按照特殊顺序排序
			# 判断牌的类型
			var a_type = _get_trump_type(a, trump_suit, current_rank)
			var b_type = _get_trump_type(b, trump_suit, current_rank)

			if a_type != b_type:
				return a_type < b_type

			# 同类型内部排序
			if a_type == 0:  # 主花色非等级牌
				return a.rank < b.rank
			elif a_type == 1:  # 非主花色等级牌
				return a.suit < b.suit
			# 其他类型（主花色等级牌、小王、大王）已经由type确定顺序
			return a.rank < b.rank
		else:
			# 默认排序：主牌在前
			if a.is_trump != b.is_trump:
				return a.is_trump
			if a.suit != b.suit:
				return a.suit < b.suit
			return a.rank < b.rank
	)

	# 验证：排序后对象ID是否还在（仅人类玩家）
	if player_type == PlayerType.HUMAN and before_ids.size() > 0:
		var all_ids_present = true
		for id in before_ids:
			var found = false
			for card in hand:
				if card.get_instance_id() == id:
					found = true
					break
			if not found:
				print("⚠ 警告：排序后对象ID %s 丢失！" % id)
				all_ids_present = false

		if not all_ids_present:
			print("⚠ 排序导致对象丢失！这不应该发生！")

func _get_trump_type(card: Card, trump_suit: Card.Suit, current_rank: int) -> int:
	"""
	获取主牌的类型，返回值越小越靠前
	0: 主花色的非等级牌
	1: 非主花色的等级牌
	2: 主花色的等级牌
	3: 小王
	4: 大王
	"""
	if card.suit == Card.Suit.JOKER:
		if card.rank == Card.Rank.SMALL_JOKER:
			return 3  # 小王
		else:
			return 4  # 大王

	if card.rank == current_rank:
		if card.suit == trump_suit:
			return 2  # 主花色等级牌
		else:
			return 1  # 非主花色等级牌

	if card.suit == trump_suit:
		return 0  # 主花色非等级牌

	# 不应该到这里，因为调用者已经确认是主牌
	return 5

func update_hand_display(animate: bool = true):
	"""更新手牌显示（新架构：纯UI布局，不管理状态）"""
	print("\n=== update_hand_display 开始 ===")
	print("hand数组大小：", hand.size())
	print("选中卡牌数：", get_selected_count())

	# 验证：显示 hand 数组的顺序（仅人类玩家，前10张）
	if player_type == PlayerType.HUMAN and hand.size() > 0:
		print("hand数组当前顺序（前10张）：")
		for i in range(min(10, hand.size())):
			var c = hand[i]
			print("  [%d] %s (对象ID=%s, is_selected=%s)" % [
				i, c.get_card_name(), c.get_instance_id(), c.is_selected
			])

	# 步骤1：同步 hand_container 与 hand 数组
	# 移除不在 hand 中的卡牌
	var to_remove = []
	for child in hand_container.get_children():
		if child is Card and not hand.has(child):
			to_remove.append(child)

	for card in to_remove:
		hand_container.remove_child(card)
		card.visible = false
		card.is_selectable = false

	# 添加 hand 中但不在 container 中的卡牌
	for card in hand:
		if card.get_parent() != hand_container:
			if card.get_parent():
				card.get_parent().remove_child(card)
			hand_container.add_child(card)

		# 确保卡牌可见和可选择
		card.visible = true
		card.is_selectable = true

		# 确保未选中的卡牌颜色正常
		if card.sprite and not card.is_selected:
			card.sprite.modulate = Color.WHITE

	# 步骤2：重新排列卡牌位置（居中对齐）
	var total_width = 0
	if hand.size() > 1:
		total_width = (hand.size() - 1) * card_spacing
	var start_offset = -total_width / 2.0

	for i in range(hand.size()):
		var card = hand[i]
		var target_pos = Vector2(start_offset + i * card_spacing, 0)
		var is_selected = card.is_selected

		if animate:
			if is_selected:
				var offset_pos = Vector2(target_pos.x, target_pos.y - 30)
				card.move_to_with_base(target_pos, offset_pos, 0.3)
			else:
				card.move_to(target_pos, 0.3)
		else:
			card.original_position = target_pos
			if is_selected:
				card.position = Vector2(target_pos.x, target_pos.y - 30)
			else:
				card.position = target_pos

		# z_index 管理
		if not is_selected:
			card.z_index = i

	print("=== update_hand_display 完成 ===\n")

func _on_card_clicked(card: Card):
	"""卡牌点击处理（新架构：只修改 card.is_selected 状态）"""
	if player_type != PlayerType.HUMAN:
		return

	# 检查卡牌是否在手牌中
	if not hand.has(card):
		print("⚠ 警告：点击的卡牌不在手牌中")
		print("  - 点击卡牌: %s (对象ID=%s)" % [card.get_card_name(), card.get_instance_id()])
		print("  - hand 数组前5张:")
		for i in range(min(5, hand.size())):
			var h = hand[i]
			print("    [%d] %s (对象ID=%s)" % [i, h.get_card_name(), h.get_instance_id()])
		return

	# 找到卡牌在 hand 数组中的索引
	var card_index = hand.find(card)

	print("\n========== [卡牌点击] ==========")
	print("点击卡牌: %s (对象ID=%s)" % [card.get_card_name(), card.get_instance_id()])
	print("  - 在hand数组中的索引: %d" % card_index)
	print("  - 卡牌位置: (%d, %d)" % [int(card.position.x), int(card.position.y)])
	print("  - 点击前 is_selected: %s" % card.is_selected)
	print("  - 当前选中总数: %d" % get_selected_count())

	# 显示 hand 数组的前5张和后5张
	print("  - hand数组前5张:")
	for i in range(min(5, hand.size())):
		var c = hand[i]
		var is_this = (c.get_instance_id() == card.get_instance_id())
		print("    [%d] %s (对象ID=%s) %s" % [
			i, c.get_card_name(), c.get_instance_id(), "← 当前点击" if is_this else ""
		])

	# 显示当前所有选中的卡牌（点击前）
	if get_selected_count() > 0:
		print("  - 点击前已选中的卡牌:")
		var selected = get_selected_cards()
		for i in range(selected.size()):
			var c = selected[i]
			print("    [%d] %s (对象ID=%s)" % [i, c.get_card_name(), c.get_instance_id()])

	# 切换选中状态
	if card.is_selected:
		print("  → 操作: 取消选中")
		card.set_selected(false)
		# 恢复原始z_index
		var index = hand.find(card)
		if index >= 0:
			card.z_index = index
	else:
		print("  → 操作: 选中")
		card.set_selected(true)
		# 提高z_index，确保选中的卡牌在最上层
		card.z_index = 1000 + get_selected_count()

	print("  - 点击后 is_selected: %s" % card.is_selected)
	print("  - 当前选中总数: %d" % get_selected_count())

	# 显示当前所有选中的卡牌（点击后）
	if get_selected_count() > 0:
		print("  - 点击后已选中的卡牌:")
		var selected = get_selected_cards()
		for i in range(selected.size()):
			var c = selected[i]
			print("    [%d] %s (对象ID=%s)" % [i, c.get_card_name(), c.get_instance_id()])
	print("================================\n")

	# 发出信号
	selection_changed.emit(get_selected_count())
	card_selected.emit(card)

func play_selected_cards() -> bool:
	"""出选中的牌（新架构：从 hand 中筛选）"""
	var cards_to_play = get_selected_cards()
	if cards_to_play.is_empty():
		return false

	return play_cards(cards_to_play)

func play_cards(cards: Array[Card]) -> bool:
	"""出牌并更新手牌显示（新架构）"""
	if not can_play_cards(cards):
		print("错误：无法出牌，部分卡牌不在手牌中")
		return false

	print("=== 开始出牌 ===")
	print("出牌前 - hand.size() = ", hand.size())
	print("准备出牌数量：", cards.size())

	for card in cards:
		print("出牌：", card.get_card_name())

		# 清除选中状态和样式
		if card.is_selected:
			card.is_selected = false
			if card.sprite:
				card.sprite.modulate = Color.WHITE

		# 设置为不可选择
		card.is_selectable = false

		# 断开信号连接
		if card.card_clicked.is_connected(_on_card_clicked):
			card.card_clicked.disconnect(_on_card_clicked)

		# 从手牌数组中移除（唯一数据源）
		hand.erase(card)

		# 从UI容器中移除
		if card.get_parent() == hand_container:
			hand_container.remove_child(card)

	print("出牌后 - hand.size() = ", hand.size())

	# 更新手牌显示
	update_hand_display(false)

	# 验证同步
	verify_hand_sync()

	# 发出信号
	cards_played.emit(cards)
	print("=== 出牌完成 ===")
	return true

func verify_hand_sync():
	"""验证hand数组和UI显示是否同步"""
	var ui_card_count = 0
	for child in hand_container.get_children():
		if child is Card:
			ui_card_count += 1

	if ui_card_count != hand.size():
		print("警告：手牌不同步！hand数组：", hand.size(), "张，UI显示：", ui_card_count, "张")
		print("强制同步手牌显示...")
		update_hand_display(false)
	else:
		print("验证通过：手牌同步正常，共 ", hand.size(), " 张")

func can_play_cards(cards: Array[Card]) -> bool:
	for card in cards:
		if not hand.has(card):
			return false
	return true

func get_valid_plays(lead_cards: Array[Card], _trump_suit: Card.Suit) -> Array:
	var valid_plays = []
	
	if lead_cards.is_empty():
		for card in hand:
			valid_plays.append([card])
	else:
		if hand.size() > 0:
			valid_plays.append([hand[0]])
	
	return valid_plays

func ai_play_turn(lead_cards: Array[Card], trump_suit: Card.Suit) -> Array[Card]:
	if player_type != PlayerType.AI:
		return []
	
	var valid_plays = get_valid_plays(lead_cards, trump_suit)
	if valid_plays.is_empty():
		return [hand[0]] if hand.size() > 0 else []
	
	return valid_plays[randi() % valid_plays.size()]

func get_hand_size() -> int:
	return hand.size()

func show_cards(face_up: bool = true):
	for card in hand:
		card.set_face_up(face_up)

func set_card_selectable(selectable: bool):
	for card in hand:
		card.is_selectable = selectable

# clear_selection() 已在上面第68行定义（新架构版本）
