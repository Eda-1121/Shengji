# game_rules.gd - 改进版游戏规则管理器
extends RefCounted
class_name GameRules

# 牌型枚举
enum CardPattern {
	INVALID,      # 无效牌型
	SINGLE,       # 单张
	PAIR,         # 对子
	TRACTOR,      # 拖拉机（连对）
	THROW         # 甩牌（多个单张或对子，但不同点数）
}

# 牌型结构
class PlayPattern:
	var pattern_type: CardPattern
	var cards: Array[Card]
	var suit: Card.Suit
	var length: int
	var rank_start: int
	var is_trump: bool = false
	
	func _init(type: CardPattern, card_list: Array[Card]):
		pattern_type = type
		cards = card_list
		if cards.size() > 0:
			suit = cards[0].suit
			rank_start = cards[0].rank
			is_trump = cards[0].is_trump
		length = cards.size()

# ============================================
# 牌型识别
# ============================================

static func identify_pattern(cards: Array[Card], trump_suit: Card.Suit, current_rank: int) -> PlayPattern:
	"""识别牌型"""
	if cards.is_empty():
		return PlayPattern.new(CardPattern.INVALID, [])
	
	# 更新所有牌的主牌状态
	for card in cards:
		card.set_trump(trump_suit, current_rank)
	
	# 按点数和花色排序
	var sorted_cards = cards.duplicate()
	sorted_cards.sort_custom(func(a, b): 
		if a.is_trump != b.is_trump:
			return b.is_trump  # 主牌排前面
		if a.suit != b.suit:
			return a.suit < b.suit
		return a.rank < b.rank
	)
	
	# 单张
	if sorted_cards.size() == 1:
		return PlayPattern.new(CardPattern.SINGLE, sorted_cards)
	
	# 对子
	if sorted_cards.size() == 2:
		# 对子只需要rank相同即可，不需要花色相同
		if sorted_cards[0].rank == sorted_cards[1].rank:
			return PlayPattern.new(CardPattern.PAIR, sorted_cards)
		else:
			return PlayPattern.new(CardPattern.THROW, sorted_cards)
	
	# 拖拉机或甩牌
	if sorted_cards.size() >= 4:
		var tractor = check_tractor(sorted_cards, trump_suit, current_rank)
		if tractor != null:
			return tractor
	
	# 甩牌
	return PlayPattern.new(CardPattern.THROW, sorted_cards)

static func check_tractor(sorted_cards: Array[Card], trump_suit: Card.Suit, current_rank: int) -> PlayPattern:
	"""检查是否是拖拉机（连对）"""
	if sorted_cards.size() % 2 != 0:
		return null
	
	# 更新主牌状态
	for card in sorted_cards:
		card.set_trump(trump_suit, current_rank)
	
	# 检查是否全部是对子
	var pairs = []
	for i in range(0, sorted_cards.size(), 2):
		if i + 1 >= sorted_cards.size():
			return null
		var card1 = sorted_cards[i]
		var card2 = sorted_cards[i + 1]

		# 对子只需要rank相同即可
		if card1.rank != card2.rank:
			return null
		
		# 必须都是主牌或都是副牌
		if card1.is_trump != card2.is_trump:
			return null
		
		pairs.append({
			"rank": card1.rank,
			"suit": card1.suit,
			"is_trump": card1.is_trump
		})
	
	# 检查对子是否连续
	for i in range(pairs.size() - 1):
		var curr_pair = pairs[i]
		var next_pair = pairs[i + 1]
		
		# 必须是相同花色或都是主牌
		if curr_pair["is_trump"] != next_pair["is_trump"]:
			return null
		
		if not curr_pair["is_trump"] and curr_pair["suit"] != next_pair["suit"]:
			return null
		
		# 点数必须连续
		if next_pair["rank"] - curr_pair["rank"] != 1:
			return null
	
	return PlayPattern.new(CardPattern.TRACTOR, sorted_cards)

# ============================================
# 跟牌规则
# ============================================

