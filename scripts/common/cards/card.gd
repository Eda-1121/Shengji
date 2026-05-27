# card.gd - Shared playing card class
extends Node2D
class_name Card

# Signals
signal card_clicked(card: Card)
signal flip_completed(card: Card)
signal move_completed(card: Card)

# Enums
enum Suit { SPADE, HEART, CLUB, DIAMOND, JOKER }
enum Rank {
	TWO = 2, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT,
	NINE, TEN, JACK, QUEEN, KING, ACE = 14,
	SMALL_JOKER = 16, BIG_JOKER = 17
}

# Card state
var suit: Suit = Suit.SPADE
var rank: Rank = Rank.TWO
var is_trump: bool = false
var points: int = 0

# Textures
var front_texture: Texture2D
var back_texture: Texture2D
var is_face_up: bool = false

# Node references
var sprite: Sprite2D
var collision_shape: CollisionShape2D
var area_2d: Area2D
var selected_glow: Sprite2D
var trump_glow: Sprite2D

# Animation settings
const FLIP_DURATION = 0.3
const FLIP_HALF_TIME = 0.15
const CARD_SCALE = 1.34  # Overall card scale
const CARD_WIDTH = 100.0
const CARD_HEIGHT = 140.0
const HOVER_HEIGHT = 28  # Hover lift
const HOVER_SCALE = 1.08  # Extra scale while hovering
const SELECTED_HEIGHT = 38  # Upward offset while selected
const DEFAULT_HAND_HIT_WIDTH = 35.0
const HAND_HIT_X_NUDGE = 13.0
const HAND_HIT_WIDTH_SHRINK = 5.0
const WIDE_HAND_SPACING = 34.0

# Interaction state
var is_selectable: bool = true
var is_selected: bool = false
var is_hovering: bool = false
var original_position: Vector2

# Generic hint overlays keyed by game-specific hint name.
var _hint_sprites: Dictionary = {}
var _visible_hints: Dictionary = {}
var _hand_visible_width: float = DEFAULT_HAND_HIT_WIDTH
var _hand_overlap_spacing: float = DEFAULT_HAND_HIT_WIDTH
var _is_last_hand_card: bool = false

# ============================================
# Initialization
# ============================================

func _init(p_suit: Suit = Suit.SPADE, p_rank: Rank = Rank.TWO):
	suit = p_suit
	rank = p_rank
	_calculate_points()

func _ready():
	_setup_sprite()
	_setup_area2d()
	load_textures()
	sprite.texture = back_texture
	_setup_card_fx()
	if not GameConfig.card_style_changed.is_connected(_on_card_style_changed):
		GameConfig.card_style_changed.connect(_on_card_style_changed)
	original_position = position
	refresh_visual_state()

func _setup_sprite():
	if not has_node("Sprite2D"):
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.scale = Vector2(CARD_SCALE, CARD_SCALE)
		add_child(sprite)
	else:
		sprite = get_node("Sprite2D")
		sprite.scale = Vector2(CARD_SCALE, CARD_SCALE)

func _setup_area2d():
	if not has_node("Area2D"):
		area_2d = Area2D.new()
		area_2d.name = "Area2D"
		add_child(area_2d)

		collision_shape = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		# The hit box covers the visible left side of overlapped hand cards.
		shape.size = Vector2(DEFAULT_HAND_HIT_WIDTH * CARD_SCALE, 90 * CARD_SCALE)
		collision_shape.shape = shape
		collision_shape.position = Vector2(0, 0)
		area_2d.add_child(collision_shape)

		area_2d.input_event.connect(_on_area_input_event)
		area_2d.mouse_entered.connect(_on_mouse_entered)
		area_2d.mouse_exited.connect(_on_mouse_exited)
	else:
		area_2d = get_node("Area2D")
		collision_shape = area_2d.get_node("CollisionShape2D")
		if collision_shape.shape is RectangleShape2D:
			collision_shape.shape.size = Vector2(DEFAULT_HAND_HIT_WIDTH * CARD_SCALE, 90 * CARD_SCALE)
		collision_shape.position = Vector2(0, 0)

