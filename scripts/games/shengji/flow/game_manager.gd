# game_manager.gd - Shengji game manager
extends Node

const ShengjiCardLogic = preload("res://scripts/games/shengji/rules/shengji_card_logic.gd")
const ShengjiAiLogic = preload("res://scripts/games/shengji/ai/shengji_ai_logic.gd")
const ShengjiBiddingRules = preload("res://scripts/games/shengji/rules/shengji_bidding_rules.gd")
const ShengjiScoring = preload("res://scripts/games/shengji/rules/shengji_scoring.gd")
const ShengjiTableLayout = preload("res://scripts/games/shengji/table/shengji_table_layout.gd")

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

const VOID_TRUMP = -1
var player_void_suits: Array = [[], [], [], []]

# Bidding state
var current_bid = {
	"team": -1,
	"suit": Card.Suit.SPADE,
	"count": 0,
	"player_id": -1
}
var bidding_round: int = 0
var max_bidding_rounds: int = 8

# Game stats
var total_rounds_played: int = 0

var play_area_positions: Array = []

const PLAYED_CARD_SPACING = 42.0
const PLAYED_CARD_MIN_SPACING = 30.0
const PLAYED_CARD_MAX_WIDTH = 230.0

# UI manager reference
var ui_manager = null

# Bid decision wait state
var waiting_for_bid_decision: bool = false
var bid_decision_made: bool = false

signal phase_changed(phase: GamePhase)
signal game_over(winner_team: int)

func _ready():
	print("=== GameManager Initialize (Phase 2) ===")
	randomize()
	if not GameConfig.play_hints_changed.is_connected(_on_play_hints_changed):
		GameConfig.play_hints_changed.connect(_on_play_hints_changed)
	if not GameConfig.language_changed.is_connected(_on_language_changed):
		GameConfig.language_changed.connect(_on_language_changed)
	if not get_viewport().size_changed.is_connected(apply_layout):
		get_viewport().size_changed.connect(apply_layout)
	initialize_game()

func initialize_game():
	print("=== Initialize game with ", GameConfig.num_decks, " decks ===")
	var player_positions = get_player_positions()
	
	for i in 4:
		var player = Player.new()
		player.player_id = i
		player.player_name = get_player_display_name(i)
		player.team = i % 2
		player.player_type = Player.PlayerType.AI if i > 0 else Player.PlayerType.HUMAN
		player.position = player_positions[i]
		players.append(player)
		add_child(player)
	
	apply_layout()
	start_new_round()

func apply_layout():
	play_area_positions = get_play_area_positions()
	var player_positions = get_player_positions()
	for i in range(min(players.size(), player_positions.size())):
		players[i].position = player_positions[i]
		if players[i].hand_container:
			players[i].update_hand_display(false)

func get_table_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func get_player_positions() -> Array:
	return ShengjiTableLayout.get_player_positions(get_table_size())

func get_play_area_positions() -> Array:
	return ShengjiTableLayout.get_play_area_positions(get_table_size())

func cleanup_round_cards():
	"""Remove cards from the previous round so the next round starts with a fresh deck."""
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
	print("=== Start new round ===")
	total_rounds_played += 1

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

	# Step 1: Shuffle
	print("Step 1: Shuffle")
	deck.shuffle()

	# Step 2: Prepare 8 bottom cards
	print("Step 2: Prepare 8 bottom cards")
	bottom_cards.clear()
	for _i in 8:
		if deck.cards.size() > 0:
			bottom_cards.append(deck.cards.pop_back())
	print("Bottom cards prepared. Remaining cards: ", deck.cards.size())

	players[dealer_index].is_dealer = true

	# InitializeUI
	if ui_manager:
		ui_manager.update_level(current_level)
		ui_manager.update_trump_suit("?")
		ui_manager.update_team_scores(0, 0)
		ui_manager.update_turn_message(GameConfig.text("dealing"))
		ui_manager.show_bury_button(false)
		ui_manager.set_buttons_enabled(false)

		if ui_manager.has_node("BiddingUI"):
			var bidding_ui = ui_manager.get_node("BiddingUI")
			bidding_ui.show_bidding_ui(false)
			bidding_ui.update_current_bid(GameConfig.text("current_bid_none"))

	phase_changed.emit(current_phase)

	# Step 3: Deal one card at a time; bidding is allowed while dealing.
	print("Step 3: Start dealing; bids are allowed while dealing")
	await get_tree().process_frame
	start_dealing_cards()

# =====================================
# =====================================

