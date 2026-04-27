# game_manager.gd - Phase 2 完整版游戏管理器
extends Node

enum GamePhase { DEALING_AND_BIDDING, BURYING, PLAYING, SCORING }

var deck: Deck
var players: Array[Player] = []
var current_phase: GamePhase = GamePhase.DEALING_AND_BIDDING

# 牌副数选择（2副或4副）
var num_decks: int = 2

var trump_suit: Card.Suit = Card.Suit.SPADE
var current_level: int = 2
var dealer_index: int = 0
var current_player_index: int = 0

var bottom_cards: Array[Card] = []
var current_trick: Array = []
var team_scores: Array[int] = [0, 0]
var team_levels: Array[int] = [2, 2]

# 叫牌相关
var current_bid = {
	"team": -1,
	"suit": Card.Suit.SPADE,
	"count": 0,  # 叫牌张数(1=单张, 2=对子)
	"player_id": -1
}
var bidding_round: int = 0
var max_bidding_rounds: int = 8  # 每人最多叫2次

# 游戏统计
var total_rounds_played: int = 0

# 出牌区域 - 围绕屏幕中心(640, 360)的十字形布局，适配1280x720屏幕
var play_area_positions = [
	Vector2(560, 365),   # 玩家1（人类）- 下方中央
	Vector2(350, 350),   # 玩家2（AI）- 左侧中央
	Vector2(560, 255),   # 玩家3（AI）- 上方中央
	Vector2(820, 350)    # 玩家4（AI）- 右侧中央
]

# UI管理器引用
var ui_manager = null

# 叫牌决策等待标记
var waiting_for_bid_decision: bool = false
var bid_decision_made: bool = false

signal phase_changed(phase: GamePhase)
signal game_over(winner_team: int)

func _ready():
	print("=== GameManager 初始化 (Phase 2) ===")
	randomize()
	initialize_game()

func initialize_game():
	print("=== 初始化游戏：使用 ", num_decks, " 副牌 ===")
	# 玩家位置：玩家1在下方居中，其他AI玩家位置不变
	var player_positions = [
		Vector2(172, 558),   # 玩家1（人类）- 下方居中，给下方出牌按钮留出空间
		Vector2(50, 280),    # 玩家2（AI）- 左侧
		Vector2(100, 50),    # 玩家3（AI）- 上方
		Vector2(1050, 280)   # 玩家4（AI）- 右侧
	]
	
	for i in 4:
		var player = Player.new()
		player.player_id = i
		player.player_name = "玩家%d" % [i + 1]
		player.team = i % 2
		player.player_type = Player.PlayerType.AI if i > 0 else Player.PlayerType.HUMAN
		player.position = player_positions[i]
		players.append(player)
		add_child(player)
	
	start_new_round()

func cleanup_round_cards():
	"""清理上一局留下的牌，确保下一局使用全新的牌堆"""
	if deck:
		for card in deck.cards:
			free_card_node(card)
		deck.cards.clear()

	for play in current_trick:
		for card in play.get("cards", []):
			free_card_node(card)
	current_trick.clear()

	for card in bottom_cards:
		free_card_node(card)
	bottom_cards.clear()

	for player in players:
		player.is_dealer = false
		player.clear_selection()

		var hand_copy = player.hand.duplicate()
		for card in hand_copy:
			free_card_node(card)
		player.hand.clear()
		player.selected_cards.clear()

		if player.hand_container:
			for child in player.hand_container.get_children():
				if child is Card:
					free_card_node(child)

func free_card_node(card: Card):
	if card == null or not is_instance_valid(card):
		return
	if card.is_queued_for_deletion():
		return
	if card.get_parent():
		card.get_parent().remove_child(card)
	card.queue_free()

func start_new_round():
	print("=== 开始新一局 ===")
	total_rounds_played += 1

	# 重置游戏状态
	cleanup_round_cards()
	deck = Deck.new(num_decks)
	deck.create_deck()
	team_scores = [0, 0]
	current_bid = {
		"team": -1,
		"suit": Card.Suit.SPADE,
		"count": 0,
		"player_id": -1
	}
	bidding_round = 0
	current_phase = GamePhase.DEALING_AND_BIDDING
	current_player_index = dealer_index

	for player in players:
		player.current_rank = current_level

	# 步骤1: 洗牌
	print("步骤1: 洗牌")
	deck.shuffle()

	# 步骤2: 准备底牌（8张）
	print("步骤2: 准备底牌（8张）")
	bottom_cards.clear()
	for _i in 8:
		if deck.cards.size() > 0:
			bottom_cards.append(deck.cards.pop_back())
	print("底牌准备完成，剩余牌数：", deck.cards.size())

	players[dealer_index].is_dealer = true

	# 初始化UI
	if ui_manager:
		ui_manager.update_level(current_level)
		ui_manager.update_trump_suit("?")
		ui_manager.update_team_scores(0, 0)
		ui_manager.update_turn_message("正在发牌...")
		ui_manager.show_bury_button(false)
		ui_manager.set_buttons_enabled(false)

		# 显示叫牌UI（但按钮禁用）
		if ui_manager.has_node("BiddingUI"):
			var bidding_ui = ui_manager.get_node("BiddingUI")
			bidding_ui.show_bidding_ui(false)
			bidding_ui.update_current_bid("当前无人叫牌")

	phase_changed.emit(current_phase)

	# 步骤3: 开始逐张发牌（发牌过程中可以随时叫牌）
	print("步骤3: 开始发牌，发牌过程中可以随时叫牌")
	await get_tree().process_frame
	start_dealing_cards()

