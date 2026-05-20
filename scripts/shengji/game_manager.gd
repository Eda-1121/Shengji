# game_manager.gd - Phase 2 完整版游戏管理器
extends Node

enum GamePhase { DEALING_AND_BIDDING, BURYING, PLAYING, SCORING }

var deck: Deck
var players: Array[Player] = []
var current_phase: GamePhase = GamePhase.DEALING_AND_BIDDING

var trump_suit: Card.Suit = Card.Suit.SPADE
var current_level: int = 2
var dealer_index: int = 0
var current_player_index: int = 0

var bottom_cards: Array[Card] = []
var current_trick: Array = []
var last_trick_summary: Array = []  # [{player_name, cards_text, winner}]
var team_scores: Array[int] = [0, 0]
var team_levels: Array[int] = [2, 2]

# 各プレイヤーの花色切れ追跡（-1 = トランプ切れ、Card.Suit値 = 非トランプ切れ）
const VOID_TRUMP = -1
var player_void_suits: Array = [[], [], [], []]

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

# 出牌区域 - 围绕屏幕中心留出足够空间，适配放大后的卡牌
var play_area_positions = [
	Vector2(640, 462),   # 玩家1（人类）- 下方中央
	Vector2(350, 360),   # 玩家2（AI）- 左侧中央
	Vector2(640, 228),   # 玩家3（AI）- 上方中央
	Vector2(930, 360)    # 玩家4（AI）- 右侧中央
]