func start_dealing_cards():
	"""Deal cards one at a time."""
	players[0].visible = true

	for i in range(1, 4):
		players[i].visible = false

	var total_cards = deck.cards.size()
	var card_index = 0
	var current_player = dealer_index

	while deck.cards.size() > 0:
		var card = deck.cards.pop_back()
		var player = players[current_player]

		player.receive_cards([card])

		if player.player_type == Player.PlayerType.HUMAN:
			card.set_face_up(true, false)
			card.visible = true
			player.set_card_selectable(false)
			SoundManager.play_deal()
		else:
			card.visible = false
			player.set_card_selectable(false)

		card_index += 1

		if ui_manager:
			ui_manager.update_turn_message(GameConfig.text("dealing_progress") % [card_index, total_cards])

		await check_and_handle_bidding(player, card)

		# nextPlayer 
		current_player = (current_player + 1) % 4

		await get_tree().create_timer(0.1).timeout

	# DealComplete
	await finish_dealing()

func check_and_handle_bidding(player: Player, latest_card: Card):
	"""Check whether the player can bid and handle the bid opportunity."""
	var level_cards = []
	for card in player.hand:
		if card.rank == current_level:
			level_cards.append(card)

	if level_cards.is_empty():
		return

	var suit_counts = {}
	for card in level_cards:
		if not suit_counts.has(card.suit):
			suit_counts[card.suit] = 0
		suit_counts[card.suit] += 1

	var max_count = 0
	var max_suit = null
	for suit in suit_counts:
		if suit_counts[suit] > max_count:
			max_count = suit_counts[suit]
			max_suit = suit

	if player.player_type == Player.PlayerType.HUMAN and max_count > 0:
		var available_suits = []
		var valid_suit_counts = {}
		for suit in suit_counts:
			var count = suit_counts[suit]
			if can_make_bid(player, suit, count):
				available_suits.append(suit)
				valid_suit_counts[suit] = count

		if not available_suits.is_empty():
			if ui_manager and ui_manager.has_node("BiddingUI"):
				var bidding_ui = ui_manager.get_node("BiddingUI")
				bidding_ui.show_bidding_options(available_suits, valid_suit_counts)

			# setwaitflag
			waiting_for_bid_decision = true
			bid_decision_made = false

			while waiting_for_bid_decision and not bid_decision_made:
				await get_tree().create_timer(0.1).timeout

			waiting_for_bid_decision = false

	# AIPlayer automaticBidlogic
	elif player.player_type == Player.PlayerType.AI:
		if max_count > 0 and can_make_bid(player, max_suit, max_count):
			if max_count >= 2 or current_bid["count"] == 0:
				make_bid(player, max_suit, max_count)
				print("AI ", player.player_name, " bids with count: ", max_count)

func finish_dealing():
	"""After dealing, offer final bid opportunities and decide trump."""
	print("=== finish_dealing() called ===")
	print("Step 4: Dealing finished; checking final bid opportunities")

	if ui_manager:
		ui_manager.update_turn_message(GameConfig.text("dealing_final_bid"))

	# Step 4: Final bid opportunity after dealing.
	# Check whether any player can counter-bid with more level cards.
	await check_final_bidding_opportunity()

	# Step 5: Determine trump and dealer.
	print("Step 5: Determine trump and dealer")
	if ui_manager and ui_manager.has_node("BiddingUI"):
		var bidding_ui = ui_manager.get_node("BiddingUI")
		bidding_ui.hide_bidding_ui()

	if current_bid["count"] == 0:
		trump_suit = Card.Suit.SPADE
		current_bid["suit"] = trump_suit
		current_bid["team"] = players[dealer_index].team
		current_bid["player_id"] = dealer_index
		print("No bid. Dealer team defaults to Spades")
	else:
		trump_suit = current_bid["suit"]
		dealer_index = current_bid["player_id"]
		print("Bid accepted. New dealer: ", players[dealer_index].player_name, " (player_id=", dealer_index, ")")

	if ui_manager:
		ui_manager.update_trump_suit(get_trump_symbol())
		ui_manager.show_center_message(GameConfig.text("team_bid_trump") % [get_team_name(current_bid["team"]), get_trump_symbol()], 2.0)

	await get_tree().create_timer(2.0).timeout

	# Step 6: Enter burying phase.
	print("Step 6: Enter burying phase")
	if players[dealer_index].player_type == Player.PlayerType.HUMAN:
		print("Dealer is human; enter human burying phase")
		start_burying_phase()
	else:
		print("Dealer is AI; enter AI burying phase")
		await ai_bury_bottom()

# =====================================
# =====================================

