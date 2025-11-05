# player.gd - 玩家类(改进版)
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

var hand: Array[Card] = []
var is_dealer: bool = false

# UI相关
var hand_container: Node2D
var card_spacing: float = 35.0  # 卡牌间距（恢复原始值）
var selected_cards: Array[Card] = []

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

func receive_cards(cards: Array[Card]):
	for card in cards:
		# 验证：记录收到的卡牌对象ID
		if player_type == PlayerType.HUMAN and hand.size() < 3:  # 只在前3张时打印
			print("[receive_cards] %s 收到卡牌: %s 对象ID=%s" % [player_name, card.get_card_name(), card.get_instance_id()])

		hand.append(card)

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
	排序手牌
	trump_last: true = 主牌放最后（出牌阶段），false = 主牌放最前（默认）
	trump_suit: 主花色
	current_rank: 当前等级
	"""
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
	"""更新手牌显示，确保与hand数组完全同步"""
	print("\n=== update_hand_display 开始 ===")
	print("调用栈：", get_stack())
	print("hand数组大小：", hand.size())
	print("hand_container子节点数：", hand_container.get_child_count())
	print("selected_cards大小（调用前）：", selected_cards.size())
	if selected_cards.size() > 0:
		print("selected_cards内容：")
		for i in range(selected_cards.size()):
			var c = selected_cards[i]
			print("  [%d] %s (对象ID=%s, is_selected=%s)" % [i, c.get_card_name(), c.get_instance_id(), c.is_selected])

	# 输出hand数组中的所有卡牌
	if hand.size() <= 5:  # 只在手牌少时详细输出
		print("hand数组内容：")
		for i in range(hand.size()):
			print("  [%d] %s" % [i, hand[i].get_card_name()])

	# 第一步：彻底清理hand_container中所有不在hand数组中的卡牌
	var to_remove = []
	for child in hand_container.get_children():
		if child is Card:
			if not hand.has(child):
				to_remove.append(child)

	for card in to_remove:
		print("移除不在hand数组中的卡牌：", card.get_card_name())
		hand_container.remove_child(card)
		card.visible = false  # 隐藏已出的牌
		card.is_selectable = false  # 确保不可选择

	# 第二步：确保hand数组中的所有卡牌都在hand_container中
	for card in hand:
		if card.get_parent() != hand_container:
			print("将卡牌添加到hand_container：", card.get_card_name())
			# 如果卡牌在其他父节点，先移除
			if card.get_parent():
				card.get_parent().remove_child(card)
			hand_container.add_child(card)

		# 确保卡牌可见和可选择（只对在手牌中的卡牌）
		card.visible = true
		card.is_selectable = true

		# 检查一致性：selected_cards数组和card.is_selected属性
		var in_selected_array = selected_cards.has(card)
		var has_selected_flag = card.is_selected
		if in_selected_array != has_selected_flag:
			print("  ⚠ 不一致！卡牌 %s (对象ID=%s): in_array=%s, flag=%s" % [
				card.get_card_name(), card.get_instance_id(), in_selected_array, has_selected_flag
			])
			print("    → 不自动修复，保留当前状态")
			# 移除自动修复逻辑，避免破坏用户选择

		# 确保卡牌颜色正常（清除任何残留的高亮）
		if card.sprite and not card.is_selected:
			card.sprite.modulate = Color.WHITE

	print("清理后 - hand_container子节点数：", hand_container.get_child_count())

	# 验证：检查hand数组和hand_container的一致性
	print("\n[一致性验证]")
	print("  - hand数组中的卡牌是否都在hand_container中？")
	for i in range(min(3, hand.size())):  # 只检查前3张
		var card = hand[i]
		var in_container = (card.get_parent() == hand_container)
		print("    [%d] %s (对象ID=%s) parent=%s in_container=%s" % [
			i, card.get_card_name(), card.get_instance_id(),
			card.get_parent().name if card.get_parent() else "无",
			in_container
		])

	print("  - hand_container中的卡牌是否都在hand数组中？")
	var container_child_count = 0
	for child in hand_container.get_children():
		if child is Card:
			if container_child_count < 3:  # 只打印前3个
				var in_hand = hand.has(child)
				print("    [%d] %s (对象ID=%s) in_hand=%s" % [
					container_child_count, child.get_card_name(), child.get_instance_id(), in_hand
				])
			container_child_count += 1

	# 第三步：重新排列所有手牌位置（居中对齐）
	# 计算居中偏移量
	var total_width = 0
	if hand.size() > 1:
		total_width = (hand.size() - 1) * card_spacing
	var start_offset = -total_width / 2.0  # 居中对齐的起始偏移量

	for i in range(hand.size()):
		var card = hand[i]
		var target_pos = Vector2(start_offset + i * card_spacing, 0)

		# 保存选中状态
		var was_selected = card.is_selected

		if animate:
			# 如果卡牌被选中，移动到偏移后的位置
			if was_selected:
				var offset_pos = Vector2(target_pos.x, target_pos.y - 30)  # SELECTED_HEIGHT = 30
				card.move_to_with_base(target_pos, offset_pos, 0.3)
			else:
				card.move_to(target_pos, 0.3)
		else:
			card.original_position = target_pos
			if was_selected:
				card.position = Vector2(target_pos.x, target_pos.y - 30)
			else:
				card.position = target_pos

		# 只对未选中的卡牌设置普通z_index，选中的卡牌保持高z_index
		if not was_selected:
			card.z_index = i
		# 如果卡牌被选中，保持其高z_index（在_on_card_clicked中设置的1000+）

	# 输出更新后的位置信息（只在手牌少时）
	if hand.size() <= 5:
		print("更新后的卡牌位置：")
		for i in range(hand.size()):
			var card = hand[i]
			print("  [%d] %s at pos(%d, %d) visible=%s selectable=%s" % [
				i, card.get_card_name(),
				int(card.position.x), int(card.position.y),
				card.visible, card.is_selectable
			])

	print("selected_cards大小（调用后）：", selected_cards.size())
	if selected_cards.size() > 0:
		print("selected_cards内容（调用后）：")
		for i in range(selected_cards.size()):
			var c = selected_cards[i]
			print("  [%d] %s (对象ID=%s, is_selected=%s, in_hand=%s)" % [i, c.get_card_name(), c.get_instance_id(), c.is_selected, hand.has(c)])
	print("=== update_hand_display 完成 ===\n")

func _on_card_clicked(card: Card):
	if player_type != PlayerType.HUMAN:
		return

	print("\n" + "=".repeat(60))
	print("[卡牌点击] 玩家点击了卡牌")
	print("=".repeat(60))
	print("  - 卡牌信息: %s (suit=%d, rank=%d, 对象ID=%s)" % [card.get_card_name(), card.suit, card.rank, card.get_instance_id()])
	print("  - 当前是否选中: %s" % ("是" if card.is_selected else "否"))
	print("  - 点击前selected_cards状态:")
	print("    - 数组大小: %d" % selected_cards.size())
	if selected_cards.size() > 0:
		print("    - 数组内容:")
		for i in range(selected_cards.size()):
			var c = selected_cards[i]
			print("      [%d] %s (对象ID=%s, is_selected=%s)" % [i, c.get_card_name(), c.get_instance_id(), c.is_selected])

	# 检查卡牌是否在手牌中（防止已出的牌被点击）
	if not hand.has(card):
		print("  ⚠ 警告：尝试选择不在手牌中的卡牌！")
		print("  - 点击的卡牌: %s (对象ID=%s)" % [card.get_card_name(), card.get_instance_id()])
		print("  - 手牌数组大小: %d" % hand.size())
		print("  - 手牌中的所有卡牌:")
		for i in range(hand.size()):
			var h_card = hand[i]
			var same_name = (h_card.get_card_name() == card.get_card_name())
			var same_id = (h_card.get_instance_id() == card.get_instance_id())
			print("    [%d] %s (对象ID=%s) 名字相同=%s 对象ID相同=%s" % [
				i, h_card.get_card_name(), h_card.get_instance_id(), same_name, same_id
			])
		print("  - 检查hand_container中的卡牌:")
		var container_index = 0
		for child in hand_container.get_children():
			if child is Card:
				var is_clicked_card = (child.get_instance_id() == card.get_instance_id())
				print("    [%d] %s (对象ID=%s) 是点击的卡牌=%s" % [
					container_index, child.get_card_name(), child.get_instance_id(), is_clicked_card
				])
				container_index += 1
		return

	if card.is_selected:
		print("  - 操作：取消选中")
		card.set_selected(false)
		selected_cards.erase(card)
		# 恢复原始z_index
		var index = hand.find(card)
		if index >= 0:
			card.z_index = index
	else:
		print("  - 操作：选中")
		card.set_selected(true)
		selected_cards.append(card)
		# 将选中的卡牌置于最前面
		card.z_index = 1000 + selected_cards.size()

	print("  - 点击后selected_cards状态:")
	print("    - 数组大小: %d" % selected_cards.size())
	if selected_cards.size() > 0:
		print("    - 数组内容:")
		for i in range(selected_cards.size()):
			var c = selected_cards[i]
			print("      [%d] %s (suit=%d, rank=%d, 对象ID=%s, is_selected=%s)" % [i, c.get_card_name(), c.suit, c.rank, c.get_instance_id(), c.is_selected])

	print("=".repeat(60) + "\n")

	# 发出选牌变化信号
	selection_changed.emit(selected_cards.size())
	card_selected.emit(card)

	# 验证：确认卡牌对象在数组中
	print("[验证] 验证selected_cards数组完整性:")
	for i in range(selected_cards.size()):
		var c = selected_cards[i]
		print("  [%d] 对象ID=%s %s (suit=%d, rank=%d) is_selected=%s" % [
			i, c.get_instance_id(), c.get_card_name(), c.suit, c.rank, c.is_selected
		])

func play_selected_cards() -> bool:
	if selected_cards.is_empty():
		return false

	# 复制一份，避免在play_cards中清空selected_cards影响cards参数
	var cards_to_play = selected_cards.duplicate()
	return play_cards(cards_to_play)

func play_cards(cards: Array[Card]) -> bool:
	"""出牌并更新手牌显示"""
	if not can_play_cards(cards):
		print("错误：无法出牌，部分卡牌不在手牌中")
		return false

	print("=== 开始出牌 ===")
	print("出牌前 - hand.size() = ", hand.size())
	print("准备出牌数量：", cards.size())

	# 记录要出的牌
	for card in cards:
		print("出牌：", card.get_card_name())

	for card in cards:
		# 立即取消选中状态（不使用动画，避免Tween冲突）
		if card.is_selected:
			card.is_selected = false
			if card.sprite:
				card.sprite.modulate = Color.WHITE  # 立即恢复颜色

		# 设置卡牌为不可选择
		card.is_selectable = false

		# 断开信号连接（避免已出的牌还能被点击）
		if card.card_clicked.is_connected(_on_card_clicked):
			card.card_clicked.disconnect(_on_card_clicked)

		# 从手牌数组中移除
		hand.erase(card)

		# 从UI容器中移除（重要：确保从UI中移除）
		if card.get_parent() == hand_container:
			hand_container.remove_child(card)
			print("从hand_container移除卡牌：", card.get_card_name())

		# 从选中列表中移除
		if selected_cards.has(card):
			selected_cards.erase(card)

	# 清空选中列表（以防万一）
	selected_cards.clear()

	print("出牌后 - hand.size() = ", hand.size())

	# 立即更新手牌显示（不使用动画，避免与出牌动画冲突）
	update_hand_display(false)

	# 验证：再次检查hand数组和UI是否同步
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

func clear_selection():
	"""清除所有选中的牌"""
	for card in selected_cards:
		card.set_selected(false)
	selected_cards.clear()
	selection_changed.emit(0)