func set_hand_overlap_spacing(spacing: float, is_last_card: bool = false):
	if collision_shape == null or not (collision_shape.shape is RectangleShape2D):
		return
	_hand_overlap_spacing = spacing
	_is_last_hand_card = is_last_card
	var full_visual_width = get_visual_card_size().x
	var full_visual_height = get_visual_card_size().y
	var visible_width = full_visual_width if is_last_card else clamp(spacing - HAND_HIT_WIDTH_SHRINK, 7.0, full_visual_width)
	_hand_visible_width = visible_width
	collision_shape.shape.size = Vector2(visible_width, full_visual_height * 0.82)
	collision_shape.position = Vector2(-full_visual_width * 0.5 + visible_width * 0.5 + HAND_HIT_X_NUDGE, 0)
	_update_visible_hints()
	refresh_visual_state()

func get_visual_card_size() -> Vector2:
	if sprite and sprite.texture:
		var texture_size = sprite.texture.get_size()
		return Vector2(texture_size.x * abs(sprite.scale.x), texture_size.y * abs(sprite.scale.y))
	return Vector2(CARD_WIDTH * CARD_SCALE, CARD_HEIGHT * CARD_SCALE)

# ============================================
# Basic card helpers
# ============================================

func _calculate_points():
	match rank:
		Rank.FIVE:
			points = 5
		Rank.TEN:
			points = 10
		Rank.KING:
			points = 10
		_:
			points = 0

func get_card_name() -> String:
	var suit_names = ["spade", "heart", "club", "diamond", "joker"]
	if suit == Suit.JOKER:
		return "big_joker" if rank == Rank.BIG_JOKER else "small_joker"
	# Use two digits to match the card asset file names.
	return "%s_%02d" % [suit_names[suit], rank]

func get_display_name() -> String:
	var suit_labels = ["♠", "♥", "♣", "♦", "Joker"]
	var rank_labels = {
		2: "2", 3: "3", 4: "4", 5: "5", 6: "6", 7: "7", 8: "8",
		9: "9", 10: "10", 11: "J", 12: "Q", 13: "K", 14: "A",
		16: "Small Joker", 17: "Big Joker"
	}
	
	if suit == Suit.JOKER:
		return "Small Joker" if rank == Rank.SMALL_JOKER else "Big Joker"
	
	return "%s%s" % [suit_labels[suit], rank_labels.get(rank, str(rank))]

# ============================================
# Texture loading
# ============================================

func load_textures():
	var card_name = get_card_name()
	var front_path = GameConfig.get_card_asset_path(card_name)
	var back_path = GameConfig.get_card_asset_path("card_back")
	
	if ResourceLoader.exists(front_path):
		front_texture = load(front_path)
	else:
		var fallback_front_path = "res://assets/common/card_sets/classic/%s.png" % card_name
		front_texture = load(fallback_front_path) if ResourceLoader.exists(fallback_front_path) else create_placeholder_texture(get_card_color())
	
	if ResourceLoader.exists(back_path):
		back_texture = load(back_path)
	else:
		var fallback_back_path = "res://assets/common/card_sets/classic/card_back.png"
		back_texture = load(fallback_back_path) if ResourceLoader.exists(fallback_back_path) else create_placeholder_texture(Color(0.3, 0.3, 0.8))

func _on_card_style_changed(_style_id: String):
	load_textures()
	if sprite:
		sprite.texture = front_texture if is_face_up else back_texture
	refresh_visual_state()

func get_card_color() -> Color:
	match suit:
		Suit.HEART, Suit.DIAMOND:
			return Color.RED
		Suit.SPADE, Suit.CLUB:
			return Color.BLACK
		Suit.JOKER:
			return Color.PURPLE
		_:
			return Color.WHITE

func create_placeholder_texture(base_color: Color = Color.WHITE) -> Texture2D:
	var image = Image.create(100, 140, false, Image.FORMAT_RGBA8)
	image.fill(base_color)
	
	# Add a simple border.
	for x in range(100):
		image.set_pixel(x, 0, Color.BLACK)
		image.set_pixel(x, 139, Color.BLACK)
	for y in range(140):
		image.set_pixel(0, y, Color.BLACK)
		image.set_pixel(99, y, Color.BLACK)
	
	return ImageTexture.create_from_image(image)