# =====================================
# 发牌系统
# =====================================

func start_dealing_cards():
	"""开始逐张发牌"""
	# 只显示人类玩家（玩家1）
	players[0].visible = true

	# 隐藏其他AI玩家的手牌
	for i in range(1, 4):
		players[i].visible = false

	var total_cards = deck.cards.size()
	var card_index = 0
	var current_player = dealer_index

	# 逐张发牌
	while deck.cards.size() > 0:
		var card = deck.cards.pop_back()
		var player = players[current_player]

		# 将牌发给玩家
		player.receive_cards([card])

		# 只有人类玩家的牌需要显示
		if player.player_type == Player.PlayerType.HUMAN:
			card.set_face_up(true, false)  # 人类玩家的牌正面朝上
			card.visible = true
			player.set_card_selectable(false)
		else:
			# AI玩家的牌完全不显示（不需要看到背面）
			card.visible = false
			player.set_card_selectable(false)

		card_index += 1

		# 更新UI显示发牌进度
		if ui_manager:
			ui_manager.update_turn_message("正在发牌... (%d/%d)" % [card_index, total_cards])

		# 检查该玩家是否可以叫牌
		await check_and_handle_bidding(player, card)

		# 下一个玩家
		current_player = (current_player + 1) % 4

		# 发牌延迟（让玩家看到发牌过程）
		await get_tree().create_timer(0.1).timeout

	# 发牌完成
	await finish_dealing()

func check_and_handle_bidding(player: Player, latest_card: Card):
	"""检查玩家是否可以叫牌，并处理叫牌"""
	# 检查玩家手里是否有当前级别的牌
	var level_cards = []
	for card in player.hand:
		if card.rank == current_level:
			level_cards.append(card)

	if level_cards.is_empty():
		return

	# 计算各个花色的等级牌数量
	var suit_counts = {}
	for card in level_cards:
		if not suit_counts.has(card.suit):
			suit_counts[card.suit] = 0
		suit_counts[card.suit] += 1

	# 找到最多的花色及张数
	var max_count = 0
	var max_suit = null
	for suit in suit_counts:
		if suit_counts[suit] > max_count:
			max_count = suit_counts[suit]
			max_suit = suit

	# 如果是人类玩家且拿到了当前级别的牌
	if player.player_type == Player.PlayerType.HUMAN and max_count > 0:
		# 收集所有可以叫的花色和对应的张数
		var available_suits = []
		var valid_suit_counts = {}
		for suit in suit_counts:
			var count = suit_counts[suit]
			# 检查该花色是否可以叫牌
			if can_make_bid(player, suit, count):
				available_suits.append(suit)
				valid_suit_counts[suit] = count

		if not available_suits.is_empty():
			# 显示叫牌UI，显示可以叫的花色和张数
			if ui_manager and ui_manager.has_node("BiddingUI"):
				var bidding_ui = ui_manager.get_node("BiddingUI")
				bidding_ui.show_bidding_options(available_suits, valid_suit_counts)

			# 设置等待标记
			waiting_for_bid_decision = true
			bid_decision_made = false

			# 等待玩家做出决策（叫牌或不叫）
			while waiting_for_bid_decision and not bid_decision_made:
				await get_tree().create_timer(0.1).timeout

			# 重置标记
			waiting_for_bid_decision = false

	# AI玩家自动叫牌逻辑
	elif player.player_type == Player.PlayerType.AI:
		# AI会根据手中等级牌的数量决定是否叫牌
		if max_count > 0 and can_make_bid(player, max_suit, max_count):
			# 如果AI有足够多的等级牌，就叫牌
			# AI策略：至少2张才叫（除非还没人叫牌）
			if max_count >= 2 or current_bid["count"] == 0:
				make_bid(player, max_suit, max_count)
				print("AI ", player.player_name, " 叫牌：", max_count, " 张")

func finish_dealing():
	"""发牌完成，进行最后一次叫牌机会，然后确定主牌"""
	print("=== finish_dealing() 被调用 ===")
	print("步骤4: 发牌结束，检查是否有最后叫牌机会")

	if ui_manager:
		ui_manager.update_turn_message("发牌完成，最后叫牌机会...")

	# 步骤4: 发牌结束后的最后叫牌机会
	# 检查所有玩家是否有更多等级牌可以反叫
	await check_final_bidding_opportunity()

	# 步骤5: 确定主牌和庄家
	print("步骤5: 确定主牌和庄家")
	if ui_manager and ui_manager.has_node("BiddingUI"):
		var bidding_ui = ui_manager.get_node("BiddingUI")
		bidding_ui.hide_bidding_ui()

	# 如果没人叫牌，默认庄家队叫黑桃
	if current_bid["count"] == 0:
		trump_suit = Card.Suit.SPADE
		current_bid["suit"] = trump_suit
		current_bid["team"] = players[dealer_index].team
		current_bid["player_id"] = dealer_index
		print("没人叫牌，默认庄家队叫黑桃")
	else:
		trump_suit = current_bid["suit"]
		dealer_index = current_bid["player_id"]  # 叫到主的人成为庄家
		print("叫牌成功！新庄家：", players[dealer_index].player_name, " (player_id=", dealer_index, ")")

	if ui_manager:
		ui_manager.update_trump_suit(get_trump_symbol())
		ui_manager.show_center_message("队伍%d 叫到主: %s" % [current_bid["team"] + 1, get_trump_symbol()], 2.0)

	await get_tree().create_timer(2.0).timeout

	# 步骤6: 进入埋底阶段
	print("步骤6: 进入埋底阶段")
	if players[dealer_index].player_type == Player.PlayerType.HUMAN:
		print("庄家是人类玩家，进入人类埋底阶段")
		start_burying_phase()
	else:
		print("庄家是AI玩家，进入AI埋底阶段")
		await ai_bury_bottom()