static func can_follow(follow_pattern: PlayPattern, lead_pattern: PlayPattern, hand: Array[Card], trump_suit: Card.Suit, current_rank: int) -> bool:
	"""检查跟牌是否合法"""
	# 牌数必须相同
	if follow_pattern.length != lead_pattern.length:
		return false
	
	# 更新手牌的主牌状态
	for card in hand:
		card.set_trump(trump_suit, current_rank)
	
	var lead_is_trump = lead_pattern.cards[0].is_trump
	var lead_suit = lead_pattern.cards[0].suit
	
	# 找出同花色的牌
	var same_suit_cards: Array[Card] = []
	for card in hand:
		if lead_is_trump:
			if card.is_trump:
				same_suit_cards.append(card)
		else:
			if not card.is_trump and card.suit == lead_suit:
				same_suit_cards.append(card)
	
	# 如果没有同花色，可以出任意牌
	if same_suit_cards.is_empty():
		return true
	
	# 根据首家牌型要求跟牌
	match lead_pattern.pattern_type:
		CardPattern.SINGLE:
			# 跟单张：必须出同花色
			return is_same_suit_as_lead(follow_pattern.cards[0], lead_pattern.cards[0], trump_suit, current_rank)
		
		CardPattern.PAIR:
			# 跟对子规则：
			# 1. 有同花色对子，必须出同花色对子
			# 2. 没有同花色对子，但有2张或更多同花色，必须出2张同花色
			# 3. 只有1张同花色，必须出这1张同花色 + 1张其它花色
			# 4. 没有同花色，可以出任意2张（不需要相同花色）

			var pairs = find_pairs_in_cards(same_suit_cards)
			if pairs.size() > 0:
				# 情况1：有同花色对子，必须出同花色对子
				return follow_pattern.pattern_type == CardPattern.PAIR and \
					   is_same_suit_as_lead(follow_pattern.cards[0], lead_pattern.cards[0], trump_suit, current_rank)

			# 没有同花色对子
			if same_suit_cards.size() >= 2:
				# 情况2：有2张或更多同花色，必须出2张同花色
				var all_same_suit = true
				for card in follow_pattern.cards:
					if not is_same_suit_as_lead(card, lead_pattern.cards[0], trump_suit, current_rank):
						all_same_suit = false
						break
				return all_same_suit
			elif same_suit_cards.size() == 1:
				# 情况3：只有1张同花色，必须出这1张同花色 + 1张其它花色
				var has_one_same_suit = false
				for card in follow_pattern.cards:
					if is_same_suit_as_lead(card, lead_pattern.cards[0], trump_suit, current_rank):
						has_one_same_suit = true
						break
				return has_one_same_suit
			else:
				# 情况4：没有同花色，可以出任意2张
				return true
		
		CardPattern.TRACTOR:
			# 跟拖拉机：有同花色拖拉机必须出拖拉机
			var tractors = find_tractors_in_cards(same_suit_cards, lead_pattern.length, trump_suit, current_rank)
			if tractors.size() > 0:
				return follow_pattern.pattern_type == CardPattern.TRACTOR and \
					   is_same_suit_as_lead(follow_pattern.cards[0], lead_pattern.cards[0], trump_suit, current_rank)
			
			# 没有拖拉机，有对子必须先出对子
			var pairs = find_pairs_in_cards(same_suit_cards)
			if pairs.size() > 0:
				# 必须尽量出对子
				return true
			
			# 没有对子，可以出任意牌
			return true
		
		CardPattern.THROW:
			# 甩牌：需要验证甩牌是否成功
			# 简化处理：只要花色对就行
			return true
	
	return true

static func is_same_suit_as_lead(card: Card, lead_card: Card, trump_suit: Card.Suit, current_rank: int) -> bool:
	"""检查两张牌是否同花色（考虑主牌）"""
	card.set_trump(trump_suit, current_rank)
	lead_card.set_trump(trump_suit, current_rank)
	
	if lead_card.is_trump:
		return card.is_trump
	else:
		return not card.is_trump and card.suit == lead_card.suit