func check_final_bidding_opportunity():
	"""Final bid opportunity after dealing."""
	print("Checking all players for final bid opportunities...")

	for player in players:
		var level_cards = []
		for card in player.hand:
			if card.rank == current_level:
				level_cards.append(card)

		if level_cards.is_empty():
			continue

		var suit_counts = {}
		for card in level_cards:
			if not suit_counts.has(card.suit):
				suit_counts[card.suit] = 0
			suit_counts[card.suit] += 1

		var max_count = 0
		var max_suit = null
		for suit in suit_counts:
			if suit_counts[suit] > max_count:
				max_count = suit_counts[suit]
				max_suit = suit

		# Counter-bids require more level cards than the current bid.
		if max_count > current_bid["count"]:
			print(player.player_name, " has ", max_count, " level cards and can counter-bid")

			if player.player_type == Player.PlayerType.HUMAN:
				# humanPlayer ，showBidUI
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
						ui_manager.show_center_message(GameConfig.text("final_bid_opportunity"), 2.0)

					# waitPlayer decision
					waiting_for_bid_decision = true
					bid_decision_made = false
					while waiting_for_bid_decision and not bid_decision_made:
						await get_tree().create_timer(0.1).timeout
					waiting_for_bid_decision = false
			else:
				# AI decides automatically whether to counter-bid.
				if max_count > current_bid["count"] + 1:  # AI counter-bids only with a clear advantage.
					print("AI ", player.player_name, " decides to counter-bid")
					make_bid(player, max_suit, max_count)
					await get_tree().create_timer(2.0).timeout
				else:
					print("AI ", player.player_name, " passes on counter-bid")

	print("Final bid opportunity ended")

func start_bidding_phase():
	"""Start the bidding phase."""
	current_player_index = dealer_index
	process_bidding_turn()

func process_bidding_turn():
	"""Process the current player bid turn."""
	if bidding_round >= max_bidding_rounds:
		# BidEnd
		finish_bidding()
		return
	
	var current_player = players[current_player_index]
	
	if ui_manager:
		ui_manager.update_turn_message(GameConfig.text("player_bidding") % current_player.player_name)

	if current_player.player_type == Player.PlayerType.HUMAN:
		# humanPlayer ，waitUIinput
		if ui_manager and ui_manager.has_node("BiddingUI"):
			var bidding_ui = ui_manager.get_node("BiddingUI")
			bidding_ui.enable_buttons(true)
	else:
		# AIPlayer ，automaticBid
		await get_tree().create_timer(1.5).timeout
		ai_make_bid(current_player)

func _on_player_bid_made(suit: Card.Suit, count: int):
	"""Player makes a bid."""
	var player = players[0]

	if not can_make_bid(player, suit, count):
		if ui_manager:
			ui_manager.show_center_message(GameConfig.text("invalid_bid"), 1.5)
		return

	# executeBid
	make_bid(player, suit, count)

	# disableBidbutton
	if ui_manager and ui_manager.has_node("BiddingUI"):
		var bidding_ui = ui_manager.get_node("BiddingUI")
		bidding_ui.enable_buttons(false)

	# setdecisionCompleteflag，notifycontinueDeal
	bid_decision_made = true

func _on_player_bid_passed():
	"""Player passes."""
	# disableBidbutton
	if ui_manager and ui_manager.has_node("BiddingUI"):
		var bidding_ui = ui_manager.get_node("BiddingUI")
		bidding_ui.enable_buttons(false)

	# setdecisionCompleteflag，notifycontinueDeal
	bid_decision_made = true

func can_make_bid(player: Player, suit: Card.Suit, count: int) -> bool:
	return ShengjiBiddingRules.can_make_bid(player.team, suit, count, current_bid)

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
		var message = GameConfig.text("player_bids") % [player.player_name, suit_name]
		ui_manager.show_center_message(message, 2.0)
		
		if ui_manager.has_node("BiddingUI"):
			var bidding_ui = ui_manager.get_node("BiddingUI")
			bidding_ui.update_current_bid(GameConfig.text("current_bid") % [player.player_name, suit_name])

func ai_make_bid(ai_player: Player):
	"""AI bidding logic."""
	var level_cards = []
	for card in ai_player.hand:
		if card.rank == current_level:
			level_cards.append(card)
	
	if level_cards.size() >= 2:
		var suit_counts = {}
		for card in level_cards:
			if not suit_counts.has(card.suit):
				suit_counts[card.suit] = 0
			suit_counts[card.suit] += 1
		
		# findPair
		for suit in suit_counts:
			if suit_counts[suit] >= 2:
				if can_make_bid(ai_player, suit, 2):
					make_bid(ai_player, suit, 2)
					next_bidding_turn()
					return
	
	if level_cards.size() >= 1 and current_bid["count"] == 0:
		make_bid(ai_player, level_cards[0].suit, 1)
		next_bidding_turn()
		return
	
	next_bidding_turn()

func next_bidding_turn():
	"""Advance to the next bid turn."""
	bidding_round += 1
	current_player_index = (current_player_index + 1) % 4
	
	# disableUIbutton
	if ui_manager and ui_manager.has_node("BiddingUI"):
		var bidding_ui = ui_manager.get_node("BiddingUI")
		bidding_ui.enable_buttons(false)
	
	await get_tree().create_timer(0.5).timeout
	process_bidding_turn()