# =====================================
# 叫牌系统
# =====================================

func check_final_bidding_opportunity():
	"""发牌结束后的最后叫牌机会"""
	print("检查所有玩家是否有最后叫牌机会...")

	# 检查每个玩家手中的等级牌数量
	for player in players:
		var level_cards = []
		for card in player.hand:
			if card.rank == current_level:
				level_cards.append(card)

		if level_cards.is_empty():
			continue

		# 计算各个花色的等级牌数量
		var suit_counts = {}
		for card in level_cards:
			if not suit_counts.has(card.suit):
				suit_counts[card.suit] = 0
			suit_counts[card.suit] += 1

		# 找到最多的花色及张数
		var max_count = 0
		var max_suit = null
		for suit in suit_counts:
			if suit_counts[suit] > max_count:
				max_count = suit_counts[suit]
				max_suit = suit

		# 检查是否可以反叫（需要比当前叫牌更多的牌）
		if max_count > current_bid["count"]:
			print(player.player_name, " 有 ", max_count, " 张等级牌，可以反叫")

			if player.player_type == Player.PlayerType.HUMAN:
				# 人类玩家，显示叫牌UI
				var available_suits = []
				var valid_suit_counts = {}
				for suit in suit_counts:
					var count = suit_counts[suit]
					if count > current_bid["count"]:
						available_suits.append(suit)
						valid_suit_counts[suit] = count

				if not available_suits.is_empty():
					if ui_manager and ui_manager.has_node("BiddingUI"):
						var bidding_ui = ui_manager.get_node("BiddingUI")
						bidding_ui.show_bidding_options(available_suits, valid_suit_counts)
						ui_manager.show_center_message("最后叫牌机会！", 2.0)

					# 等待玩家决策
					waiting_for_bid_decision = true
					bid_decision_made = false
					while waiting_for_bid_decision and not bid_decision_made:
						await get_tree().create_timer(0.1).timeout
					waiting_for_bid_decision = false
			else:
				# AI玩家，自动判断是否反叫
				if max_count > current_bid["count"] + 1:  # AI只在有明显优势时反叫
					print("AI ", player.player_name, " 决定反叫")
					make_bid(player, max_suit, max_count)
					await get_tree().create_timer(2.0).timeout
				else:
					print("AI ", player.player_name, " 放弃反叫")

	print("最后叫牌机会结束")

func start_bidding_phase():
	"""开始叫牌阶段"""
	current_player_index = dealer_index
	process_bidding_turn()

func process_bidding_turn():
	"""处理当前玩家的叫牌轮次"""
	if bidding_round >= max_bidding_rounds:
		# 叫牌结束
		finish_bidding()
		return
	
	var current_player = players[current_player_index]
	
	if ui_manager:
		ui_manager.update_turn_message("%s 叫牌中..." % current_player.player_name)

	if current_player.player_type == Player.PlayerType.HUMAN:
		# 人类玩家，等待UI输入
		if ui_manager and ui_manager.has_node("BiddingUI"):
			var bidding_ui = ui_manager.get_node("BiddingUI")
			bidding_ui.enable_buttons(true)
	else:
		# AI玩家，自动叫牌
		await get_tree().create_timer(1.5).timeout
		ai_make_bid(current_player)

func _on_player_bid_made(suit: Card.Suit, count: int):
	"""玩家做出叫牌"""
	# 在发牌阶段，玩家1（人类）叫牌
	var player = players[0]

	# 验证叫牌是否有效
	if not can_make_bid(player, suit, count):
		if ui_manager:
			ui_manager.show_center_message("叫牌无效!", 1.5)
		return

	# 执行叫牌
	make_bid(player, suit, count)

	# 禁用叫牌按钮
	if ui_manager and ui_manager.has_node("BiddingUI"):
		var bidding_ui = ui_manager.get_node("BiddingUI")
		bidding_ui.enable_buttons(false)

	# 设置决策完成标记，通知继续发牌
	bid_decision_made = true

func _on_player_bid_passed():
	"""玩家选择不叫"""
	# 禁用叫牌按钮
	if ui_manager and ui_manager.has_node("BiddingUI"):
		var bidding_ui = ui_manager.get_node("BiddingUI")
		bidding_ui.enable_buttons(false)

	# 设置决策完成标记，通知继续发牌
	bid_decision_made = true

func can_make_bid(player: Player, suit: Card.Suit, count: int) -> bool:
	"""
	检查是否可以叫牌
	规则：
	- 第一次叫牌只需要1张等级牌
	- 后续叫牌需要比当前叫牌更多的等级牌（count > current_bid["count"]）
	- 同队加固：相同花色，更多张数
	- 反主：不同队，更多张数（任意花色）
	"""
	# 如果还没有人叫牌，只需要至少1张等级牌
	if current_bid["count"] == 0:
		return count >= 1

	# 如果已经有人叫牌，需要更多的等级牌才能反叫
	# 1. 同队加固：相同花色，更多张数
	if player.team == current_bid["team"]:
		if suit == current_bid["suit"] and count > current_bid["count"]:
			return true

	# 2. 反主：不同队，更多张数（任意花色）
	if player.team != current_bid["team"]:
		if count > current_bid["count"]:
			return true

	# 3. 无主特殊规则：小王=1张无主，大王=2张无主（最大）
	if suit == Card.Suit.JOKER:
		return count > current_bid["count"]

	return false