static func get_valid_follow_cards(hand: Array[Card], lead_pattern: PlayPattern, trump_suit: Card.Suit, current_rank: int) -> Array:
	"""获取合法的跟牌（返回所有可能的跟牌组合）"""
	if lead_pattern.pattern_type == CardPattern.INVALID:
		return []
	
	# 更新手牌的主牌状态
	for card in hand:
		card.set_trump(trump_suit, current_rank)
	
	var lead_is_trump = lead_pattern.cards[0].is_trump
	var lead_suit = lead_pattern.cards[0].suit
	
	# 找出同花色的牌
	var same_suit_cards: Array[Card] = []
	for card in hand:
		if lead_is_trump:
			if card.is_trump:
				same_suit_cards.append(card)
		else:
			if not card.is_trump and card.suit == lead_suit:
				same_suit_cards.append(card)
	
	# 如果没有同花色，可以出任意牌
	if same_suit_cards.is_empty():
		if hand.size() >= lead_pattern.length:
			return [hand.slice(0, lead_pattern.length)]
		return []
	
	# 根据首家牌型返回合法跟牌
	match lead_pattern.pattern_type:
		CardPattern.SINGLE:
			var valid_plays = []
			for card in same_suit_cards:
				valid_plays.append([card])
			return valid_plays
		
		CardPattern.PAIR:
			# 跟对子的优先级：
			# 1. 有同花色对子，出同花色对子
			# 2. 没有对子但有2张或更多同花色，出2张同花色
			# 3. 只有1张同花色，出这1张同花色 + 1张其它花色
			# 4. 没有同花色，出任意2张

			var pairs = find_pairs_in_cards(same_suit_cards)
			if pairs.size() > 0:
				# 情况1：有同花色对子
				return pairs

			if same_suit_cards.size() >= 2:
				# 情况2：没有对子，但有2张或更多同花色
				return [[same_suit_cards[0], same_suit_cards[1]]]

			if same_suit_cards.size() == 1:
				# 情况3：只有1张同花色，组合1张同花色 + 1张其它花色
				var other_cards: Array[Card] = []
				for card in hand:
					if not same_suit_cards.has(card):
						other_cards.append(card)
				if other_cards.size() > 0:
					return [[same_suit_cards[0], other_cards[0]]]

			# 情况4：没有同花色，出任意2张
			if hand.size() >= 2:
				return [hand.slice(0, 2)]
			return []
		
		CardPattern.TRACTOR:
			var tractors = find_tractors_in_cards(same_suit_cards, lead_pattern.length, trump_suit, current_rank)
			if tractors.size() > 0:
				return tractors
			
			# 没有拖拉机，尽量出对子
			var pairs = find_pairs_in_cards(same_suit_cards)
			if pairs.size() > 0:
				var result = []
				var needed = lead_pattern.length
				for pair in pairs:
					result.append_array(pair)
					needed -= 2
					if needed <= 0:
						break
				if result.size() >= lead_pattern.length:
					return [result.slice(0, lead_pattern.length)]
			
			# 出同花色的牌
			if same_suit_cards.size() >= lead_pattern.length:
				return [same_suit_cards.slice(0, lead_pattern.length)]
			
			# 不够同花色，垫其他牌
			if hand.size() >= lead_pattern.length:
				return [hand.slice(0, lead_pattern.length)]
			return []
		
		CardPattern.THROW:
			if same_suit_cards.size() >= lead_pattern.length:
				return [same_suit_cards.slice(0, lead_pattern.length)]
			if hand.size() >= lead_pattern.length:
				return [hand.slice(0, lead_pattern.length)]
			return []
	
	return []

static func find_pairs_in_cards(cards: Array[Card]) -> Array:
	"""在牌中找出所有对子"""
	var sorted_cards: Array[Card] = []
	sorted_cards.assign(cards)
	sorted_cards.sort_custom(func(a, b): 
		if a.suit != b.suit:
			return a.suit < b.suit
		return a.rank < b.rank
	)
	
	var pairs = []
	var i = 0
	while i < sorted_cards.size() - 1:
		if sorted_cards[i].rank == sorted_cards[i + 1].rank and \
		   sorted_cards[i].suit == sorted_cards[i + 1].suit:
			pairs.append([sorted_cards[i], sorted_cards[i + 1]])
			i += 2
		else:
			i += 1
	
	return pairs