func finish_bidding():
	"""End the bidding phase."""
	# hideBidUI
	if ui_manager and ui_manager.has_node("BiddingUI"):
		var bidding_ui = ui_manager.get_node("BiddingUI")
		bidding_ui.hide_bidding_ui()
	
	if current_bid["count"] == 0:
		trump_suit = Card.Suit.SPADE
		current_bid["suit"] = trump_suit
		current_bid["team"] = players[dealer_index].team
		current_bid["player_id"] = dealer_index
	else:
		trump_suit = current_bid["suit"]
		dealer_index = current_bid["player_id"]
	
	if ui_manager:
		ui_manager.update_trump_suit(get_trump_symbol())
		ui_manager.show_center_message(GameConfig.text("team_bid_trump") % [get_team_name(current_bid["team"]), get_trump_symbol()], 2.0)
	
	await get_tree().create_timer(2.0).timeout
	
	# enterBury bottom cardsphase
	if players[dealer_index].player_type == Player.PlayerType.HUMAN:
		start_burying_phase()
	else:
		await ai_bury_bottom()

func get_suit_name(suit: Card.Suit) -> String:
	"""Return the display name for a suit."""
	match suit:
		Card.Suit.SPADE: return GameConfig.text("suit_spade")
		Card.Suit.HEART: return GameConfig.text("suit_heart")
		Card.Suit.CLUB: return GameConfig.text("suit_club")
		Card.Suit.DIAMOND: return GameConfig.text("suit_diamond")
		Card.Suit.JOKER: return GameConfig.text("suit_no_trump")
		_: return "?"

# =====================================
# Bury bottom cardsphase
# =====================================

func start_burying_phase():
	"""Start the burying phase."""
	print("=== start_burying_phase() called ===")
	print("Current phase changed to BURYING")
	current_phase = GamePhase.BURYING

	var dealer = players[dealer_index]
	print("Dealer ", dealer.player_name, " receives bottom cards. Hand size: ", dealer.hand.size())

	dealer.receive_cards(bottom_cards, false)
	bottom_cards.clear()
	dealer.sort_hand(true, trump_suit, current_level)
	dealer.update_hand_display()
	dealer.clear_selection()
	dealer.set_card_selectable(true)

	print("Bottom cards dealt. Dealer hand size: ", dealer.hand.size())

	_apply_bury_hints(dealer)

	if ui_manager:
		ui_manager.update_turn_message(GameConfig.text("bury_hint"))
		ui_manager.show_center_message(GameConfig.text("suggested_bury"), 2.5)
		ui_manager.show_bury_button(true)
		ui_manager.update_selected_count(0, 8)
		ui_manager.set_bury_button_enabled(false)

func _on_bury_cards_pressed():
	"""Player pressed the bury button."""
	print("=== _on_bury_cards_pressed() called ===")
	print("Current phase: ", current_phase)

	if current_phase != GamePhase.BURYING:
		print("Warning: not in burying phase; ignoring bury action")
		return

	var dealer = players[dealer_index]

	if dealer.selected_cards.size() != 8:
		print("Wrong selected card count: ", dealer.selected_cards.size(), "; expected 8")
		if ui_manager:
			ui_manager.show_center_message(GameConfig.text("select_exact_bury"), 1.5)
		return

	print("Bury action: remove 8 cards from hand size ", dealer.hand.size())

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

	print("Bury complete. Dealer remaining hand size: ", dealer.hand.size())

	if ui_manager:
		ui_manager.show_bury_button(false)
		ui_manager.show_center_message(GameConfig.text("bury_complete"), 1.5)

	print("Waiting 1.5 seconds before entering playing phase...")
	await get_tree().create_timer(1.5).timeout
	print("Calling start_playing_phase()")
	await start_playing_phase()

func auto_bury_for_player(dealer: Player):
	"""Automatically bury bottom cards."""
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
		ui_manager.show_center_message(GameConfig.text("bury_complete"), 1.5)
	
	await get_tree().create_timer(1.5).timeout
	await start_playing_phase()

func ai_bury_bottom():
	"""AI buries bottom cards."""
	print("=== ai_bury_bottom() called ===")
	current_phase = GamePhase.BURYING
	for player in players:
		player.set_card_selectable(false)
	if ui_manager:
		ui_manager.update_turn_message(GameConfig.text("ai_burying"))
		ui_manager.show_bury_button(false)
		ui_manager.set_buttons_enabled(false)

	var dealer = players[dealer_index]
	print("AI dealer ", dealer.player_name, " starts burying cards")

	dealer.receive_cards(bottom_cards, false)
	bottom_cards.clear()
	dealer.sort_hand(true, trump_suit, current_level)
	dealer.update_hand_display()

	print("Waiting 1.5 seconds...")
	await get_tree().create_timer(1.5).timeout
	print("Calling auto_bury_for_player()")
	await auto_bury_for_player(dealer)

func _apply_bury_hints(dealer: Player):
	var suggested = choose_ai_bury_cards(dealer)
	for card in dealer.hand:
		ShengjiCardLogic.apply_trump(card, trump_suit, current_level)
		card.set_hint("bury", suggested.has(card))

func _clear_bury_hints(dealer: Player):
	for card in dealer.hand:
		card.clear_hint("bury")