func make_bid(player: Player, suit: Card.Suit, count: int):
	"""执行叫牌"""
	current_bid = {
		"team": player.team,
		"suit": suit,
		"count": count,
		"player_id": player.player_id
	}
	
	var suit_name = get_suit_name(suit)

	if ui_manager:
		var message = "%s 叫 %s" % [player.player_name, suit_name]
		ui_manager.show_center_message(message, 2.0)
		
		if ui_manager.has_node("BiddingUI"):
			var bidding_ui = ui_manager.get_node("BiddingUI")
			bidding_ui.update_current_bid("当前: %s - %s" % [player.player_name, suit_name])

func ai_make_bid(ai_player: Player):
	"""AI叫牌逻辑"""
	# 简化AI：检查手牌中当前级别的牌
	var level_cards = []
	for card in ai_player.hand:
		if card.rank == current_level:
			level_cards.append(card)
	
	# 如果有当前级别的对子，考虑叫牌或反主
	if level_cards.size() >= 2:
		var suit_counts = {}
		for card in level_cards:
			if not suit_counts.has(card.suit):
				suit_counts[card.suit] = 0
			suit_counts[card.suit] += 1
		
		# 找到对子
		for suit in suit_counts:
			if suit_counts[suit] >= 2:
				# 检查是否可以叫牌
				if can_make_bid(ai_player, suit, 2):
					make_bid(ai_player, suit, 2)
					next_bidding_turn()
					return
	
	# 如果有单张且还没人叫，就叫
	if level_cards.size() >= 1 and current_bid["count"] == 0:
		make_bid(ai_player, level_cards[0].suit, 1)
		next_bidding_turn()
		return
	
	# 否则不叫
	next_bidding_turn()

func next_bidding_turn():
	"""下一个叫牌轮次"""
	bidding_round += 1
	current_player_index = (current_player_index + 1) % 4
	
	# 禁用UI按钮
	if ui_manager and ui_manager.has_node("BiddingUI"):
		var bidding_ui = ui_manager.get_node("BiddingUI")
		bidding_ui.enable_buttons(false)
	
	await get_tree().create_timer(0.5).timeout
	process_bidding_turn()

func finish_bidding():
	"""结束叫牌阶段"""
	# 隐藏叫牌UI
	if ui_manager and ui_manager.has_node("BiddingUI"):
		var bidding_ui = ui_manager.get_node("BiddingUI")
		bidding_ui.hide_bidding_ui()
	
	# 如果没人叫牌，默认庄家队叫黑桃
	if current_bid["count"] == 0:
		trump_suit = Card.Suit.SPADE
		current_bid["suit"] = trump_suit
		current_bid["team"] = players[dealer_index].team
		current_bid["player_id"] = dealer_index
	else:
		trump_suit = current_bid["suit"]
		dealer_index = current_bid["player_id"]  # 叫到主的人成为庄家
	
	if ui_manager:
		ui_manager.update_trump_suit(get_trump_symbol())
		ui_manager.show_center_message("队伍%d 叫到主: %s" % [current_bid["team"] + 1, get_trump_symbol()], 2.0)
	
	await get_tree().create_timer(2.0).timeout
	
	# 进入埋底阶段
	if players[dealer_index].player_type == Player.PlayerType.HUMAN:
		start_burying_phase()
	else:
		await ai_bury_bottom()

func get_suit_name(suit: Card.Suit) -> String:
	"""获取花色名称"""
	match suit:
		Card.Suit.SPADE: return "黑桃♠"
		Card.Suit.HEART: return "红心♥"
		Card.Suit.CLUB: return "梅花♣"
		Card.Suit.DIAMOND: return "方片♦"
		Card.Suit.JOKER: return "无主👑"
		_: return "?"

# =====================================
# 埋底阶段
# =====================================

func start_burying_phase():
	"""开始埋底阶段"""
	print("=== start_burying_phase() 被调用 ===")
	print("当前阶段变更为：BURYING")
	current_phase = GamePhase.BURYING

	var dealer = players[dealer_index]
	print("庄家：", dealer.player_name, " 收到底牌，手牌数：", dealer.hand.size())

	dealer.receive_cards(bottom_cards, false)
	bottom_cards.clear()
	dealer.sort_hand(true, trump_suit, current_level)
	dealer.update_hand_display()
	dealer.clear_selection()
	dealer.set_card_selectable(true)

	print("底牌发放完成，庄家手牌数：", dealer.hand.size())

	if ui_manager:
		ui_manager.update_turn_message("庄家埋底 - 请选择8张牌作为底牌")
		ui_manager.show_center_message("庄家请选择8张牌扣底", 2.0)
		ui_manager.show_bury_button(true)
		ui_manager.set_bury_button_enabled(false)
		ui_manager.update_selected_count(0, 8)