static func find_tractors_in_cards(cards: Array[Card], min_length: int, trump_suit: Card.Suit, current_rank: int) -> Array:
	"""在牌中找出拖拉机"""
	for card in cards:
		card.set_trump(trump_suit, current_rank)
	
	var pairs = find_pairs_in_cards(cards)
	var required_pairs = min_length / 2
	if pairs.size() < required_pairs:
		return []
	
	# 检查对子是否连续
	var tractors = []
	for i in range(pairs.size() - required_pairs + 1):
		var tractor_cards = []
		var is_valid = true
		
		for j in range(required_pairs):
			var pair_idx = i + j
			if pair_idx >= pairs.size():
				is_valid = false
				break
			
			if j > 0:
				var prev_pair = pairs[i + j - 1]
				var curr_pair = pairs[pair_idx]
				
				# 检查是否同花色（或都是主牌）
				if prev_pair[0].is_trump != curr_pair[0].is_trump:
					is_valid = false
					break
				
				if not prev_pair[0].is_trump and prev_pair[0].suit != curr_pair[0].suit:
					is_valid = false
					break
				
				# 检查点数是否连续
				if curr_pair[0].rank - prev_pair[0].rank != 1:
					is_valid = false
					break
			
			tractor_cards.append_array(pairs[pair_idx])
		
		if is_valid and tractor_cards.size() == min_length:
			tractors.append(tractor_cards)
	
	return tractors

# ============================================
# 比牌逻辑
# ============================================

static func compare_plays(play1: PlayPattern, play2: PlayPattern, trump_suit: Card.Suit, current_rank: int) -> int:
	"""
	比较两次出牌
	返回 1: play1 大
	返回 -1: play2 大
	返回 0: 相等
	"""
	# 更新主牌状态
	for card in play1.cards:
		card.set_trump(trump_suit, current_rank)
	for card in play2.cards:
		card.set_trump(trump_suit, current_rank)
	
	# 如果一个是主牌一个不是，主牌大
	var play1_is_trump = play1.cards[0].is_trump
	var play2_is_trump = play2.cards[0].is_trump
	
	if play1_is_trump and not play2_is_trump:
		return 1
	elif not play1_is_trump and play2_is_trump:
		return -1
	
	# 如果花色不同（都不是主牌），首家大
	if not play1_is_trump and not play2_is_trump:
		if play1.cards[0].suit != play2.cards[0].suit:
			return 1  # 首家大
	
	# 牌型不同，按优先级比较
	if play1.pattern_type != play2.pattern_type:
		# 拖拉机 > 对子 > 单张 > 甩牌
		var priority = {
			CardPattern.TRACTOR: 3,
			CardPattern.PAIR: 2,
			CardPattern.SINGLE: 1,
			CardPattern.THROW: 0
		}
		var p1 = priority.get(play1.pattern_type, 0)
		var p2 = priority.get(play2.pattern_type, 0)
		if p1 > p2:
			return 1
		elif p1 < p2:
			return -1
		return 0
	
	# 相同牌型，比较最大的牌
	var card1 = get_largest_card(play1.cards, trump_suit, current_rank)
	var card2 = get_largest_card(play2.cards, trump_suit, current_rank)
	
	return card1.compare_to(card2, trump_suit, current_rank)

static func get_largest_card(cards: Array[Card], trump_suit: Card.Suit, current_rank: int) -> Card:
	"""获取一组牌中最大的牌"""
	if cards.is_empty():
		return null
	
	var largest = cards[0]
	for card in cards:
		card.set_trump(trump_suit, current_rank)
		largest.set_trump(trump_suit, current_rank)
		if card.compare_to(largest, trump_suit, current_rank) > 0:
			largest = card
	
	return largest

# ============================================
# 计分
# ============================================

static func calculate_points(cards: Array) -> int:
	"""计算一组牌的分数"""
	var total = 0
	for card in cards:
		if card is Card:
			total += card.points
	return total

# ============================================
# 验证出牌
# ============================================

static func validate_play(cards: Array[Card], hand: Array[Card]) -> bool:
	"""验证是否可以出这些牌"""
	for card in cards:
		if not hand.has(card):
			return false
	return true
