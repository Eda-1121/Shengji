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
	Vector2(640, 560),   # 玩家1（人类）- 下方中央（向下移动，避免与按钮重叠）
	Vector2(380, 360),   # 玩家2（AI）- 左侧中央
	Vector2(640, 220),   # 玩家3（AI）- 上方中央
	Vector2(900, 360)    # 玩家4（AI）- 右侧中央
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
	initialize_game()

func initialize_game():
	print("=== 初始化游戏：使用 ", num_decks, " 副牌 ===")
	deck = Deck.new(num_decks)
	deck.create_deck()

	# 玩家位置：围绕屏幕中心(640, 360)对称布局
	var player_positions = [
		Vector2(200, 640),   # 玩家1（人类）- 下方，向下移动避免与按钮重叠
		Vector2(50, 360),    # 玩家2（AI）- 左侧，垂直居中与玩家4对齐
		Vector2(640, 50),    # 玩家3（AI）- 上方，水平居中与玩家1对齐
		Vector2(1050, 360)   # 玩家4（AI）- 右侧，垂直居中与玩家2对齐
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

		# 对人类玩家，将手牌容器居中显示在屏幕中央
		if player.player_type == Player.PlayerType.HUMAN:
			player.center_hand_container()

	start_new_round()

func start_new_round():
	print("\n" + "=".repeat(60))
	print("=== 开始新一局 (第 %d 局) ===" % [total_rounds_played + 1])
	print("=".repeat(60))
	total_rounds_played += 1

	# ==========================================
	# 步骤1: 重置游戏状态
	# ==========================================
	print("\n[步骤1] 重置游戏状态")
	team_scores = [0, 0]
	current_bid = {
		"team": -1,
		"suit": Card.Suit.SPADE,
		"count": 0,
		"player_id": -1
	}
	bidding_round = 0
	current_phase = GamePhase.DEALING_AND_BIDDING

	# 清理所有玩家手牌
	for player in players:
		for card in player.hand:
			if is_instance_valid(card):
				card.queue_free()
		player.hand.clear()
		player.selected_cards.clear()
		player.is_dealer = false

	# 重新创建牌堆
	deck = Deck.new(num_decks)
	deck.create_deck()
	print("  - 创建牌堆: %d 副牌, 共 %d 张牌" % [num_decks, deck.cards.size()])

	# 验证：打印前5张牌的对象ID
	print("  - 验证牌堆中的卡牌对象ID（前5张）:")
	for i in range(min(5, deck.cards.size())):
		var card = deck.cards[i]
		print("    [%d] %s 对象ID=%s" % [i, card.get_card_name(), card.get_instance_id()])

	# ==========================================
	# 步骤2: 洗牌
	# ==========================================
	print("\n[步骤2] 洗牌")
	deck.shuffle()
	print("  - 洗牌完成")

	# ==========================================
	# 步骤3: 准备底牌（8张）
	# ==========================================
	print("\n[步骤3] 准备底牌")
	bottom_cards.clear()
	for _i in 8:
		if deck.cards.size() > 0:
			bottom_cards.append(deck.cards.pop_back())
	print("  - 底牌准备完成: 8张")
	print("  - 剩余待发牌数: %d张" % deck.cards.size())

	# 标记庄家（上一局的庄家或初始庄家）
	players[dealer_index].is_dealer = true
	print("  - 当前庄家: %s (player_id=%d)" % [players[dealer_index].player_name, dealer_index])

	# ==========================================
	# 初始化UI
	# ==========================================
	if ui_manager:
		ui_manager.update_level(current_level)
		ui_manager.update_trump_suit("?")
		ui_manager.update_team_scores(0, 0)
		ui_manager.update_turn_message("正在发牌...")

		# 显示叫牌UI（但按钮禁用）
		if ui_manager.has_node("BiddingUI"):
			var bidding_ui = ui_manager.get_node("BiddingUI")
			bidding_ui.show_bidding_ui(false)
			bidding_ui.update_current_bid("当前无人叫牌")

	phase_changed.emit(current_phase)

	# ==========================================
	# 步骤4: 开始逐张发牌（发牌过程中可以随时叫牌）
	# ==========================================
	print("\n[步骤4] 开始发牌（发牌过程中可随时叫牌）")
	print("  - 从庄家 %s 开始发牌" % players[dealer_index].player_name)
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
		else:
			# AI玩家的牌完全不显示（不需要看到背面）
			card.visible = false

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
	print("\n[发牌完成] 验证玩家1手牌对象ID（前5张）:")
	var human_player = players[0]
	for i in range(min(5, human_player.hand.size())):
		var card = human_player.hand[i]
		print("  [%d] %s 对象ID=%s, parent=%s" % [i, card.get_card_name(), card.get_instance_id(), card.get_parent().name if card.get_parent() else "无"])

	finish_dealing()

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
	print("\n" + "=".repeat(60))
	print("=== 发牌完成 ===")
	print("=".repeat(60))

	if ui_manager:
		ui_manager.update_turn_message("发牌完成，最后叫牌机会...")

	# ==========================================
	# 步骤5: 发牌结束后的最后叫牌机会
	# ==========================================
	print("\n[步骤5] 最后叫牌机会")
	print("  - 当前叫牌状态: %s" % ("无人叫牌" if current_bid["count"] == 0 else "%s 叫了 %d 张" % [players[current_bid["player_id"]].player_name, current_bid["count"]]))

	# 检查所有玩家是否有更多等级牌可以反叫
	await check_final_bidding_opportunity()

	# ==========================================
	# 步骤6: 确定主牌和庄家
	# ==========================================
	print("\n[步骤6] 确定主牌和庄家")
	if ui_manager and ui_manager.has_node("BiddingUI"):
		var bidding_ui = ui_manager.get_node("BiddingUI")
		bidding_ui.hide_bidding_ui()

	# 如果没人叫牌，默认庄家队叫黑桃
	if current_bid["count"] == 0:
		trump_suit = Card.Suit.SPADE
		current_bid["team"] = players[dealer_index].team
		print("  - 没人叫牌，默认庄家队叫黑桃")
		print("  - 庄家: %s (保持不变)" % players[dealer_index].player_name)
	else:
		trump_suit = current_bid["suit"]
		dealer_index = current_bid["player_id"]  # 叫到主的人成为新庄家
		print("  - 叫牌成功！")
		print("  - 新庄家: %s (player_id=%d)" % [players[dealer_index].player_name, dealer_index])
		print("  - 主牌花色: %s" % get_suit_name(trump_suit))
		print("  - 庄家队伍: 队伍%d" % [current_bid["team"] + 1])

	if ui_manager:
		ui_manager.update_trump_suit(get_trump_symbol())
		ui_manager.show_center_message("队伍%d 叫到主: %s" % [current_bid["team"] + 1, get_trump_symbol()], 2.0)

	await get_tree().create_timer(2.0).timeout

	# ==========================================
	# 步骤7: 进入埋底阶段
	# ==========================================
	print("\n[步骤7] 进入埋底阶段")
	print("  - 庄家 %s 将收到8张底牌" % players[dealer_index].player_name)

	# 设置埋底阶段（重要：在任何埋底操作之前设置，防止AI误出牌）
	current_phase = GamePhase.BURYING

	if players[dealer_index].player_type == Player.PlayerType.HUMAN:
		print("  - 庄家是人类玩家，等待手动埋底")
		start_burying_phase()
	else:
		print("  - 庄家是AI玩家，自动埋底")
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
		current_bid["team"] = players[dealer_index].team
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
		ai_bury_bottom()

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
	print("\n" + "=".repeat(60))
	print("=== 埋底阶段 ===")
	print("=".repeat(60))
	current_phase = GamePhase.BURYING
	print("  - 游戏阶段已设置为：BURYING")

	var dealer = players[dealer_index]
	print("\n[埋底] 庄家收到底牌")
	print("  - 庄家: %s (player_id=%d)" % [dealer.player_name, dealer.player_id])
	print("  - 当前手牌数: %d张" % dealer.hand.size())
	print("  - 准备发放底牌: 8张")

	# 庄家收到8张底牌
	dealer.receive_cards(bottom_cards)
	bottom_cards.clear()

	print("  - 底牌发放完成")
	print("  - 庄家当前手牌总数: %d张" % dealer.hand.size())
	print("  - 等待庄家选择8张牌扣底...")

	if ui_manager:
		ui_manager.update_turn_message("庄家埋底 - 请选择8张牌作为底牌")
		ui_manager.show_center_message("庄家请选择8张牌扣底", 2.0)
		ui_manager.show_bury_button(true)
		ui_manager.set_bury_button_enabled(false)

func _on_bury_cards_pressed():
	"""玩家点击埋底按钮"""
	print("\n[埋底] 玩家确认埋底")

	if current_phase != GamePhase.BURYING:
		print("  ⚠ 警告：当前不是埋底阶段，忽略操作")
		return

	var dealer = players[dealer_index]

	if dealer.selected_cards.size() != 8:
		print("  ⚠ 选中牌数不对：%d张 (需要8张)" % dealer.selected_cards.size())
		if ui_manager:
			ui_manager.show_center_message("请选择正好8张牌!", 1.5)
		return

	print("  - 从%d张手牌中选择了8张埋底" % dealer.hand.size())

	# 将选中的8张牌移到底牌
	for card in dealer.selected_cards:
		bottom_cards.append(card)
		dealer.hand.erase(card)
		if card.get_parent() == dealer.hand_container:
			dealer.hand_container.remove_child(card)
		card.set_selected(false)

	dealer.selected_cards.clear()
	dealer.update_hand_display()

	print("  - 埋底完成！")
	print("  - 庄家剩余手牌: %d张" % dealer.hand.size())
	print("  - 底牌总分: %d分" % GameRules.calculate_points(bottom_cards))

	if ui_manager:
		ui_manager.show_bury_button(false)
		ui_manager.show_center_message("埋底完成", 1.5)

	print("\n等待1.5秒后进入出牌阶段...")
	await get_tree().create_timer(1.5).timeout
	start_playing_phase()

func auto_bury_for_player(dealer: Player):
	"""自动埋底"""
	var sorted_hand = dealer.hand.duplicate()
	sorted_hand.sort_custom(func(a, b): 
		a.set_trump(trump_suit, current_level)
		b.set_trump(trump_suit, current_level)
		return a.compare_to(b, trump_suit, current_level) < 0
	)
	
	for i in range(min(8, sorted_hand.size())):
		bottom_cards.append(sorted_hand[i])
		dealer.hand.erase(sorted_hand[i])
	
	dealer.update_hand_display()

	if ui_manager:
		ui_manager.show_center_message("埋底完成", 1.5)
	
	await get_tree().create_timer(1.5).timeout
	start_playing_phase()

func ai_bury_bottom():
	"""AI埋底"""
	print("=== ai_bury_bottom() 被调用 ===")
	var dealer = players[dealer_index]
	print("AI庄家：", dealer.player_name, " 开始埋底")

	dealer.receive_cards(bottom_cards)
	bottom_cards.clear()

	print("等待1.5秒...")
	await get_tree().create_timer(1.5).timeout
	print("调用 auto_bury_for_player()")
	auto_bury_for_player(dealer)

# =====================================
# 出牌阶段
# =====================================

func start_playing_phase():
	"""开始出牌阶段"""
	print("\n" + "=".repeat(60))
	print("=== 出牌阶段 ===")
	print("=".repeat(60))
	current_phase = GamePhase.PLAYING

	print("\n[出牌阶段] 初始化")
	print("  - 主牌花色: %s" % get_suit_name(trump_suit))
	print("  - 当前等级: %d" % current_level)

	# 重新整理所有玩家的手牌（主牌放最后）
	print("\n[出牌阶段] 整理手牌")
	for player in players:
		# 设置所有牌的主牌状态
		for card in player.hand:
			card.set_trump(trump_suit, current_level)
		# 重新排序：主牌和当前级别的牌放在最后，按正确顺序排列
		player.sort_hand(true, trump_suit, current_level)
		# 更新显示
		player.update_hand_display(true)
		if player.player_type == Player.PlayerType.HUMAN:
			print("  - %s: %d张手牌" % [player.player_name, player.hand.size()])

	# 第一轮由庄家（叫牌成功的玩家）先出牌
	current_player_index = dealer_index
	print("\n[第1轮] 开始")
	print("  - 庄家（首家）: %s (player_id=%d)" % [players[dealer_index].player_name, dealer_index])
	print("  - 出牌顺序: %s → %s → %s → %s" % [
		players[dealer_index].player_name,
		players[(dealer_index + 1) % 4].player_name,
		players[(dealer_index + 2) % 4].player_name,
		players[(dealer_index + 3) % 4].player_name
	])

	if ui_manager:
		ui_manager.update_turn_message("轮到 %s 出牌" % players[current_player_index].player_name)
		ui_manager.highlight_current_player(current_player_index)

	phase_changed.emit(current_phase)

	if players[current_player_index].player_type == Player.PlayerType.AI:
		print("  - %s 是AI，自动出牌..." % players[current_player_index].player_name)
		await get_tree().create_timer(1.0).timeout
		ai_play_turn(players[current_player_index])
	else:
		print("  - %s 是人类玩家，等待操作..." % players[current_player_index].player_name)

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

func _on_play_cards_pressed():
	"""出牌按钮被点击"""
	if current_phase != GamePhase.PLAYING:
		return

	var human_player = players[0]
	if human_player.selected_cards.is_empty():
		if ui_manager:
			ui_manager.show_center_message("请先选择要出的牌!", 1.5)
		return

	print("\n[出牌按钮] 玩家点击出牌按钮")
	print("  - 已选中卡牌数量: %d" % human_player.selected_cards.size())
	print("  - 已选中的卡牌列表:")
	for i in range(human_player.selected_cards.size()):
		var c = human_player.selected_cards[i]
		print("    [%d] %s (suit=%d, rank=%d, 对象ID=%s)" % [i, c.get_card_name(), c.suit, c.rank, c.get_instance_id()])

	# 先复制一份要出的牌，避免后续操作影响
	var cards_to_play: Array[Card] = []
	for card in human_player.selected_cards:
		card.set_trump(trump_suit, current_level)
		cards_to_play.append(card)

	print("  - 复制后的cards_to_play数量: %d" % cards_to_play.size())
	print("  - cards_to_play列表:")
	for i in range(cards_to_play.size()):
		var c = cards_to_play[i]
		print("    [%d] %s (suit=%d, rank=%d, 对象ID=%s)" % [i, c.get_card_name(), c.suit, c.rank, c.get_instance_id()])

	var pattern = GameRules.identify_pattern(cards_to_play, trump_suit, current_level)

	if not GameRules.validate_play(cards_to_play, human_player.hand):
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

				# 甩牌失败，清理所有选中牌的选择状态
				for card in human_player.selected_cards:
					card.set_selected(false)
				human_player.selected_cards.clear()

				# 只出最大的牌
				var largest_card = GameRules.get_largest_card(pattern.cards, trump_suit, current_level)
				cards_to_play.clear()
				cards_to_play.append(largest_card)
				pattern = GameRules.identify_pattern([largest_card], trump_suit, current_level)

		# 手动处理出牌流程（避免play_selected_cards和show_played_cards冲突）
		if execute_play_cards(human_player, cards_to_play):
			current_trick.append({
				"player_id": human_player.player_id,
				"cards": cards_to_play,
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

		# 手动处理出牌流程
		if execute_play_cards(human_player, cards_to_play):
			current_trick.append({
				"player_id": human_player.player_id,
				"cards": cards_to_play,
				"pattern": pattern
			})

			if ui_manager:
				ui_manager.show_center_message("跟牌成功!", 1.0)

			if current_trick.size() == 4:
				evaluate_trick()
			else:
				next_player_turn()

func execute_play_cards(player: Player, cards_to_play: Array[Card]) -> bool:
	"""
	统一的出牌处理函数
	1. 从玩家手牌中移除卡牌
	2. 清空选择状态
	3. 显示出的牌到出牌区域
	4. 更新手牌显示
	"""
	if cards_to_play.is_empty():
		print("  ⚠ 错误：没有要出的牌")
		return false

	print("\n" + "=".repeat(60))
	print("[出牌流程] %s 出 %d 张牌" % [player.player_name, cards_to_play.size()])
	print("=".repeat(60))

	# 输出要出的牌
	for card in cards_to_play:
		print("  → 准备出牌: %s" % card.get_card_name())

	print("\n[步骤1] 出牌前状态")
	print("  - hand数组大小: %d" % player.hand.size())
	print("  - hand_container子节点数: %d" % player.hand_container.get_child_count())
	print("  - selected_cards大小: %d" % player.selected_cards.size())

	# 验证所有要出的牌都在hand中
	for card in cards_to_play:
		if not player.hand.has(card):
			print("  ⚠ 错误：卡牌 %s 不在手牌中！" % card.get_card_name())
			return false

	print("\n[步骤2] 从hand数组和hand_container移除卡牌")
	# 从手牌中移除，并清理选择状态
	for card in cards_to_play:
		# 取消选择状态
		if card.is_selected:
			card.is_selected = false
			if card.sprite:
				card.sprite.modulate = Color.WHITE
			print("  - 清除选中状态: %s" % card.get_card_name())

		# 从手牌数组移除
		player.hand.erase(card)

		# 从UI容器移除（关键！必须在这里移除）
		if card.get_parent() == player.hand_container:
			player.hand_container.remove_child(card)
			print("  - 从hand_container移除: %s" % card.get_card_name())

		# 从选中列表移除
		if player.selected_cards.has(card):
			player.selected_cards.erase(card)

		# 断开信号
		if card.card_clicked.is_connected(player._on_card_clicked):
			card.card_clicked.disconnect(player._on_card_clicked)

	# 清空选中列表
	player.selected_cards.clear()

	print("\n[步骤3] 移除后状态")
	print("  - hand数组大小: %d" % player.hand.size())
	print("  - hand_container子节点数: %d" % player.hand_container.get_child_count())
	print("  - selected_cards大小: %d" % player.selected_cards.size())

	print("\n[步骤4] 显示出的牌到出牌区域")
	show_played_cards(player.player_id, cards_to_play)

	print("\n[步骤5] 更新手牌显示")
	player.update_hand_display(false)  # 不使用动画，避免异步问题
	print("[步骤5] update_hand_display返回")  # 添加这行确认函数返回

	print("\n[步骤6] 最终状态")
	print("  - hand数组大小: %d" % player.hand.size())
	print("  - hand_container子节点数: %d" % player.hand_container.get_child_count())

	# 验证hand和hand_container同步
	var ui_card_count = 0
	for child in player.hand_container.get_children():
		if child is Card:
			ui_card_count += 1

	if ui_card_count == player.hand.size():
		print("  ✓ 同步验证成功：hand数组和UI一致")
	else:
		print("  ⚠ 同步验证失败：hand数组 %d 张，UI显示 %d 张" % [player.hand.size(), ui_card_count])

	# 验证：确认出的牌已经不在hand数组中
	print("\n[步骤7] 验证出的牌已从hand数组移除:")
	var cards_still_in_hand = []
	for card in cards_to_play:
		if player.hand.has(card):
			cards_still_in_hand.append(card)
			print("  ⚠⚠⚠ 错误：%s (对象ID=%s) 仍在hand数组中！" % [card.get_card_name(), card.get_instance_id()])

	if cards_still_in_hand.is_empty():
		print("  ✓ 验证通过：所有出的牌都已从hand数组移除")
	else:
		print("  ⚠⚠⚠ 发现 %d 张牌仍在hand数组中，这会导致手牌增多bug！" % cards_still_in_hand.size())

	print("=".repeat(60))
	print("出牌成功，剩余手牌：%d张\n" % player.hand.size())
	return true

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
	"""显示出的牌到出牌区域"""
	var position = play_area_positions[player_id]

	for i in range(cards.size()):
		var card = cards[i]

		# 如果卡牌还有父节点（不应该有，因为execute_play_cards已经移除了）
		if card.get_parent():
			print("  ⚠ 警告：show_played_cards时卡牌 %s 还有父节点: %s" % [card.get_card_name(), card.get_parent().name])
			card.get_parent().remove_child(card)

		# 添加到game_manager以显示在出牌区
		add_child(card)
		print("  - 添加到出牌区: %s" % card.get_card_name())

		# 使用全局坐标，确保牌显示在正确的屏幕位置
		card.global_position = position + Vector2(i * 20, 0)
		card.z_index = 100
		card.visible = true
		card.set_face_up(true, true)

		# 禁用已出牌的交互事件
		card.is_selectable = false

func next_player_turn():
	"""下一个玩家"""
	# 安全检查：确保在出牌阶段才能调用
	if current_phase != GamePhase.PLAYING:
		print("  ⚠ 警告：当前不是出牌阶段(%s)，不能调用next_player_turn！" % ["DEALING_AND_BIDDING", "BURYING", "PLAYING", "SCORING"][current_phase])
		return

	current_player_index = (current_player_index + 1) % 4
	var current_player = players[current_player_index]

	if ui_manager:
		ui_manager.update_turn_message("轮到 %s 出牌" % current_player.player_name)
		ui_manager.highlight_current_player(current_player_index)

	if current_player.player_type == Player.PlayerType.AI:
		await get_tree().create_timer(1.5).timeout
		ai_play_turn(current_player)

func ai_play_turn(ai_player: Player):
	"""AI出牌"""
	print("\n[AI出牌] %s 思考中..." % ai_player.player_name)
	print("  - 当前阶段: %s" % ("出牌阶段" if current_phase == GamePhase.PLAYING else "其他"))
	print("  - 手牌数: %d张" % ai_player.hand.size())

	# 安全检查：确保在出牌阶段才能出牌
	if current_phase != GamePhase.PLAYING:
		print("  ⚠ 警告：当前不是出牌阶段，AI不能出牌！")
		return

	# 更新所有手牌的主牌状态
	for card in ai_player.hand:
		card.set_trump(trump_suit, current_level)

	var cards_to_play: Array[Card] = []

	if current_trick.is_empty():
		# 首家出牌：出最大的单张
		if ai_player.hand.size() > 0:
			var sorted_hand = ai_player.hand.duplicate()
			sorted_hand.sort_custom(func(a, b):
				return a.compare_to(b, trump_suit, current_level) > 0
			)
			cards_to_play.append(sorted_hand[0])
			print("  - AI选择首家出牌: %s" % sorted_hand[0].get_card_name())
	else:
		# 跟牌
		var lead_pattern = current_trick[0]["pattern"]
		var valid_plays = GameRules.get_valid_follow_cards(ai_player.hand, lead_pattern, trump_suit, current_level)

		if valid_plays.size() > 0:
			for card in valid_plays[0]:
				cards_to_play.append(card)
			print("  - AI选择跟牌: %d张" % cards_to_play.size())
		elif ai_player.hand.size() >= lead_pattern.length:
			var sorted_hand = ai_player.hand.duplicate()
			sorted_hand.sort_custom(func(a, b):
				return a.compare_to(b, trump_suit, current_level) < 0
			)
			for i in range(lead_pattern.length):
				cards_to_play.append(sorted_hand[i])
			print("  - AI选择垫牌: %d张" % cards_to_play.size())

	if cards_to_play.size() > 0:
		# 使用统一的出牌函数
		if execute_play_cards(ai_player, cards_to_play):
			var pattern = GameRules.identify_pattern(cards_to_play, trump_suit, current_level)
			current_trick.append({
				"player_id": ai_player.player_id,
				"cards": cards_to_play,
				"pattern": pattern
			})

			if current_trick.size() == 4:
				await get_tree().create_timer(1.0).timeout
				evaluate_trick()
			else:
				next_player_turn()
		else:
			print("  ⚠ AI出牌失败！")
	else:
		print("  ⚠ AI没有可出的牌！")

func evaluate_trick():
	"""评估本轮出牌，判定赢家"""
	print("\n" + "-".repeat(60))
	print("[本轮结算]")

	# 显示本轮所有人的出牌
	for i in range(current_trick.size()):
		var play = current_trick[i]
		var player = players[play["player_id"]]
		var pattern_name = get_pattern_name(play["pattern"].pattern_type)
		print("  %d. %s: %s (%d张)" % [i+1, player.player_name, pattern_name, play["cards"].size()])

	# 比较所有出牌，找出赢家
	var lead_play = current_trick[0]
	var winner_play = lead_play

	for i in range(1, current_trick.size()):
		var current_play = current_trick[i]
		var compare_result = GameRules.compare_plays(winner_play["pattern"], current_play["pattern"], trump_suit, current_level)

		if compare_result < 0:
			winner_play = current_play

	var winner = players[winner_play["player_id"]]

	# 计算本轮分数
	var points = 0
	for play in current_trick:
		points += GameRules.calculate_points(play["cards"])

	team_scores[winner.team] += points

	print("  → 赢家: %s (队伍%d)" % [winner.player_name, winner.team + 1])
	print("  → 本轮得分: %d分" % points)
	print("  → 当前比分: 队伍1 %d分 | 队伍2 %d分" % [team_scores[0], team_scores[1]])

	if ui_manager:
		ui_manager.update_team_scores(team_scores[0], team_scores[1])
		ui_manager.show_center_message("%s 赢得本轮，得 %d 分" % [winner.player_name, points], 2.0)

	await get_tree().create_timer(2.0).timeout

	# 清理本轮出的牌
	print("\n[清理出牌区]")
	for play in current_trick:
		var player = players[play["player_id"]]
		print("  - %s 出的牌:" % player.player_name)
		for card in play["cards"]:
			print("    清理卡牌: %s (对象ID=%s, parent=%s)" % [
				card.get_card_name(),
				card.get_instance_id(),
				card.get_parent().name if card.get_parent() else "无"
			])

			# 检查这张卡牌是否还在玩家的hand数组中（不应该在）
			if player.hand.has(card):
				print("    ⚠⚠⚠ 严重错误：卡牌 %s 还在玩家 %s 的hand数组中！" % [card.get_card_name(), player.player_name])
				print("    ⚠⚠⚠ 这会导致手牌增多的bug！")
				# 强制从hand数组中移除
				player.hand.erase(card)
				print("    → 已强制从hand数组移除")

			if is_instance_valid(card) and card.get_parent():
				card.queue_free()
				print("    → 已调用queue_free()")

	current_trick.clear()
	print("[清理完成] current_trick已清空")

	# 验证所有玩家的hand数组大小
	print("\n[验证] 清理后各玩家手牌数:")
	for i in range(4):
		var p = players[i]
		print("  %s: hand数组=%d张, hand_container子节点=%d个" % [
			p.player_name,
			p.hand.size(),
			p.hand_container.get_child_count()
		])

	# 检查是否所有牌都出完了
	if players[0].get_hand_size() == 0:
		print("\n" + "=".repeat(60))
		print("=== 所有牌已出完，结算底牌 ===")
		print("=".repeat(60))
		await get_tree().create_timer(1.0).timeout

		var bottom_points = GameRules.calculate_points(bottom_cards)
		var multiplier = 2

		print("\n[底牌结算]")
		print("  - 底牌分数: %d分" % bottom_points)
		print("  - 倍数: ×%d" % multiplier)
		print("  - 最后一轮赢家: %s (队伍%d)" % [winner.player_name, winner.team + 1])

		if winner.team == current_bid["team"]:
			# 庄家队扣底
			team_scores[current_bid["team"]] += bottom_points * multiplier
			print("  - 庄家队扣底成功！获得 %d 分" % [bottom_points * multiplier])
			if ui_manager:
				ui_manager.show_center_message("庄家队扣底成功!+%d分" % [bottom_points * multiplier], 2.0)
				ui_manager.update_team_scores(team_scores[0], team_scores[1])
		else:
			# 对手队抠底
			var opponent_team = 1 - current_bid["team"]
			team_scores[opponent_team] += bottom_points * multiplier
			print("  - 对手队抠底成功！获得 %d 分" % [bottom_points * multiplier])
			if ui_manager:
				ui_manager.show_center_message("对手队抠底成功!+%d分" % [bottom_points * multiplier], 2.0)
				ui_manager.update_team_scores(team_scores[0], team_scores[1])

		print("  - 最终比分: 队伍1 %d分 | 队伍2 %d分" % [team_scores[0], team_scores[1]])

		await get_tree().create_timer(2.0).timeout
		end_round()
	else:
		# 继续下一轮，赢家先出牌
		current_player_index = winner_play["player_id"]
		print("\n[下一轮] 由赢家 %s 先出牌" % players[current_player_index].player_name)
		await get_tree().create_timer(1.0).timeout

		if ui_manager:
			ui_manager.update_turn_message("轮到 %s 出牌" % players[current_player_index].player_name)
			ui_manager.highlight_current_player(current_player_index)

		if players[current_player_index].player_type == Player.PlayerType.AI:
			await get_tree().create_timer(1.0).timeout
			ai_play_turn(players[current_player_index])

# =====================================
# 结束和升级
# =====================================

func end_round():
	"""本局结束，计算升级"""
	current_phase = GamePhase.SCORING

	print("\n" + "=".repeat(60))
	print("=== 本局结束，计算升级 ===")
	print("=".repeat(60))

	var dealer_team = current_bid["team"]  # 庄家队（叫牌成功的队）
	var attacker_team = 1 - dealer_team    # 对手队（闲家）
	var attacker_score = team_scores[attacker_team]  # 对手队得分

	print("\n[最终得分]")
	print("  - 庄家队 (队伍%d): %d分" % [dealer_team + 1, team_scores[dealer_team]])
	print("  - 对手队 (队伍%d): %d分" % [attacker_team + 1, attacker_score])

	var levels_to_advance = 0
	var winning_team = -1
	var dealer_changed = false

	print("\n[升级规则判定]")
	print("  - 根据对手队得分: %d分" % attacker_score)

	# 标准升级规则（根据对手队得分）：
	# 对手得分 < 40分：庄家升3级
	# 对手得分 40-79分：庄家升2级
	# 对手得分 80-119分：庄家升1级
	# 对手得分 120-159分：对手升1级，庄家换到对手队
	# 对手得分 160-199分：对手升2级，庄家换到对手队
	# 对手得分 ≥ 200分：对手升3级，庄家换到对手队

	if attacker_score >= 200:
		levels_to_advance = 3
		winning_team = attacker_team
		team_levels[attacker_team] += levels_to_advance
		dealer_index = (dealer_index + 1) % 4
		dealer_changed = true
		print("  - 对手得分≥200: 对手大胜！升3级，庄家轮换")
		if ui_manager:
			ui_manager.show_center_message("队伍%d 大胜！升%d级！" % [attacker_team + 1, levels_to_advance], 3.0)
	elif attacker_score >= 160:
		levels_to_advance = 2
		winning_team = attacker_team
		team_levels[attacker_team] += levels_to_advance
		dealer_index = (dealer_index + 1) % 4
		dealer_changed = true
		print("  - 对手得分160-199: 对手获胜！升2级，庄家轮换")
		if ui_manager:
			ui_manager.show_center_message("队伍%d 获胜！升%d级！" % [attacker_team + 1, levels_to_advance], 3.0)
	elif attacker_score >= 120:
		levels_to_advance = 1
		winning_team = attacker_team
		team_levels[attacker_team] += levels_to_advance
		dealer_index = (dealer_index + 1) % 4
		dealer_changed = true
		print("  - 对手得分120-159: 对手获胜！升1级，庄家轮换")
		if ui_manager:
			ui_manager.show_center_message("队伍%d 获胜！升%d级！" % [attacker_team + 1, levels_to_advance], 3.0)
	elif attacker_score >= 80:
		levels_to_advance = 1
		winning_team = dealer_team
		team_levels[dealer_team] += levels_to_advance
		print("  - 对手得分80-119: 庄家守住！升1级，庄家不变")
		if ui_manager:
			ui_manager.show_center_message("队伍%d 守住！升%d级！" % [dealer_team + 1, levels_to_advance], 3.0)
	elif attacker_score >= 40:
		levels_to_advance = 2
		winning_team = dealer_team
		team_levels[dealer_team] += levels_to_advance
		print("  - 对手得分40-79: 庄家守住！升2级，庄家不变")
		if ui_manager:
			ui_manager.show_center_message("队伍%d 守住！升%d级！" % [dealer_team + 1, levels_to_advance], 3.0)
	else:
		levels_to_advance = 3
		winning_team = dealer_team
		team_levels[dealer_team] += levels_to_advance
		print("  - 对手得分<40: 庄家大胜！升3级，庄家不变")
		if ui_manager:
			ui_manager.show_center_message("队伍%d 大胜！升%d级！" % [dealer_team + 1, levels_to_advance], 3.0)

	print("\n[升级结果]")
	print("  - 获胜队伍: 队伍%d" % [winning_team + 1])
	print("  - 升级数: %d级" % levels_to_advance)
	print("  - 队伍1当前等级: %d" % team_levels[0])
	print("  - 队伍2当前等级: %d" % team_levels[1])
	if dealer_changed:
		print("  - 庄家轮换到: %s (player_id=%d)" % [players[dealer_index].player_name, dealer_index])
	else:
		print("  - 庄家保持: %s (player_id=%d)" % [players[dealer_index].player_name, dealer_index])

	# 更新当前级别（取两队中最高的）
	current_level = max(team_levels[0], team_levels[1])
	print("  - 下一局等级: %d" % current_level)

	await get_tree().create_timer(3.0).timeout

	# 检查游戏是否结束
	if check_game_over():
		print("\n游戏结束！有队伍达到A（14级）")
		show_game_over_screen()
	else:
		print("\n准备开始下一局...")
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
	team_levels = [2, 2]
	current_level = 2
	total_rounds_played = 0
	dealer_index = 0
	
	# 清理玩家手牌
	for player in players:
		for card in player.hand:
			if is_instance_valid(card):
				card.queue_free()
		player.hand.clear()
		player.selected_cards.clear()
	
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