func _on_bury_cards_pressed():
	"""玩家点击埋底按钮"""
	print("=== _on_bury_cards_pressed() 被调用 ===")
	print("当前阶段：", current_phase)

	if current_phase != GamePhase.BURYING:
		print("警告：当前不是埋底阶段，忽略埋底操作")
		return

	var dealer = players[dealer_index]

	if dealer.selected_cards.size() != 8:
		print("选中的牌数量不对：", dealer.selected_cards.size(), " 需要8张")
		if ui_manager:
			ui_manager.show_center_message("请选择正好8张牌!", 1.5)
		return

	print("埋底操作：从 ", dealer.hand.size(), " 张手牌中移除 8 张")

	for card in dealer.selected_cards:
		bottom_cards.append(card)
		dealer.hand.erase(card)
		if card.is_selected:
			card.is_selected = false
			if card.sprite:
				card.sprite.modulate = Color.WHITE
		if card.get_parent():
			card.get_parent().remove_child(card)
		card.is_selectable = false
		card.visible = false

	dealer.selected_cards.clear()
	dealer.update_hand_display()
	dealer.set_card_selectable(false)

	print("埋底完成，庄家剩余手牌：", dealer.hand.size())

	if ui_manager:
		ui_manager.show_bury_button(false)
		ui_manager.show_center_message("埋底完成", 1.5)

	print("等待1.5秒后进入出牌阶段...")
	await get_tree().create_timer(1.5).timeout
	print("调用 start_playing_phase()")
	await start_playing_phase()

func auto_bury_for_player(dealer: Player):
	"""自动埋底"""
	var sorted_hand = dealer.hand.duplicate()
	sorted_hand.sort_custom(func(a, b): 
		a.set_trump(trump_suit, current_level)
		b.set_trump(trump_suit, current_level)
		return a.compare_to(b, trump_suit, current_level) < 0
	)
	
	for i in range(min(8, sorted_hand.size())):
		var card = sorted_hand[i]
		bottom_cards.append(card)
		dealer.hand.erase(card)
		if card.get_parent():
			card.get_parent().remove_child(card)
		card.is_selectable = false
		card.visible = false
	
	dealer.update_hand_display()

	if ui_manager:
		ui_manager.show_center_message("埋底完成", 1.5)
	
	await get_tree().create_timer(1.5).timeout
	await start_playing_phase()

func ai_bury_bottom():
	"""AI埋底"""
	print("=== ai_bury_bottom() 被调用 ===")
	current_phase = GamePhase.BURYING
	for player in players:
		player.set_card_selectable(false)
	if ui_manager:
		ui_manager.update_turn_message("AI庄家正在埋底...")
		ui_manager.show_bury_button(false)
		ui_manager.set_buttons_enabled(false)

	var dealer = players[dealer_index]
	print("AI庄家：", dealer.player_name, " 开始埋底")

	dealer.receive_cards(bottom_cards, false)
	bottom_cards.clear()
	dealer.sort_hand(true, trump_suit, current_level)
	dealer.update_hand_display()

	print("等待1.5秒...")
	await get_tree().create_timer(1.5).timeout
	print("调用 auto_bury_for_player()")
	await auto_bury_for_player(dealer)

# =====================================
# 出牌阶段
# =====================================

func start_playing_phase():
	"""开始出牌阶段"""
	print("=== start_playing_phase() 被调用 ===")
	print("当前阶段变更为：PLAYING")
	current_phase = GamePhase.PLAYING

	# 重新整理所有玩家的手牌（主牌放最后）
	for player in players:
		player.current_rank = current_level
		# 设置所有牌的主牌状态
		for card in player.hand:
			card.set_trump(trump_suit, current_level)
		# 重新排序：主牌和当前级别的牌放在最后，按正确顺序排列
		player.sort_hand(true, trump_suit, current_level)
		# 更新显示
		player.update_hand_display(true)

	current_player_index = dealer_index
	print("庄家（叫牌成功的玩家）：", players[dealer_index].player_name, " (player_id=", dealer_index, ")")
	print("首先出牌的玩家：", players[current_player_index].player_name)

	if ui_manager:
		ui_manager.update_turn_message("轮到 %s 出牌" % players[current_player_index].player_name)
		ui_manager.highlight_current_player(current_player_index)
		ui_manager.show_bury_button(false)

	phase_changed.emit(current_phase)
	update_turn_interaction()

	if players[current_player_index].player_type == Player.PlayerType.AI:
		print("首位出牌的是AI，等待1秒后让AI出牌")
		await get_tree().create_timer(1.0).timeout
		ai_play_turn(players[current_player_index])
	else:
		print("首位出牌的是人类玩家，等待玩家操作")

func get_trump_symbol() -> String:
	match trump_suit:
		Card.Suit.SPADE: return "♠"
		Card.Suit.HEART: return "♥"
		Card.Suit.CLUB: return "♣"
		Card.Suit.DIAMOND: return "♦"
		Card.Suit.JOKER: return "👑"
		_: return "?"

func get_team_name(team: int) -> String:
	return "队伍%d" % [team + 1]

func get_current_player() -> Player:
	return players[current_player_index]

func update_turn_interaction():
	"""根据当前阶段和当前玩家启用人类玩家交互"""
	var human_player = players[0]
	var human_turn = current_phase == GamePhase.PLAYING and current_player_index == 0

	for player in players:
		player.set_card_selectable(player == human_player and human_turn)

	update_action_controls()

func on_human_selection_changed(_count: int):
	"""人类玩家选牌变化后刷新操作按钮状态"""
	update_action_controls()

