# deck.gd - 牌堆管理
extends Node
class_name Deck

var cards: Array[Card] = []
var num_decks: int = 2

func _init(decks: int = 2):
	num_decks = decks

func create_deck(_parent_node: Node = null):
	cards.clear()
	
	for _deck_num in num_decks:
		# 创建4种花色的牌
		for suit in [Card.Suit.SPADE, Card.Suit.HEART, Card.Suit.CLUB, Card.Suit.DIAMOND]:
			for rank in range(Card.Rank.TWO, Card.Rank.ACE + 1):
				var card = Card.new(suit, rank)
				cards.append(card)
		
		# 添加大小王
		var small_joker = Card.new(Card.Suit.JOKER, Card.Rank.SMALL_JOKER)
		var big_joker = Card.new(Card.Suit.JOKER, Card.Rank.BIG_JOKER)
		cards.append(small_joker)
		cards.append(big_joker)

func shuffle():
	cards.shuffle()

func deal(num_cards: int) -> Array[Card]:
	var dealt_cards: Array[Card] = []
	for _i in num_cards:
		if cards.size() > 0:
			dealt_cards.append(cards.pop_back())
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