func _apply_play_hints():
	if not GameConfig.play_hints_enabled:
		_clear_play_hints()
		return
	if players.is_empty():
		return
	var human = players[0]
	if human.hand.is_empty():
		return
	var suggested = choose_ai_play(human)
	for card in human.hand:
		card.set_hint("play", suggested.has(card))

func _clear_play_hints():
	if players.is_empty():
		return
	for card in players[0].hand:
		card.set_hint("play", false)

func _on_play_hints_changed(enabled: bool):
	if not enabled:
		_clear_play_hints()
	elif current_phase == GamePhase.PLAYING and current_player_index == 0:
		_apply_play_hints()

func choose_ai_bury_cards(dealer: Player) -> Array:
	var sorted_hand = dealer.hand.duplicate()
	sorted_hand.sort_custom(func(a, b):
		return get_ai_bury_score(a, dealer.hand) > get_ai_bury_score(b, dealer.hand)
	)
	return sorted_hand.slice(0, min(8, sorted_hand.size()))

func get_ai_bury_score(card: Card, hand: Array[Card]) -> float:
	ShengjiCardLogic.apply_trump(card, trump_suit, current_level)
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
# Play cardsphase
# =====================================

func start_playing_phase():
	"""Start the playing phase."""
	print("=== start_playing_phase() called ===")
	print("Current phase changed to PLAYING")
	current_phase = GamePhase.PLAYING

	for player in players:
		player.current_rank = current_level
		for card in player.hand:
			ShengjiCardLogic.apply_trump(card, trump_suit, current_level)
		player.sort_hand(true, trump_suit, current_level)
		# updateshow
		player.update_hand_display(true)

	current_player_index = dealer_index
	refresh_all_card_counts()
	print("Dealer: ", players[dealer_index].player_name, " (player_id=", dealer_index, ")")
	print("First player to play: ", players[current_player_index].player_name)

	if ui_manager:
		ui_manager.update_turn_message(get_turn_message(current_player_index))
		ui_manager.highlight_current_player(current_player_index)
		ui_manager.show_bury_button(false)

	phase_changed.emit(current_phase)
	update_turn_interaction()

	if players[current_player_index].player_type == Player.PlayerType.AI:
		print("First player is AI; waiting 1 second before AI play")
		await get_tree().create_timer(1.0).timeout
		ai_play_turn(players[current_player_index])
	else:
		print("First player is human; waiting for player input")

func get_trump_symbol() -> String:
	match trump_suit:
		Card.Suit.SPADE: return "♠"
		Card.Suit.HEART: return "♥"
		Card.Suit.CLUB: return "♣"
		Card.Suit.DIAMOND: return "♦"
		Card.Suit.JOKER: return "👑"
		_: return "?"

func get_team_name(team: int) -> String:
	return GameConfig.text("team_name") % [team + 1]

func get_player_display_name(player_id: int) -> String:
	return GameConfig.text("player_name") % [player_id + 1]

func get_turn_message(player_id: int) -> String:
	return GameConfig.text("turn_play_cards") % get_player_display_name(player_id)

func refresh_player_names():
	for player in players:
		player.player_name = get_player_display_name(player.player_id)

