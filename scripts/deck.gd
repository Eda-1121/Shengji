# deck.gd - 牌堆管理（唯一卡牌对象架构）
extends Node
class_name Deck

var cards: Array[Card] = []  # 唯一卡牌对象存储
var num_decks: int = 2
var card_registry: Dictionary = {}  # 卡牌对象ID注册表，用于验证唯一性

func _init(decks: int = 2):
	num_decks = decks

func create_deck(_parent_node: Node = null):
	"""创建唯一卡牌对象（每张牌只创建一次，全程使用同一对象）"""
	cards.clear()
	card_registry.clear()

	print("\n=== 创建牌堆（唯一对象架构） ===")

	for _deck_num in num_decks:
		# 创建4种花色的牌
		for suit in [Card.Suit.SPADE, Card.Suit.HEART, Card.Suit.CLUB, Card.Suit.DIAMOND]:
			for rank in range(Card.Rank.TWO, Card.Rank.ACE + 1):
				var card = Card.new(suit, rank)  # 创建唯一对象实例
				cards.append(card)
				# 注册卡牌对象ID
				var card_id = card.get_instance_id()
				card_registry[card_id] = {
					"name": card.get_card_name(),
					"created": true
				}

		# 添加大小王
		var small_joker = Card.new(Card.Suit.JOKER, Card.Rank.SMALL_JOKER)
		var big_joker = Card.new(Card.Suit.JOKER, Card.Rank.BIG_JOKER)
		cards.append(small_joker)
		cards.append(big_joker)
		card_registry[small_joker.get_instance_id()] = {"name": "small_joker", "created": true}
		card_registry[big_joker.get_instance_id()] = {"name": "big_joker", "created": true}

	print("  - 创建了 %d 张唯一卡牌对象" % cards.size())
	print("  - 卡牌注册表大小: %d" % card_registry.size())
	print("=================================\n")

func shuffle():
	cards.shuffle()

func verify_card_is_original(card: Card) -> bool:
	"""验证卡牌是否是原始创建的唯一对象"""
	var card_id = card.get_instance_id()
	if not card_registry.has(card_id):
		print("⚠ 警告：发现未注册的卡牌对象！ID=%s, Name=%s" % [card_id, card.get_card_name()])
		return false
	return true

func deal(num_cards: int) -> Array[Card]:
	"""发牌（确保发的是唯一对象引用，不是副本）"""
	var dealt_cards: Array[Card] = []
	for _i in num_cards:
		if cards.size() > 0:
			var card = cards.pop_back()  # 从牌堆中取出（引用传递，不复制）
			# 验证对象唯一性
			if not verify_card_is_original(card):
				print("⚠ 错误：发牌时检测到非原始对象！")
			dealt_cards.append(card)
	return dealt_cards

func deal_to_players(players: Array) -> Array[Card]:
	var bottom_cards: Array[Card] = []
	
	# 先留出底牌
	for _i in 8:
		if cards.size() > 0:
			bottom_cards.append(cards.pop_back())
	
	# 给每个玩家发25张
	for player in players:
		var hand = deal(25)
		player.receive_cards(hand)
	
	return bottom_cards

func get_remaining_count() -> int:
	return cards.size()