func update_action_controls():
	if ui_manager == null or players.is_empty():
		return

	if current_phase == GamePhase.BURYING:
		var dealer = players[dealer_index]
		if dealer.player_type == Player.PlayerType.HUMAN:
			ui_manager.update_selected_count(dealer.selected_cards.size(), 8)
			ui_manager.set_bury_button_enabled(dealer.selected_cards.size() == 8)
		ui_manager.set_buttons_enabled(false)
		return

	if current_phase == GamePhase.PLAYING:
		ui_manager.set_buttons_enabled(is_human_selected_play_valid())
		return

	ui_manager.set_buttons_enabled(false)

func is_human_selected_play_valid() -> bool:
	if players.is_empty():
		return false
	if current_phase != GamePhase.PLAYING or current_player_index != 0:
		return false

	var human_player = players[0]
	if human_player.selected_cards.is_empty():
		return false

	for card in human_player.selected_cards:
		card.set_trump(trump_suit, current_level)

	if not GameRules.validate_play(human_player.selected_cards, human_player.hand):
		return false

	var pattern = GameRules.identify_pattern(human_player.selected_cards, trump_suit, current_level)
	if pattern.pattern_type == GameRules.CardPattern.INVALID:
		return false

	if current_trick.is_empty():
		if pattern.pattern_type == GameRules.CardPattern.THROW:
			return validate_throw(human_player, pattern)
		return true

	var lead_pattern = current_trick[0]["pattern"]
	return GameRules.can_follow(pattern, lead_pattern, human_player.hand, trump_suit, current_level)

func _on_play_cards_pressed():
	"""出牌按钮被点击"""
	if current_phase != GamePhase.PLAYING:
		return

	var human_player = players[0]
	if current_player_index != human_player.player_id:
		if ui_manager:
			ui_manager.show_center_message("还没轮到你出牌", 1.0)
		return

	if human_player.selected_cards.is_empty():
		if ui_manager:
			ui_manager.show_center_message("请先选择要出的牌!", 1.5)
		return

	if not is_human_selected_play_valid():
		if ui_manager:
			ui_manager.show_center_message("选择的牌不符合出牌规则!", 1.5)
		update_action_controls()
		return
	
	for card in human_player.selected_cards:
		card.set_trump(trump_suit, current_level)
	
	var pattern = GameRules.identify_pattern(human_player.selected_cards, trump_suit, current_level)

	if not GameRules.validate_play(human_player.selected_cards, human_player.hand):
		if ui_manager:
			ui_manager.show_center_message("无效的出牌!", 1.5)
		return
	
	if current_trick.is_empty():
		# 首家出牌
		if pattern.pattern_type == GameRules.CardPattern.THROW:
			# 甩牌需要验证
			if not validate_throw(human_player, pattern):
				if ui_manager:
					ui_manager.show_center_message("甩牌失败! 其他人能管上", 2.0)
				update_action_controls()
				return
		
		if human_player.play_selected_cards():
			show_played_cards(0, pattern.cards)
			
			current_trick.append({
				"player_id": human_player.player_id,
				"cards": pattern.cards,
				"pattern": pattern
			})


			if ui_manager:
				ui_manager.show_center_message("出牌成功!", 1.0)

			next_player_turn()
		else:
			if ui_manager:
				ui_manager.show_center_message("出牌失败!", 1.5)
	else:
		# 跟牌
		var lead_pattern = current_trick[0]["pattern"]
		
		if not GameRules.can_follow(pattern, lead_pattern, human_player.hand, trump_suit, current_level):
			if ui_manager:
				ui_manager.show_center_message("跟牌不符合规则!", 1.5)
			return
		
		if human_player.play_selected_cards():
			show_played_cards(0, pattern.cards)
			
			current_trick.append({
				"player_id": human_player.player_id,
				"cards": pattern.cards,
				"pattern": pattern
			})
			
			if ui_manager:
				ui_manager.show_center_message("跟牌成功!", 1.0)
			
			if current_trick.size() == 4:
				evaluate_trick()
			else:
				next_player_turn()

func validate_throw(player: Player, throw_pattern: GameRules.PlayPattern) -> bool:
	"""验证甩牌是否成功"""
	# 检查其他三家是否都管不上
	for i in range(1, 4):
		var other_player = players[(player.player_id + i) % 4]
		
		# 更新手牌主牌状态
		for card in other_player.hand:
			card.set_trump(trump_suit, current_level)
		
		# 检查是否能管上甩出的任何一张牌
		for throw_card in throw_pattern.cards:
			for hand_card in other_player.hand:
				if can_beat_card(hand_card, throw_card):
					return false

	return true

func can_beat_card(card1: Card, card2: Card) -> bool:
	"""检查card1是否能打过card2"""
	return card1.compare_to(card2, trump_suit, current_level) > 0

func show_played_cards(player_id: int, cards: Array):
	"""显示出的牌"""
	var position = play_area_positions[player_id]

	for i in range(cards.size()):
		var card = cards[i]
		# 确保牌从原父节点移除并添加到game_manager
		if card.get_parent():
			card.get_parent().remove_child(card)
		add_child(card)

		# 使用全局坐标，确保牌显示在正确的屏幕位置
		card.global_position = position + Vector2(i * 24, 0)
		card.z_index = 100
		card.visible = true
		card.set_face_up(true, true)

		# 禁用已出牌的交互事件
		card.is_selectable = false