func _on_language_changed(_language: String):
	refresh_player_names()
	if ui_manager == null:
		return
	if current_phase == GamePhase.PLAYING and not players.is_empty():
		ui_manager.update_turn_message(get_turn_message(current_player_index))
	elif current_phase == GamePhase.BURYING:
		if players[dealer_index].player_type == Player.PlayerType.HUMAN:
			ui_manager.update_turn_message(GameConfig.text("bury_hint"))
		else:
			ui_manager.update_turn_message(GameConfig.text("ai_burying"))
	elif current_phase == GamePhase.DEALING_AND_BIDDING:
		ui_manager.update_turn_message(GameConfig.text("dealing"))
	if not last_trick_summary.is_empty() and ui_manager.has_method("update_last_trick"):
		for entry in last_trick_summary:
			if entry.has("player_id"):
				entry["player_name"] = get_player_display_name(entry["player_id"])
		ui_manager.update_last_trick(last_trick_summary)

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
	"""Refresh action buttons after the human player selection changes."""
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
		ShengjiCardLogic.apply_trump(card, trump_suit, current_level)

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
	"""Play button pressed."""
	if current_phase != GamePhase.PLAYING:
		return
	_clear_play_hints()

	var human_player = players[0]
	if current_player_index != human_player.player_id:
		if ui_manager:
			ui_manager.show_center_message(GameConfig.text("not_your_turn"), 1.0)
		return

	if human_player.selected_cards.is_empty():
		if ui_manager:
			ui_manager.show_center_message(GameConfig.text("select_cards_first"), 1.5)
		return

	if not is_human_selected_play_valid():
		if ui_manager:
			ui_manager.show_center_message(GameConfig.text("selected_cards_invalid"), 1.5)
		update_action_controls()
		return
	
	for card in human_player.selected_cards:
		ShengjiCardLogic.apply_trump(card, trump_suit, current_level)
	
	var pattern = GameRules.identify_pattern(human_player.selected_cards, trump_suit, current_level)

	if not GameRules.validate_play(human_player.selected_cards, human_player.hand):
		if ui_manager:
			ui_manager.show_center_message(GameConfig.text("invalid_play"), 1.5)
		return
	
	if current_trick.is_empty():
		# lead playerPlay cards
		if pattern.pattern_type == GameRules.CardPattern.THROW:
			# Throwrequiresvalidate
			if not validate_throw(human_player, pattern):
				if ui_manager:
					ui_manager.show_center_message(GameConfig.text("throw_failed"), 2.0)
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
				ui_manager.show_center_message(GameConfig.text("cards_played"), 1.0)

			next_player_turn()
		else:
			if ui_manager:
				ui_manager.show_center_message(GameConfig.text("play_failed"), 1.5)
	else:
		# Follow suit
		var lead_pattern = current_trick[0]["pattern"]
		
		if not GameRules.can_follow(pattern, lead_pattern, human_player.hand, trump_suit, current_level):
			if ui_manager:
				ui_manager.show_center_message(GameConfig.text("follow_invalid"), 1.5)
			return
		
		if human_player.play_selected_cards():
			show_played_cards(0, pattern.cards)
			
			current_trick.append({
				"player_id": human_player.player_id,
				"cards": pattern.cards,
				"pattern": pattern
			})
			
			if ui_manager:
				ui_manager.show_center_message(GameConfig.text("follow_accepted"), 1.0)
			
			if current_trick.size() == 4:
				evaluate_trick()
			else:
				next_player_turn()

func validate_throw(player: Player, throw_pattern: GameRules.PlayPattern) -> bool:
	"""Validate whether a throw succeeds."""
	for i in range(1, 4):
		var other_player = players[(player.player_id + i) % 4]
		
		# updatehandTrumpstate
		for card in other_player.hand:
			ShengjiCardLogic.apply_trump(card, trump_suit, current_level)
		
		# Check whether any thrown card can be beaten.
		for throw_card in throw_pattern.cards:
			for hand_card in other_player.hand:
				if can_beat_card(hand_card, throw_card):
					return false

	return true

func can_beat_card(card1: Card, card2: Card) -> bool:
	"""Check whether card1 beats card2."""
	return ShengjiCardLogic.compare_cards(card1, card2, trump_suit, current_level) > 0

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
		if card.has_method("refresh_visual_state"):
			card.refresh_visual_state()

		if player_id != 0:
			# AI: アバターpositionからPlay cardsエリアへスライドアニメーション
			card.position = get_card_anim_source(player_id)
			var tween = card.create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(card, "position", target_pos, 0.30)
		else:
			card.global_position = target_pos

func get_card_anim_source(player_id: int) -> Vector2:
	var positions = get_player_positions()
	if player_id >= 0 and player_id < positions.size():
		return positions[player_id]
	return get_table_size() * 0.5

func get_played_card_spacing(card_count: int) -> float:
	if card_count <= 1:
		return 0.0

	var spacing = PLAYED_CARD_SPACING
	var total_width = spacing * float(card_count - 1)
	if total_width > PLAYED_CARD_MAX_WIDTH:
		spacing = PLAYED_CARD_MAX_WIDTH / float(card_count - 1)

	return max(spacing, PLAYED_CARD_MIN_SPACING)

func next_player_turn():
	"""Advance to the next player."""
	current_player_index = (current_player_index + 1) % 4
	var current_player = players[current_player_index]
	
	if ui_manager:
		ui_manager.update_turn_message(get_turn_message(current_player_index))
		ui_manager.highlight_current_player(current_player_index)
	update_turn_interaction()
	
	if current_player.player_type == Player.PlayerType.AI:
		await get_tree().create_timer(1.5).timeout
		ai_play_turn(current_player)

func ai_play_turn(ai_player: Player):
	"""AI plays cards."""
	print("=== ai_play_turn() called ===")
	print("AI player: ", ai_player.player_name, " (player_id=", ai_player.player_id, ")")
	print("Current phase: ", current_phase)

	if current_phase != GamePhase.PLAYING:
		print("Warning: current phase is not PLAYING; AI cannot play")
		return

	for card in ai_player.hand:
		ShengjiCardLogic.apply_trump(card, trump_suit, current_level)
	
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
	"""Rule-based AI: preserve strong leads and decide follow plays based on teammate/opponent trick state."""
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
	return ShengjiAiLogic.normalize_card_list(cards)

func append_unique_candidate(candidates: Array, cards: Array[Card]):
	ShengjiAiLogic.append_unique_candidate(candidates, cards)

func has_same_cards(cards_a: Array, cards_b: Array) -> bool:
	return ShengjiAiLogic.has_same_cards(cards_a, cards_b)

