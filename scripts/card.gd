# card.gd - 完整版扑克牌类
extends Node2D
class_name Card

# 信号定义
signal card_clicked(card: Card)
signal flip_completed(card: Card)
signal move_completed(card: Card)

# 枚举定义
enum Suit { SPADE, HEART, CLUB, DIAMOND, JOKER }
enum Rank { 
	TWO = 2, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, 
	NINE, TEN, JACK, QUEEN, KING, ACE, 
	SMALL_JOKER = 14, BIG_JOKER = 15 
}

# 卡牌属性
var suit: Suit = Suit.SPADE
var rank: Rank = Rank.TWO
var is_trump: bool = false
var points: int = 0

# 纹理
var front_texture: Texture2D
var back_texture: Texture2D
var is_face_up: bool = false

# 节点引用
var sprite: Sprite2D
var collision_shape: CollisionShape2D
var area_2d: Area2D

# 动画参数
const FLIP_DURATION = 0.3
const FLIP_HALF_TIME = 0.15
const CARD_SCALE = 1.0  # 卡牌整体缩放比例（恢复原始大小）
const HOVER_HEIGHT = 25  # 悬停高度
const HOVER_SCALE = 1.15  # 悬停时额外的缩放比例
const SELECTED_HEIGHT = 30  # 选中时的向上偏移高度

# 交互状态
var is_selectable: bool = true
var is_selected: bool = false
var is_hovering: bool = false
var original_position: Vector2

# ============================================
# 初始化
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
	original_position = position

func _setup_sprite():
	if not has_node("Sprite2D"):
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.scale = Vector2(CARD_SCALE, CARD_SCALE)  # 设置卡牌缩放
		add_child(sprite)
	else:
		sprite = get_node("Sprite2D")
		sprite.scale = Vector2(CARD_SCALE, CARD_SCALE)  # 确保已存在的sprite也缩放

func _setup_area2d():
	if not has_node("Area2D"):
		area_2d = Area2D.new()
		area_2d.name = "Area2D"
		add_child(area_2d)

		collision_shape = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		# 碰撞区域只覆盖卡牌左侧可见部分（根据CARD_SCALE调整）
		shape.size = Vector2(35 * CARD_SCALE, 90 * CARD_SCALE)
		collision_shape.shape = shape
		# 将碰撞形状向左偏移，使其覆盖左侧
		collision_shape.position = Vector2(-12.5 * CARD_SCALE, 0)
		area_2d.add_child(collision_shape)

		area_2d.input_event.connect(_on_area_input_event)
		area_2d.mouse_entered.connect(_on_mouse_entered)
		area_2d.mouse_exited.connect(_on_mouse_exited)
	else:
		area_2d = get_node("Area2D")
		collision_shape = area_2d.get_node("CollisionShape2D")

# ============================================
# 基础属性方法
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
	# 使用两位数字格式匹配你的文件名
	return "%s_%02d" % [suit_names[suit], rank]

func get_display_name() -> String:
	var suit_cn = ["♠", "♥", "♣", "♦", "Joker"]
	var rank_cn = {
		2: "2", 3: "3", 4: "4", 5: "5", 6: "6", 7: "7", 8: "8",
		9: "9", 10: "10", 11: "J", 12: "Q", 13: "K", 14: "A",
		15: "小王", 16: "大王"
	}
	
	if suit == Suit.JOKER:
		return "小王" if rank == Rank.SMALL_JOKER else "大王"
	
	return "%s%s" % [suit_cn[suit], rank_cn.get(rank, str(rank))]

# ============================================
# 纹理加载
# ============================================

func load_textures():
	var card_name = get_card_name()
	var front_path = "res://assets/cards/%s.png" % card_name
	var back_path = "res://assets/cards/card_back.png"
	
	if ResourceLoader.exists(front_path):
		front_texture = load(front_path)
	else:
		front_texture = create_placeholder_texture(get_card_color())
	
	if ResourceLoader.exists(back_path):
		back_texture = load(back_path)
	else:
		back_texture = create_placeholder_texture(Color(0.3, 0.3, 0.8))

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
	
	# 添加边框
	for x in range(100):
		image.set_pixel(x, 0, Color.BLACK)
		image.set_pixel(x, 139, Color.BLACK)
	for y in range(140):
		image.set_pixel(0, y, Color.BLACK)
		image.set_pixel(99, y, Color.BLACK)
	
	return ImageTexture.create_from_image(image)

# ============================================
# 主牌判断
# ============================================