func next_player_turn():
	"""下一个玩家"""
	current_player_index = (current_player_index + 1) % 4
	var current_player = players[current_player_index]
	
	if ui_manager:
		ui_manager.update_turn_message("轮到 %s 出牌" % current_player.player_name)
		ui_manager.highlight_current_player(current_player_index)
	update_turn_interaction()
	
	if current_player.player_type == Player.PlayerType.AI:
		await get_tree().create_timer(1.5).timeout
		ai_play_turn(current_player)

func ai_play_turn(ai_player: Player):
	"""AI出牌"""
	print("=== ai_play_turn() 被调用 ===")
	print("AI玩家：", ai_player.player_name, " (player_id=", ai_player.player_id, ")")
	print("当前阶段：", current_phase)

	# 安全检查：确保在出牌阶段才能出牌
	if current_phase != GamePhase.PLAYING:
		print("警告：当前不是出牌阶段，AI不能出牌！")
		return

	for card in ai_player.hand:
		card.set_trump(trump_suit, current_level)
	
	var cards_to_play: Array = []
	
	if current_trick.is_empty():
		# 首家出牌：出最大的单张
		if ai_player.hand.size() > 0:
			var sorted_hand = ai_player.hand.duplicate()
			sorted_hand.sort_custom(func(a, b): 
				return a.compare_to(b, trump_suit, current_level) > 0
			)
			cards_to_play = [sorted_hand[0]]
	else:
		# 跟牌
		var lead_pattern = current_trick[0]["pattern"]
		var valid_plays = GameRules.get_valid_follow_cards(ai_player.hand, lead_pattern, trump_suit, current_level)
		
		if valid_plays.size() > 0:
			cards_to_play = valid_plays[0]
		elif ai_player.hand.size() >= lead_pattern.length:
			var sorted_hand = ai_player.hand.duplicate()
			sorted_hand.sort_custom(func(a, b): 
				return a.compare_to(b, trump_suit, current_level) < 0
			)
			cards_to_play = sorted_hand.slice(0, lead_pattern.length)
	
	if cards_to_play.size() > 0:
		for card in cards_to_play:
			ai_player.hand.erase(card)
			if card.get_parent() == ai_player.hand_container:
				ai_player.hand_container.remove_child(card)
		
		ai_player.update_hand_display()
		
		var cards_array: Array[Card] = []
		for card in cards_to_play:
			cards_array.append(card)
		
		show_played_cards(ai_player.player_id, cards_array)
		
		var pattern = GameRules.identify_pattern(cards_array, trump_suit, current_level)
		current_trick.append({
			"player_id": ai_player.player_id,
			"cards": cards_array,
			"pattern": pattern
		})

		if current_trick.size() == 4:
			await get_tree().create_timer(1.0).timeout
			evaluate_trick()
		else:
			next_player_turn()

func evaluate_trick():
	"""评估本轮"""
	print("=== 评估本轮 ===")
	for player in players:
		player.set_card_selectable(false)
	if ui_manager:
		ui_manager.set_buttons_enabled(false)

	print("当前回合出牌顺序：")
	for i in range(current_trick.size()):
		var play = current_trick[i]
		print("  ", i+1, ". ", players[play["player_id"]].player_name, " 出了 ", play["cards"].size(), " 张牌")

	var lead_play = current_trick[0]
	var winner_play = lead_play

	for i in range(1, current_trick.size()):
		var current_play = current_trick[i]
		var compare_result = GameRules.compare_plays(winner_play["pattern"], current_play["pattern"], trump_suit, current_level)

		if compare_result < 0:
			winner_play = current_play

	var winner = players[winner_play["player_id"]]
	print("本轮赢家：", winner.player_name, " (player_id=", winner_play["player_id"], ")")

	var points = 0
	for play in current_trick:
		points += GameRules.calculate_points(play["cards"])

	team_scores[winner.team] += points

	if ui_manager:
		ui_manager.update_team_scores(team_scores[0], team_scores[1])
		ui_manager.show_center_message("%s 赢得本轮，得 %d 分" % [winner.player_name, points], 2.0)

	await get_tree().create_timer(2.0).timeout

	for play in current_trick:
		for card in play["cards"]:
			if is_instance_valid(card) and card.get_parent():
				card.queue_free()

	current_trick.clear()
	
	if players[0].get_hand_size() == 0:
		await get_tree().create_timer(1.0).timeout
		
		var bottom_points = GameRules.calculate_points(bottom_cards)
		var multiplier = 2


		if winner.team == current_bid["team"]:
			team_scores[current_bid["team"]] += bottom_points * multiplier
			if ui_manager:
				ui_manager.show_center_message("庄家队扣底成功!+%d分" % [bottom_points * multiplier], 2.0)
				ui_manager.update_team_scores(team_scores[0], team_scores[1])
		else:
			var opponent_team = 1 - current_bid["team"]
			team_scores[opponent_team] += bottom_points * multiplier
			if ui_manager:
				ui_manager.show_center_message("对手队抠底成功!+%d分" % [bottom_points * multiplier], 2.0)
				ui_manager.update_team_scores(team_scores[0], team_scores[1])
		
		await get_tree().create_timer(2.0).timeout
		end_round()
	else:
		current_player_index = winner_play["player_id"]
		print("下一轮由赢家先出牌：", players[current_player_index].player_name, " (player_id=", current_player_index, ")")
		await get_tree().create_timer(1.0).timeout

		if ui_manager:
			ui_manager.update_turn_message("轮到 %s 出牌" % players[current_player_index].player_name)
			ui_manager.highlight_current_player(current_player_index)
		update_turn_interaction()

		if players[current_player_index].player_type == Player.PlayerType.AI:
			await get_tree().create_timer(1.0).timeout
			ai_play_turn(players[current_player_index])