func get_same_suit_cards_for_lead(hand: Array[Card], lead_pattern: GameRules.PlayPattern) -> Array[Card]:
	return ShengjiAiLogic.get_same_suit_cards_for_lead(hand, lead_pattern, trump_suit, current_level)

func sort_cards_by_strength(cards: Array, ascending: bool) -> Array:
	return ShengjiAiLogic.sort_cards_by_strength(cards, ascending, trump_suit, current_level)

func sort_candidate_list_by_cost(candidates: Array):
	ShengjiAiLogic.sort_candidate_list_by_cost(candidates, trump_suit, current_level)

func take_low_cards(cards: Array, count: int) -> Array:
	return ShengjiAiLogic.take_low_cards(cards, count, trump_suit, current_level)

func take_high_cards(cards: Array, count: int) -> Array:
	return ShengjiAiLogic.take_high_cards(cards, count, trump_suit, current_level)

func take_point_heavy_cards(cards: Array, count: int) -> Array:
	return ShengjiAiLogic.take_point_heavy_cards(cards, count, trump_suit, current_level)

func get_cards_except(cards: Array[Card], excluded: Array) -> Array[Card]:
	return ShengjiAiLogic.get_cards_except(cards, excluded)

func build_pair_preferred_candidate(cards: Array[Card], needed: int) -> Array:
	return ShengjiAiLogic.build_pair_preferred_candidate(cards, needed, trump_suit, current_level)

func score_ai_lead_candidate(cards: Array, ai_player_id: int = 0) -> float:
	return ShengjiAiLogic.score_lead_candidate(cards, ai_player_id, trump_suit, current_level, _any_opponent_void)

func score_ai_follow_candidate(cards: Array, teammate_winning: bool, has_winning_candidate: bool, can_beat: bool, trick_points: int) -> float:
	return ShengjiAiLogic.score_follow_candidate(cards, teammate_winning, has_winning_candidate, can_beat, trick_points, trump_suit, current_level)

func get_ai_card_cost(card: Card) -> float:
	return ShengjiAiLogic.get_card_cost(card, trump_suit, current_level)

func get_ai_play_cost(cards: Array) -> float:
	return ShengjiAiLogic.get_play_cost(cards, trump_suit, current_level)