const PLAYED_CARD_SPACING = 42.0
const PLAYED_CARD_MIN_SPACING = 30.0
const PLAYED_CARD_MAX_WIDTH = 230.0

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
	print("=== 初始化游戏：使用 ", GameConfig.num_decks, " 副牌 ===")
	# 玩家位置：玩家1在下方居中，其他AI玩家位置不变
	var player_positions = [
		Vector2(640, 558),   # 玩家1（人类）- 下方居中，给下方出牌按钮留出空间
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
	player_void_suits = [[], [], [], []]
	deck = Deck.new(GameConfig.num_decks)
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
			card.set_face_up(true, false)
			card.visible = true
			player.set_card_selectable(false)
			SoundManager.play_deal()
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
	current_bid = {
		"team": player.team,
		"suit": suit,
		"count": count,
		"player_id": player.player_id
	}
	SoundManager.play_bid()
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

	# ヒント色を適用してからおすすめカードを自動選択
	_apply_bury_hints(dealer)
	var suggested = choose_ai_bury_cards(dealer)
	dealer.pre_select_cards(suggested)

	if ui_manager:
		ui_manager.update_turn_message("埋底：赤=NG / 黄=得点牌 / 緑=安全 （変更できます）")
		ui_manager.show_center_message("おすすめ8枚を選択しました（変更可）", 2.5)
		ui_manager.show_bury_button(true)
		ui_manager.update_selected_count(dealer.selected_cards.size(), 8)
		ui_manager.set_bury_button_enabled(dealer.selected_cards.size() == 8)

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
	_clear_bury_hints(dealer)
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
	var bury_cards = choose_ai_bury_cards(dealer)
	
	for card in bury_cards:
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

func _apply_bury_hints(dealer: Player):
	for card in dealer.hand:
		card.set_trump(trump_suit, current_level)
		card.set_bury_hint(_get_bury_hint_level(card))

func _get_bury_hint_level(card: Card) -> int:
	if card.suit == Card.Suit.JOKER or card.rank == current_level or card.is_trump:
		return 3  # 赤：絶対NG
	if card.points > 0:
		return 2  # 黄：得点牌・注意
	return 1        # 緑：安全

func _clear_bury_hints(dealer: Player):
	for card in dealer.hand:
		card.clear_bury_hint()

func _apply_play_hints():
	if players.is_empty():
		return
	var human = players[0]
	if human.hand.is_empty():
		return
	var suggested = choose_ai_play(human)
	for card in human.hand:
		card.set_play_hint(suggested.has(card))

func _clear_play_hints():
	if players.is_empty():
		return
	for card in players[0].hand:
		card.set_play_hint(false)

func choose_ai_bury_cards(dealer: Player) -> Array:
	var sorted_hand = dealer.hand.duplicate()
	sorted_hand.sort_custom(func(a, b):
		return get_ai_bury_score(a, dealer.hand) > get_ai_bury_score(b, dealer.hand)
	)
	return sorted_hand.slice(0, min(8, sorted_hand.size()))

func get_ai_bury_score(card: Card, hand: Array[Card]) -> float:
	card.set_trump(trump_suit, current_level)
	var score = 100.0 - get_ai_card_cost(card)

	if card.is_trump:
		score -= 80.0
	if card.rank == current_level:
		score -= 70.0
	if card.suit == Card.Suit.JOKER:
		score -= 120.0
	if card.points > 0:
		score -= float(card.points) * 8.0
	if is_card_part_of_pair(card, hand):
		score -= 28.0

	return score

func is_card_part_of_pair(card: Card, hand: Array[Card]) -> bool:
	var count = 0
	for hand_card in hand:
		if hand_card.rank == card.rank and hand_card.suit == card.suit:
			count += 1
			if count >= 2:
				return true
	return false

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
	refresh_all_card_counts()
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

func refresh_all_card_counts():
	if ui_manager == null:
		return
	for player in players:
		if player.player_type == Player.PlayerType.AI:
			ui_manager.update_player_card_count(player.player_id, player.get_hand_size())

func update_turn_interaction():
	var human_player = players[0]
	var human_turn = current_phase == GamePhase.PLAYING and current_player_index == 0

	for player in players:
		player.set_card_selectable(player == human_player and human_turn)

	refresh_all_card_counts()
	update_action_controls()

	if human_turn:
		_apply_play_hints()
	else:
		_clear_play_hints()

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
	_clear_play_hints()

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

const CARD_ANIM_SOURCE = [
	Vector2(640, 600),   # Player 1 (human)
	Vector2(60,  300),   # Player 2 (AI left)
	Vector2(640,  60),   # Player 3 (AI top)
	Vector2(1220, 300),  # Player 4 (AI right)
]

func show_played_cards(player_id: int, cards: Array):
	var center_position = play_area_positions[player_id]
	var spacing = get_played_card_spacing(cards.size())
	var row_width = spacing * float(max(cards.size() - 1, 0))
	var start_position = center_position - Vector2(row_width * 0.5, 0)

	SoundManager.play_card_play()

	for i in range(cards.size()):
		var card = cards[i]
		if card.get_parent():
			card.get_parent().remove_child(card)
		add_child(card)

		var target_pos = start_position + Vector2(i * spacing, 0)
		card.z_index = 100 + i
		card.visible = true
		card.set_face_up(true, true)
		card.is_selectable = false

		if player_id != 0:
			# AI: アバター位置から出牌エリアへスライドアニメーション
			card.position = CARD_ANIM_SOURCE[player_id]
			var tween = card.create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(card, "position", target_pos, 0.30)
		else:
			card.global_position = target_pos

func get_played_card_spacing(card_count: int) -> float:
	if card_count <= 1:
		return 0.0

	var spacing = PLAYED_CARD_SPACING
	var total_width = spacing * float(card_count - 1)
	if total_width > PLAYED_CARD_MAX_WIDTH:
		spacing = PLAYED_CARD_MAX_WIDTH / float(card_count - 1)

	return max(spacing, PLAYED_CARD_MIN_SPACING)

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
	
	var cards_to_play = choose_ai_play(ai_player)
	
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

func choose_ai_play(ai_player: Player) -> Array:
	"""规则型AI：首出保留强牌，跟牌时按队友/对手当前赢牌状态决策"""
	if ai_player.hand.is_empty():
		return []

	if current_trick.is_empty():
		return choose_ai_lead_play(ai_player)

	return choose_ai_follow_play(ai_player)

func choose_ai_lead_play(ai_player: Player) -> Array:
	var candidates = get_ai_lead_candidates(ai_player.hand)
	if candidates.is_empty():
		var sorted_hand = sort_cards_by_strength(ai_player.hand, true)
		return [sorted_hand[0]]

	var best_candidate = candidates[0]
	var best_score = INF
	for candidate in candidates:
		var score = score_ai_lead_candidate(candidate, ai_player.player_id)
		if score < best_score:
			best_score = score
			best_candidate = candidate

	return best_candidate

func choose_ai_follow_play(ai_player: Player) -> Array:
	var lead_pattern = current_trick[0]["pattern"]
	var candidates = get_ai_follow_candidates(ai_player.hand, lead_pattern)
	if candidates.is_empty():
		var sorted_hand = sort_cards_by_strength(ai_player.hand, true)
		return sorted_hand.slice(0, min(lead_pattern.length, sorted_hand.size()))

	var winning_play = get_current_winning_play()
	var winning_player = players[winning_play["player_id"]]
	var teammate_winning = winning_player.team == ai_player.team
	var trick_points = get_current_trick_points()
	var has_winning_candidate = false

	if not teammate_winning:
		for candidate in candidates:
			if does_candidate_beat_winning_play(candidate, winning_play):
				has_winning_candidate = true
				break

	var best_candidate = candidates[0]
	var best_score = INF
	for candidate in candidates:
		var can_beat = does_candidate_beat_winning_play(candidate, winning_play)
		var score = score_ai_follow_candidate(candidate, teammate_winning, has_winning_candidate, can_beat, trick_points)
		if score < best_score:
			best_score = score
			best_candidate = candidate

	return best_candidate

func get_ai_lead_candidates(hand: Array[Card]) -> Array:
	var candidates = []
	var sorted_hand = sort_cards_by_strength(hand, true)

	for card in sorted_hand:
		append_ai_lead_candidate(candidates, [card], hand)

	var pairs = GameRules.find_pairs_in_cards(hand)
	sort_candidate_list_by_cost(pairs)
	for pair in pairs:
		append_ai_lead_candidate(candidates, pair, hand)

	var tractors = GameRules.find_tractors_in_cards(hand, 4, trump_suit, current_level)
	sort_candidate_list_by_cost(tractors)
	for tractor in tractors:
		append_ai_lead_candidate(candidates, tractor, hand)

	return candidates

func get_ai_follow_candidates(hand: Array[Card], lead_pattern: GameRules.PlayPattern) -> Array:
	var candidates = []
	var needed = lead_pattern.length
	var same_suit_cards = get_same_suit_cards_for_lead(hand, lead_pattern)

	match lead_pattern.pattern_type:
		GameRules.CardPattern.SINGLE:
			var source = same_suit_cards if not same_suit_cards.is_empty() else hand
			for card in sort_cards_by_strength(source, true):
				append_ai_follow_candidate(candidates, [card], hand, lead_pattern)

		GameRules.CardPattern.PAIR:
			var pairs = GameRules.find_pairs_in_cards(same_suit_cards)
			sort_candidate_list_by_cost(pairs)
			for pair in pairs:
				append_ai_follow_candidate(candidates, pair, hand, lead_pattern)

			if pairs.is_empty():
				append_count_based_follow_candidates(candidates, same_suit_cards, hand, needed, lead_pattern)

		GameRules.CardPattern.TRACTOR:
			var tractors = GameRules.find_tractors_in_cards(same_suit_cards, needed, trump_suit, current_level)
			sort_candidate_list_by_cost(tractors)
			for tractor in tractors:
				append_ai_follow_candidate(candidates, tractor, hand, lead_pattern)

			if tractors.is_empty():
				var pair_preferred = build_pair_preferred_candidate(same_suit_cards, needed)
				append_ai_follow_candidate(candidates, pair_preferred, hand, lead_pattern)
				append_count_based_follow_candidates(candidates, same_suit_cards, hand, needed, lead_pattern)

		_:
			append_count_based_follow_candidates(candidates, same_suit_cards, hand, needed, lead_pattern)

	if candidates.is_empty():
		for candidate in GameRules.get_valid_follow_cards(hand, lead_pattern, trump_suit, current_level):
			append_ai_follow_candidate(candidates, candidate, hand, lead_pattern)

	return candidates

func append_count_based_follow_candidates(candidates: Array, same_suit_cards: Array[Card], hand: Array[Card], needed: int, lead_pattern: GameRules.PlayPattern):
	if same_suit_cards.size() >= needed:
		append_ai_follow_candidate(candidates, take_low_cards(same_suit_cards, needed), hand, lead_pattern)
		append_ai_follow_candidate(candidates, take_high_cards(same_suit_cards, needed), hand, lead_pattern)
		append_ai_follow_candidate(candidates, take_point_heavy_cards(same_suit_cards, needed), hand, lead_pattern)
	else:
		var base = sort_cards_by_strength(same_suit_cards, true)
		var fillers = get_cards_except(hand, base)
		append_ai_follow_candidate(candidates, base + take_low_cards(fillers, needed - base.size()), hand, lead_pattern)
		append_ai_follow_candidate(candidates, base + take_point_heavy_cards(fillers, needed - base.size()), hand, lead_pattern)

func append_ai_lead_candidate(candidates: Array, cards: Array, hand: Array[Card]):
	var typed_cards = normalize_card_list(cards)
	if typed_cards.is_empty() or not GameRules.validate_play(typed_cards, hand):
		return

	var pattern = GameRules.identify_pattern(typed_cards, trump_suit, current_level)
	if pattern.pattern_type == GameRules.CardPattern.INVALID or pattern.pattern_type == GameRules.CardPattern.THROW:
		return

	append_unique_candidate(candidates, typed_cards)

func append_ai_follow_candidate(candidates: Array, cards: Array, hand: Array[Card], lead_pattern: GameRules.PlayPattern):
	var typed_cards = normalize_card_list(cards)
	if typed_cards.size() != lead_pattern.length or not GameRules.validate_play(typed_cards, hand):
		return

	var pattern = GameRules.identify_pattern(typed_cards, trump_suit, current_level)
	if pattern.pattern_type == GameRules.CardPattern.INVALID:
		return

	if not GameRules.can_follow(pattern, lead_pattern, hand, trump_suit, current_level):
		return

	append_unique_candidate(candidates, typed_cards)

func normalize_card_list(cards: Array) -> Array[Card]:
	var typed_cards: Array[Card] = []
	for card in cards:
		if card is Card and not typed_cards.has(card):
			typed_cards.append(card)
	return typed_cards

func append_unique_candidate(candidates: Array, cards: Array[Card]):
	for candidate in candidates:
		if has_same_cards(candidate, cards):
			return
	candidates.append(cards)

func has_same_cards(cards_a: Array, cards_b: Array) -> bool:
	if cards_a.size() != cards_b.size():
		return false
	for card in cards_a:
		if not cards_b.has(card):
			return false
	return true

func get_same_suit_cards_for_lead(hand: Array[Card], lead_pattern: GameRules.PlayPattern) -> Array[Card]:
	var same_suit_cards: Array[Card] = []
	var lead_card = lead_pattern.cards[0]
	lead_card.set_trump(trump_suit, current_level)

	for card in hand:
		card.set_trump(trump_suit, current_level)
		if lead_card.is_trump:
			if card.is_trump:
				same_suit_cards.append(card)
		elif not card.is_trump and card.suit == lead_card.suit:
			same_suit_cards.append(card)

	return same_suit_cards

func sort_cards_by_strength(cards: Array, ascending: bool) -> Array:
	var sorted_cards = cards.duplicate()
	for card in sorted_cards:
		card.set_trump(trump_suit, current_level)

	sorted_cards.sort_custom(func(a, b):
		var result = a.compare_to(b, trump_suit, current_level)
		if result == 0:
			if a.suit != b.suit:
				return a.suit < b.suit if ascending else a.suit > b.suit
			return a.rank < b.rank if ascending else a.rank > b.rank
		return result < 0 if ascending else result > 0
	)
	return sorted_cards

func sort_candidate_list_by_cost(candidates: Array):
	candidates.sort_custom(func(a, b):
		return get_ai_play_cost(a) < get_ai_play_cost(b)
	)

func take_low_cards(cards: Array, count: int) -> Array:
	if count <= 0:
		return []
	return sort_cards_by_strength(cards, true).slice(0, min(count, cards.size()))

func take_high_cards(cards: Array, count: int) -> Array:
	if count <= 0:
		return []
	return sort_cards_by_strength(cards, false).slice(0, min(count, cards.size()))

func take_point_heavy_cards(cards: Array, count: int) -> Array:
	if count <= 0:
		return []

	var sorted_cards = cards.duplicate()
	sorted_cards.sort_custom(func(a, b):
		if a.points != b.points:
			return a.points > b.points
		return get_ai_card_cost(a) < get_ai_card_cost(b)
	)
	return sorted_cards.slice(0, min(count, sorted_cards.size()))

func get_cards_except(cards: Array[Card], excluded: Array) -> Array[Card]:
	var result: Array[Card] = []
	for card in cards:
		if not excluded.has(card):
			result.append(card)
	return result

func build_pair_preferred_candidate(cards: Array[Card], needed: int) -> Array:
	var result = []
	var pairs = GameRules.find_pairs_in_cards(cards)
	sort_candidate_list_by_cost(pairs)

	for pair in pairs:
		if result.size() + pair.size() <= needed:
			result.append_array(pair)
		if result.size() >= needed:
			return result.slice(0, needed)

	for card in sort_cards_by_strength(cards, true):
		if not result.has(card):
			result.append(card)
		if result.size() >= needed:
			break

	return result

func score_ai_lead_candidate(cards: Array, ai_player_id: int = 0) -> float:
	var pattern = GameRules.identify_pattern(normalize_card_list(cards), trump_suit, current_level)
	var score = get_ai_play_cost(cards)
	score += float(GameRules.calculate_points(cards)) * 2.2
	score -= float(cards.size() - 1) * 4.0

	if is_all_trump_cards(cards):
		score += 35.0
	else:
		score -= 12.0

	match pattern.pattern_type:
		GameRules.CardPattern.PAIR:
			score -= 8.0
		GameRules.CardPattern.TRACTOR:
			score -= 16.0

	# 相手がこの花色（またはトランプ）を切らしている場合はペナルティ
	if not cards.is_empty() and cards[0] is Card:
		var lead_c: Card = cards[0]
		lead_c.set_trump(trump_suit, current_level)
		var void_key = VOID_TRUMP if lead_c.is_trump else lead_c.suit
		if _any_opponent_void(ai_player_id, void_key):
			score += 22.0  # リスク増：相手が自由牌を出せる

	return score

func score_ai_follow_candidate(cards: Array, teammate_winning: bool, has_winning_candidate: bool, can_beat: bool, trick_points: int) -> float:
	var cost = get_ai_play_cost(cards)
	var points = float(GameRules.calculate_points(cards))

	if teammate_winning:
		var score = cost - points * 6.0
		if can_beat:
			score += 140.0 + cost
		return score

	if has_winning_candidate:
		if can_beat:
			return cost - float(trick_points) * 3.0 - points * 1.5
		return 10000.0 + cost + points * 5.0

	return cost + points * 5.0

func get_ai_card_cost(card: Card) -> float:
	card.set_trump(trump_suit, current_level)
	var cost = float(card.rank)

	if card.suit == Card.Suit.JOKER:
		cost += 55.0
	elif card.rank == current_level:
		cost += 30.0
	elif card.is_trump:
		cost += 18.0

	cost += float(card.points) * 0.8
	return cost

func get_ai_play_cost(cards: Array) -> float:
	var cost = 0.0
	for card in cards:
		if card is Card:
			cost += get_ai_card_cost(card)
	return cost

func is_all_trump_cards(cards: Array) -> bool:
	if cards.is_empty():
		return false
	for card in cards:
		card.set_trump(trump_suit, current_level)
		if not card.is_trump:
			return false
	return true

func get_current_winning_play() -> Dictionary:
	if current_trick.is_empty():
		return {}

	var winning_play = current_trick[0]
	for i in range(1, current_trick.size()):
		var play = current_trick[i]
		if GameRules.compare_plays(winning_play["pattern"], play["pattern"], trump_suit, current_level) < 0:
			winning_play = play

	return winning_play

func does_candidate_beat_winning_play(cards: Array, winning_play: Dictionary) -> bool:
	if winning_play.is_empty():
		return true

	var typed_cards = normalize_card_list(cards)
	var pattern = GameRules.identify_pattern(typed_cards, trump_suit, current_level)
	if pattern.pattern_type == GameRules.CardPattern.INVALID:
		return false

	return GameRules.compare_plays(winning_play["pattern"], pattern, trump_suit, current_level) < 0

func get_current_trick_points() -> int:
	var points = 0
	for play in current_trick:
		points += GameRules.calculate_points(play["cards"])
	return points

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
	SoundManager.play_trick_win()

	var points = 0
	for play in current_trick:
		points += GameRules.calculate_points(play["cards"])

	team_scores[winner.team] += points

	if ui_manager:
		ui_manager.update_team_scores(team_scores[0], team_scores[1])
		ui_manager.show_center_message("%s 赢得本轮，得 %d 分" % [winner.player_name, points], 2.0)

	# 底牌倍率とトリック情報はカード解放前に計算・保存する
	_update_void_tracking()
	var bottom_multiplier = calculate_bottom_multiplier(winner_play)

	# 前トリック情報を保存（カード解放前）
	last_trick_summary.clear()
	for play in current_trick:
		var cards_text = " ".join(play["cards"].map(func(c): return c.get_display_name()))
		last_trick_summary.append({
			"player_name": players[play["player_id"]].player_name,
			"cards_text": cards_text,
			"is_winner": play["player_id"] == winner_play["player_id"]
		})
	if ui_manager and ui_manager.has_method("update_last_trick"):
		ui_manager.update_last_trick(last_trick_summary)

	await get_tree().create_timer(2.0).timeout

	for play in current_trick:
		for card in play["cards"]:
			if is_instance_valid(card) and card.get_parent():
				card.queue_free()

	current_trick.clear()

	if players[0].get_hand_size() == 0:
		await get_tree().create_timer(1.0).timeout

		var bottom_points = GameRules.calculate_points(bottom_cards)
		var multiplier = bottom_multiplier

		if winner.team == current_bid["team"]:
			team_scores[current_bid["team"]] += bottom_points * multiplier
			if ui_manager:
				ui_manager.show_center_message("庄家队扣底成功! +%d分 (x%d)" % [bottom_points * multiplier, multiplier], 2.0)
				ui_manager.update_team_scores(team_scores[0], team_scores[1])
		else:
			var opponent_team = 1 - current_bid["team"]
			team_scores[opponent_team] += bottom_points * multiplier
			if ui_manager:
				ui_manager.show_center_message("对手队抠底成功! +%d分 (x%d)" % [bottom_points * multiplier, multiplier], 2.0)
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

func _update_void_tracking():
	if current_trick.size() < 2:
		return
	var lead_card = current_trick[0]["cards"][0]
	lead_card.set_trump(trump_suit, current_level)
	for i in range(1, current_trick.size()):
		var play = current_trick[i]
		var played_card = play["cards"][0]
		played_card.set_trump(trump_suit, current_level)
		var pid = play["player_id"]
		if lead_card.is_trump:
			if not played_card.is_trump and not player_void_suits[pid].has(VOID_TRUMP):
				player_void_suits[pid].append(VOID_TRUMP)
				print("▶ ", players[pid].player_name, " トランプ切れ確定")
		else:
			if (played_card.is_trump or played_card.suit != lead_card.suit) and not player_void_suits[pid].has(lead_card.suit):
				player_void_suits[pid].append(lead_card.suit)
				print("▶ ", players[pid].player_name, " ", lead_card.suit, " 切れ確定")

func _any_opponent_void(ai_player_id: int, suit_key) -> bool:
	for i in range(4):
		if i != ai_player_id and players[i].team != players[ai_player_id].team:
			if player_void_suits[i].has(suit_key):
				return true
	return false

func calculate_bottom_multiplier(winning_play: Dictionary) -> int:
	# 倍率ルール: ×2基本、小王対→×4、大王対→×8、両ジョーカー対→×16
	var small_joker_count = 0
	var big_joker_count = 0
	for card in winning_play.get("cards", []):
		if card.suit == Card.Suit.JOKER:
			if card.rank == Card.Rank.BIG_JOKER:
				big_joker_count += 1
			else:
				small_joker_count += 1
	if big_joker_count >= 2 and small_joker_count >= 2:
		return 16
	if big_joker_count >= 2:
		return 8
	if small_joker_count >= 2:
		return 4
	return 2

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

	# 标准升级规则（攻撃チームの得点による）:
	# 攻撃チーム 0点       : 庄家チーム +3级
	# 攻撃チーム 1〜39点   : 庄家チーム +2级
	# 攻撃チーム 40〜79点  : 庄家チーム +1级
	# 攻撃チーム 80〜119点 : 攻撃チーム +1级（攻撃勝利・庄家交代）
	# 攻撃チーム 120〜159点: 攻撃チーム +2级
	# 攻撃チーム 160〜199点: 攻撃チーム +3级
	# 攻撃チーム 200点以上 : 攻撃チーム +4级

	if attacker_score >= 200:
		levels_to_advance = 4
		winning_team = attacker_team
		team_levels[attacker_team] += levels_to_advance
		dealer_index = (dealer_index + 1) % 4
		if ui_manager:
			ui_manager.show_center_message("队伍%d 大胜！升%d级！" % [attacker_team + 1, levels_to_advance], 3.0)
	elif attacker_score >= 160:
		levels_to_advance = 3
		winning_team = attacker_team
		team_levels[attacker_team] += levels_to_advance
		dealer_index = (dealer_index + 1) % 4
		if ui_manager:
			ui_manager.show_center_message("队伍%d 获胜！升%d级！" % [attacker_team + 1, levels_to_advance], 3.0)
	elif attacker_score >= 120:
		levels_to_advance = 2
		winning_team = attacker_team
		team_levels[attacker_team] += levels_to_advance
		dealer_index = (dealer_index + 1) % 4
		if ui_manager:
			ui_manager.show_center_message("队伍%d 获胜！升%d级！" % [attacker_team + 1, levels_to_advance], 3.0)
	elif attacker_score >= 80:
		# 80点以上 = 攻撃チーム勝利・庄家交代（標準ルール）
		levels_to_advance = 1
		winning_team = attacker_team
		team_levels[attacker_team] += levels_to_advance
		dealer_index = (dealer_index + 1) % 4
		if ui_manager:
			ui_manager.show_center_message("队伍%d 获胜！升%d级！" % [attacker_team + 1, levels_to_advance], 3.0)
	elif attacker_score >= 40:
		# 庄家守住，升1级
		levels_to_advance = 1
		winning_team = dealer_team
		team_levels[dealer_team] += levels_to_advance
		if ui_manager:
			ui_manager.show_center_message("队伍%d 守住！升%d级！" % [dealer_team + 1, levels_to_advance], 3.0)
	elif attacker_score >= 1:
		# 庄家守住，升2级
		levels_to_advance = 2
		winning_team = dealer_team
		team_levels[dealer_team] += levels_to_advance
		if ui_manager:
			ui_manager.show_center_message("队伍%d 守住！升%d级！" % [dealer_team + 1, levels_to_advance], 3.0)
	else:
		# 攻撃チーム0点 = 庄家チーム大勝、+3级
		levels_to_advance = 3
		winning_team = dealer_team
		team_levels[dealer_team] += levels_to_advance
		if ui_manager:
			ui_manager.show_center_message("队伍%d 大胜！升%d级！" % [dealer_team + 1, levels_to_advance], 3.0)

	print("获胜队伍：队伍", winning_team + 1, " 升级：", levels_to_advance)
	print("当前等级 - 队伍1：", team_levels[0], " 队伍2：", team_levels[1])
	SoundManager.play_level_up()

	current_level = team_levels[players[dealer_index].team]

	await get_tree().create_timer(3.0).timeout

	if check_game_over():
		SoundManager.play_game_over()
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