# =====================================
# 结束和升级
# =====================================

func end_round():
	"""本局结束，计算升级"""
	current_phase = GamePhase.SCORING

	print("=== 本局结束，开始计算升级 ===")
	var dealer_team = current_bid["team"]  # 庄家队（叫牌成功的队）
	var attacker_team = 1 - dealer_team    # 对手队（闲家）
	var attacker_score = team_scores[attacker_team]  # 对手队得分

	print("庄家队：队伍", dealer_team + 1, " 得分：", team_scores[dealer_team])
	print("对手队：队伍", attacker_team + 1, " 得分：", attacker_score)

	var levels_to_advance = 0
	var winning_team = -1

	# 标准升级规则（根据对手队得分）：
	# 对手得分 < 40分：庄家升3级
	# 对手得分 40-75分：庄家升2级
	# 对手得分 80-115分：庄家升1级
	# 对手得分 120-155分：对手升1级，庄家换到对手队
	# 对手得分 160-195分：对手升2级，庄家换到对手队
	# 对手得分 ≥ 200分：对手升3级，庄家换到对手队

	if attacker_score >= 200:
		# 对手升3级
		levels_to_advance = 3
		winning_team = attacker_team
		team_levels[attacker_team] += levels_to_advance
		dealer_index = (dealer_index + 1) % 4  # 庄家换到对手队
		if ui_manager:
			ui_manager.show_center_message("队伍%d 大胜！升%d级！" % [attacker_team + 1, levels_to_advance], 3.0)
	elif attacker_score >= 160:
		# 对手升2级
		levels_to_advance = 2
		winning_team = attacker_team
		team_levels[attacker_team] += levels_to_advance
		dealer_index = (dealer_index + 1) % 4
		if ui_manager:
			ui_manager.show_center_message("队伍%d 获胜！升%d级！" % [attacker_team + 1, levels_to_advance], 3.0)
	elif attacker_score >= 120:
		# 对手升1级
		levels_to_advance = 1
		winning_team = attacker_team
		team_levels[attacker_team] += levels_to_advance
		dealer_index = (dealer_index + 1) % 4
		if ui_manager:
			ui_manager.show_center_message("队伍%d 获胜！升%d级！" % [attacker_team + 1, levels_to_advance], 3.0)
	elif attacker_score >= 80:
		# 庄家守住，升1级
		levels_to_advance = 1
		winning_team = dealer_team
		team_levels[dealer_team] += levels_to_advance
		# 庄家不变
		if ui_manager:
			ui_manager.show_center_message("队伍%d 守住！升%d级！" % [dealer_team + 1, levels_to_advance], 3.0)
	elif attacker_score >= 40:
		# 庄家守住，升2级
		levels_to_advance = 2
		winning_team = dealer_team
		team_levels[dealer_team] += levels_to_advance
		if ui_manager:
			ui_manager.show_center_message("队伍%d 守住！升%d级！" % [dealer_team + 1, levels_to_advance], 3.0)
	else:
		# 对手得分 < 40，庄家大胜，升3级
		levels_to_advance = 3
		winning_team = dealer_team
		team_levels[dealer_team] += levels_to_advance
		if ui_manager:
			ui_manager.show_center_message("队伍%d 大胜！升%d级！" % [dealer_team + 1, levels_to_advance], 3.0)

	print("获胜队伍：队伍", winning_team + 1, " 升级：", levels_to_advance)
	print("当前等级 - 队伍1：", team_levels[0], " 队伍2：", team_levels[1])

	# 下一局的当前级别取新庄家队伍的等级
	current_level = team_levels[players[dealer_index].team]
	
	await get_tree().create_timer(3.0).timeout
	
	# 检查游戏是否结束
	if check_game_over():
		show_game_over_screen()
	else:
		# 继续下一局
		start_new_round()

func check_game_over() -> bool:
	"""检查游戏是否结束"""
	# A = 14
	if team_levels[0] >= 14 or team_levels[1] >= 14:
		return true
	return false

func show_game_over_screen():
	"""显示游戏结束画面"""
	var winner_team = 0 if team_levels[0] >= 14 else 1
	
	if ui_manager and ui_manager.has_node("GameOverUI"):
		var game_over_ui = ui_manager.get_node("GameOverUI")
		game_over_ui.show_game_over(winner_team, team_levels[0], team_levels[1], total_rounds_played)
	
	game_over.emit(winner_team)

func restart_game():
	"""重新开始游戏"""
	# 重置所有状态
	cleanup_round_cards()
	team_levels = [2, 2]
	current_level = 2
	total_rounds_played = 0
	dealer_index = 0
	
	# 隐藏游戏结束界面
	if ui_manager and ui_manager.has_node("GameOverUI"):
		var game_over_ui = ui_manager.get_node("GameOverUI")
		game_over_ui.hide_game_over()
	
	# 开始新游戏
	start_new_round()

func get_pattern_name(pattern_type: GameRules.CardPattern) -> String:
	match pattern_type:
		GameRules.CardPattern.SINGLE: return "单张"
		GameRules.CardPattern.PAIR: return "对子"
		GameRules.CardPattern.TRACTOR: return "拖拉机"
		GameRules.CardPattern.THROW: return "甩牌"
		_: return "无效"