func is_all_trump_cards(cards: Array) -> bool:
	return ShengjiAiLogic.is_all_trump_cards(cards, trump_suit, current_level)

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
	"""Evaluate this trick."""
	print("=== Evaluate this trick ===")
	for player in players:
		player.set_card_selectable(false)
	if ui_manager:
		ui_manager.set_buttons_enabled(false)

	print("Current trick play order:")
	for i in range(current_trick.size()):
		var play = current_trick[i]
		print("  ", i+1, ". ", players[play["player_id"]].player_name, " played ", play["cards"].size(), " cards")

	var lead_play = current_trick[0]
	var winner_play = lead_play

	for i in range(1, current_trick.size()):
		var current_play = current_trick[i]
		var compare_result = GameRules.compare_plays(winner_play["pattern"], current_play["pattern"], trump_suit, current_level)

		if compare_result < 0:
			winner_play = current_play

	var winner = players[winner_play["player_id"]]
	print("Trick winner: ", winner.player_name, " (player_id=", winner_play["player_id"], ")")
	SoundManager.play_trick_win()

	var points = 0
	for play in current_trick:
		points += GameRules.calculate_points(play["cards"])

	team_scores[winner.team] += points

	if ui_manager:
		ui_manager.update_team_scores(team_scores[0], team_scores[1])
		var trick_message = GameConfig.text("trick_won") % [winner.player_name, points]
		if ui_manager.has_method("show_trick_result"):
			ui_manager.show_trick_result(winner.player_id, trick_message, 2.0)
		else:
			ui_manager.show_center_message(trick_message, 2.0)

	_update_void_tracking()
	var bottom_multiplier = calculate_bottom_multiplier(winner_play)

	last_trick_summary.clear()
	for play in current_trick:
		var cards_text = " ".join(play["cards"].map(func(c): return c.get_display_name()))
		last_trick_summary.append({
			"player_id": play["player_id"],
			"player_name": get_player_display_name(play["player_id"]),
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
				ui_manager.show_center_message(GameConfig.text("dealer_captures_bottom") % [bottom_points * multiplier, multiplier], 2.0)
				ui_manager.update_team_scores(team_scores[0], team_scores[1])
		else:
			var opponent_team = 1 - current_bid["team"]
			team_scores[opponent_team] += bottom_points * multiplier
			if ui_manager:
				ui_manager.show_center_message(GameConfig.text("opponent_captures_bottom") % [bottom_points * multiplier, multiplier], 2.0)
				ui_manager.update_team_scores(team_scores[0], team_scores[1])
		
		await get_tree().create_timer(2.0).timeout
		end_round()
	else:
		current_player_index = winner_play["player_id"]
		print("Next trick starts with winner: ", players[current_player_index].player_name, " (player_id=", current_player_index, ")")
		await get_tree().create_timer(1.0).timeout

		if ui_manager:
			ui_manager.update_turn_message(get_turn_message(current_player_index))
			ui_manager.highlight_current_player(current_player_index)
		update_turn_interaction()

		if players[current_player_index].player_type == Player.PlayerType.AI:
			await get_tree().create_timer(1.0).timeout
			ai_play_turn(players[current_player_index])

# =====================================
# End and level up
# =====================================

func _update_void_tracking():
	if current_trick.size() < 2:
		return
	var lead_card = current_trick[0]["cards"][0]
	ShengjiCardLogic.apply_trump(lead_card, trump_suit, current_level)
	for i in range(1, current_trick.size()):
		var play = current_trick[i]
		var played_card = play["cards"][0]
		ShengjiCardLogic.apply_trump(played_card, trump_suit, current_level)
		var pid = play["player_id"]
		if lead_card.is_trump:
			if not played_card.is_trump and not player_void_suits[pid].has(VOID_TRUMP):
				player_void_suits[pid].append(VOID_TRUMP)
				print("▶ ", players[pid].player_name, " is void in trump")
		else:
			if (played_card.is_trump or played_card.suit != lead_card.suit) and not player_void_suits[pid].has(lead_card.suit):
				player_void_suits[pid].append(lead_card.suit)
				print("▶ ", players[pid].player_name, " is void in suit ", lead_card.suit)

func _any_opponent_void(ai_player_id: int, suit_key) -> bool:
	for i in range(4):
		if i != ai_player_id and players[i].team != players[ai_player_id].team:
			if player_void_suits[i].has(suit_key):
				return true
	return false

func calculate_bottom_multiplier(winning_play: Dictionary) -> int:
	return ShengjiScoring.calculate_bottom_multiplier(winning_play)

func end_round():
	"""End this round and calculate level changes."""
	current_phase = GamePhase.SCORING

	print("=== Round ended; calculate level changes ===")
	var dealer_team = current_bid["team"]  # Team that won the bid.
	var attacker_team = 1 - dealer_team    # Non-dealer team.
	var attacker_score = team_scores[attacker_team]

	print("Dealer team: Team ", dealer_team + 1, " score: ", team_scores[dealer_team])
	print("Opponent team: Team ", attacker_team + 1, " score: ", attacker_score)

	var result = ShengjiScoring.get_round_result(dealer_team, attacker_score)
	var levels_to_advance: int = result["levels"]
	var winning_team: int = result["winning_team"]

	team_levels[winning_team] += levels_to_advance
	if result["dealer_rotates"]:
		dealer_index = (dealer_index + 1) % 4

	if ui_manager:
		var message_key = "team_dominates_levels" if result["dominant"] else "team_wins_levels"
		if winning_team == dealer_team and not result["dominant"]:
			message_key = "team_holds_levels"
		ui_manager.show_center_message(GameConfig.text(message_key) % [get_team_name(winning_team), levels_to_advance], 3.0)

	print("Winning team: Team ", winning_team + 1, " level increase: ", levels_to_advance)
	print("Current levels - Team 1: ", team_levels[0], " Team 2: ", team_levels[1])
	SoundManager.play_level_up()

	current_level = team_levels[players[dealer_index].team]

	await get_tree().create_timer(3.0).timeout

	if check_game_over():
		SoundManager.play_game_over()
		show_game_over_screen()
	else:
		start_new_round()

func check_game_over() -> bool:
	"""Check whether the game is over."""
	return ShengjiScoring.is_game_over(team_levels)

func show_game_over_screen():
	"""Show the game over screen."""
	var winner_team = ShengjiScoring.get_winner_team(team_levels)
	
	if ui_manager and ui_manager.has_node("GameOverUI"):
		var game_over_ui = ui_manager.get_node("GameOverUI")
		game_over_ui.show_game_over(winner_team, team_levels[0], team_levels[1], total_rounds_played)
	
	game_over.emit(winner_team)

func restart_game():
	"""Restart the game."""
	# Reset all state.
	cleanup_round_cards()
	team_levels = [2, 2]
	current_level = 2
	total_rounds_played = 0
	dealer_index = 0
	
	# Hide the game over screen.
	if ui_manager and ui_manager.has_node("GameOverUI"):
		var game_over_ui = ui_manager.get_node("GameOverUI")
		game_over_ui.hide_game_over()
	
	# Start a new game.
	start_new_round()

func get_pattern_name(pattern_type: GameRules.CardPattern) -> String:
	match pattern_type:
		GameRules.CardPattern.SINGLE: return "Single"
		GameRules.CardPattern.PAIR: return "Pair"
		GameRules.CardPattern.TRACTOR: return "Tractor"
		GameRules.CardPattern.THROW: return "Throw"
		_: return "Invalid"