func set_trump(trump_suit: Suit, current_rank: int):
	is_trump = (suit == trump_suit) or (rank == current_rank) or (suit == Suit.JOKER)

# ============================================
# 翻牌动画
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
	tween.tween_property(sprite, "scale:x", 1.0, FLIP_HALF_TIME)
	tween.tween_callback(func(): flip_completed.emit(self))

func set_face_up(face_up: bool, instant: bool = false):
	if instant:
		is_face_up = face_up
		sprite.texture = front_texture if face_up else back_texture
		sprite.scale.x = 1.0
	else:
		if face_up and not is_face_up:
			flip_to_front()
		elif not face_up and is_face_up:
			flip_to_back()

# ============================================
# 移动动画
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
	移动卡牌到actual_position，但保存base_position作为original_position
	用于处理选中状态的卡牌移动
	"""
	var tween = create_tween()
	tween.set_ease(ease_type)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", actual_position, duration)
	tween.tween_callback(func():
		original_position = base_position  # 保存基础位置，不是实际位置
		move_completed.emit(self)
	)
	return tween

# ============================================
# 悬浮效果
# ============================================

func hover_effect():
	if not is_selectable or is_hovering:
		return

	is_hovering = true

	# 临时提高z_index，确保悬停的卡牌在最上层
	var original_z = z_index
	z_index = 900

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	# 计算悬停目标位置（考虑是否已选中）
	var base_offset = SELECTED_HEIGHT if is_selected else 0
	var target_y = original_position.y - base_offset - HOVER_HEIGHT

	tween.tween_property(self, "position:y", target_y, 0.2)
	# 对整个Card节点进行缩放，而不是sprite
	tween.tween_property(self, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), 0.2)

	# 动画完成后，如果不再悬停则恢复z_index
	tween.finished.connect(func():
		if not is_hovering:
			z_index = original_z
	)

func unhover_effect():
	if not is_hovering:
		return

	is_hovering = false

	# 只有未选中的卡牌才恢复原始z_index
	if not is_selected:
		var hand_index = 0
		if get_parent() and get_parent().name == "HandContainer":
			var parent_player = get_parent().get_parent()
			if parent_player and parent_player is Player:
				hand_index = parent_player.hand.find(self)
		z_index = hand_index

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)

	# 计算恢复目标位置（考虑是否已选中）
	var base_offset = SELECTED_HEIGHT if is_selected else 0
	var target_y = original_position.y - base_offset

	tween.tween_property(self, "position:y", target_y, 0.2)
	# 恢复Card节点的缩放为1.0（sprite自身保持CARD_SCALE）
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
# ============================================
# 选中状态
# ============================================

func set_selected(selected: bool):
	is_selected = selected

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	if selected:
		# 选中时：高亮颜色 + 向上移动
		sprite.modulate = Color(1.3, 1.3, 1.0)  # 更明显的黄色高亮
		tween.tween_property(self, "position:y", original_position.y - SELECTED_HEIGHT, 0.2)
	else:
		# 取消选中时：恢复颜色 + 恢复原始位置
		sprite.modulate = Color.WHITE
		tween.tween_property(self, "position:y", original_position.y, 0.2)

func toggle_selected():
	set_selected(not is_selected)

# ============================================
# 输入处理
# ============================================

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if not is_selectable:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			card_clicked.emit(self)

func _on_mouse_entered():
	if is_selectable:
		hover_effect()

func _on_mouse_exited():
	unhover_effect()

# ============================================
# 比较方法
# ============================================

func compare_to(other: Card, trump_suit: Suit, current_rank: int) -> int:
	self.set_trump(trump_suit, current_rank)
	other.set_trump(trump_suit, current_rank)
	
	if is_trump and not other.is_trump:
		return 1
	elif not is_trump and other.is_trump:
		return -1
	
	if suit == Suit.JOKER and other.suit == Suit.JOKER:
		return 1 if rank > other.rank else (-1 if rank < other.rank else 0)
	elif suit == Suit.JOKER:
		return 1
	elif other.suit == Suit.JOKER:
		return -1
	
	if rank == current_rank and other.rank == current_rank:
		if suit == trump_suit and other.suit != trump_suit:
			return 1
		elif suit != trump_suit and other.suit == trump_suit:
			return -1
		return 0
	elif rank == current_rank:
		return 1
	elif other.rank == current_rank:
		return -1
	
	if rank > other.rank:
		return 1
	elif rank < other.rank:
		return -1
	return 0

# ============================================
# 辅助方法
# ============================================

func _to_string() -> String:
	return "Card(%s, trump=%s, points=%d)" % [get_display_name(), is_trump, points]