# ============================================
# Flip animation
# ============================================

func flip_to_front():
	if is_face_up:
		return
	is_face_up = true
	_animate_flip(back_texture, front_texture)

func flip_to_back():
	if not is_face_up:
		return
	is_face_up = false
	_animate_flip(front_texture, back_texture)

func _animate_flip(_from_texture: Texture2D, to_texture: Texture2D):
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	tween.tween_property(sprite, "scale:x", 0.0, FLIP_HALF_TIME)
	tween.tween_callback(func(): sprite.texture = to_texture)
	tween.tween_property(sprite, "scale:x", CARD_SCALE, FLIP_HALF_TIME)
	tween.tween_callback(func():
		refresh_visual_state()
		flip_completed.emit(self)
	)

func set_face_up(face_up: bool, instant: bool = false):
	if instant:
		is_face_up = face_up
		sprite.texture = front_texture if face_up else back_texture
		sprite.scale = Vector2(CARD_SCALE, CARD_SCALE)
		refresh_visual_state()
	else:
		if face_up and not is_face_up:
			flip_to_front()
		elif not face_up and is_face_up:
			flip_to_back()

# ============================================
# Move animation
# ============================================

func move_to(target_position: Vector2, duration: float = 0.5, ease_type = Tween.EASE_IN_OUT):
	var tween = create_tween()
	tween.set_ease(ease_type)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", target_position, duration)
	tween.tween_callback(func():
		original_position = target_position
		move_completed.emit(self)
	)
	return tween

func move_to_with_base(base_position: Vector2, actual_position: Vector2, duration: float = 0.5, ease_type = Tween.EASE_IN_OUT):
	"""
	Move the card to actual_position while storing base_position as original_position.
	This keeps selected cards aligned after layout changes.
	"""
	var tween = create_tween()
	tween.set_ease(ease_type)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", actual_position, duration)
	tween.tween_callback(func():
		original_position = base_position
		move_completed.emit(self)
	)
	return tween

# ============================================
# Hover effect
# ============================================

func hover_effect():
	if not is_selectable or is_hovering:
		return

	is_hovering = true

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	# Include the selected offset when calculating the hover target.
	var base_offset = SELECTED_HEIGHT if is_selected else 0
	var target_y = original_position.y - base_offset - HOVER_HEIGHT

	tween.tween_property(self, "position:y", target_y, 0.2)
	# Scale the whole Card node, not only the sprite.
	var target_scale = HOVER_SCALE if _hand_overlap_spacing >= 30.0 else 1.0
	tween.tween_property(self, "scale", Vector2(target_scale, target_scale), 0.2)

func unhover_effect():
	if not is_hovering:
		return

	is_hovering = false

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)

	# Include the selected offset when restoring the target.
	var base_offset = SELECTED_HEIGHT if is_selected else 0
	var target_y = original_position.y - base_offset

	tween.tween_property(self, "position:y", target_y, 0.2)
	# Restore the Card node scale; the sprite keeps CARD_SCALE.
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
# ============================================
# Selection state
# ============================================

func set_selected(selected: bool):
	is_selected = selected
	refresh_visual_state()

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	if selected:
		# Selected: highlight and lift.
		sprite.modulate = Color(1.18, 1.13, 0.92)
		tween.tween_property(self, "position:y", original_position.y - SELECTED_HEIGHT, 0.2)
	else:
		# Unselected: restore color and position.
		sprite.modulate = Color.WHITE
		tween.tween_property(self, "position:y", original_position.y, 0.2)

func toggle_selected():
	set_selected(not is_selected)

# ============================================
# Input handling
# ============================================

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if not is_selectable:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			SoundManager.play_card_click()
			card_clicked.emit(self)

func _on_mouse_entered():
	if is_selectable:
		hover_effect()

func _on_mouse_exited():
	unhover_effect()

# ============================================
# Debug helpers
# ============================================

func _to_string() -> String:
	return "Card(%s, trump=%s, points=%d)" % [get_display_name(), is_trump, points]

# ============================================
# Hint overlays
# ============================================

func set_hint(key: String, show: bool):
	if not show:
		clear_hint(key)
		return
	_visible_hints[key] = true
	_update_hint_visual(key)

func clear_hint(key: String):
	_visible_hints.erase(key)
	if _hint_sprites.has(key):
		var hint = _hint_sprites[key]
		if hint:
			hint.queue_free()
		_hint_sprites.erase(key)

func clear_all_hints():
	for key in _hint_sprites.keys():
		var hint = _hint_sprites[key]
		if hint:
			hint.queue_free()
	_hint_sprites.clear()
	_visible_hints.clear()

func _update_visible_hints():
	for key in _visible_hints.keys():
		_update_hint_visual(key)

func _update_hint_visual(key: String):
	if _hint_sprites.has(key):
		var existing = _hint_sprites[key]
		if existing:
			existing.queue_free()
		_hint_sprites.erase(key)
	var img = create_hint_dot_texture(get_hint_dot_size())
	var hint = Sprite2D.new()
	hint.texture = ImageTexture.create_from_image(img)
	hint.position = get_hint_dot_position()
	hint.z_as_relative = false
	hint.z_index = 2000
	add_child(hint)
	_hint_sprites[key] = hint

func create_hint_dot_texture(size: int = 24) -> Image:
	var radius = float(size) * 0.5
	var center = Vector2(radius, radius)
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in size:
		for x in size:
			var distance = Vector2(x, y).distance_to(center) / radius
			if distance <= 1.0:
				var alpha = pow(1.0 - distance, 1.8) * 0.82
				var color = Color(0.78, 0.92, 1.0, alpha)
				if distance < 0.34:
					color = Color(1.0, 0.96, 0.68, min(0.95, alpha + 0.22))
				img.set_pixel(x, y, color)
	return img

func get_hint_dot_position() -> Vector2:
	var visual_size = get_visual_card_size()
	var x = 0.0
	var dot_size = float(get_hint_dot_size())
	if not is_wide_hand_spacing():
		var rank_anchor = clamp(_hand_visible_width * 1.02, dot_size * 0.65, _hand_visible_width + dot_size * 0.15)
		x = -visual_size.x * 0.5 + rank_anchor
	return Vector2(x, -visual_size.y * 0.5 - dot_size * 0.35)

func get_hint_dot_size() -> int:
	if is_wide_hand_spacing():
		return 24
	return int(clamp(_hand_visible_width - 2.0, 10.0, 16.0))

func is_wide_hand_spacing() -> bool:
	return _is_last_hand_card or _hand_overlap_spacing >= WIDE_HAND_SPACING

# ============================================
# Visual overlays
# ============================================

func _setup_card_fx():
	selected_glow = Sprite2D.new()
	selected_glow.name = "SelectedGlow"
	selected_glow.texture = ImageTexture.create_from_image(create_card_glow_texture(Color(0.96, 0.78, 0.28, 0.95), 92, 92))
	selected_glow.z_index = -3
	selected_glow.visible = false
	add_child(selected_glow)

	trump_glow = Sprite2D.new()
	trump_glow.name = "TrumpGlow"
	trump_glow.texture = ImageTexture.create_from_image(create_card_glow_texture(Color(0.52, 0.92, 1.00, 0.72), 86, 86))
	trump_glow.z_index = -2
	trump_glow.visible = false
	add_child(trump_glow)

func refresh_visual_state():
	if selected_glow:
		selected_glow.visible = is_selected
	if trump_glow:
		trump_glow.visible = is_face_up and is_trump

func create_card_glow_texture(color: Color, width: int, height: int) -> Image:
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center = Vector2(width * 0.5, height * 0.5)
	var half = Vector2(width * 0.44, height * 0.44)
	for y in range(height):
		for x in range(width):
			var p = Vector2(x, y)
			var edge_distance = max(abs(p.x - center.x) / half.x, abs(p.y - center.y) / half.y)
			if edge_distance <= 1.0:
				var border = smoothstep(0.72, 1.0, edge_distance)
				var alpha = border * color.a
				img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return img
