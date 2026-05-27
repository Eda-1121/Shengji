# game_hub.gd - ゲーム選択ハブ（モダンカードUI）
extends Control

const HelpScreenScene = preload("res://scripts/app/help_screen.gd")
const SettingsScreenScene = preload("res://scripts/app/settings_screen.gd")

const GAMES = [
	{
		"name_key": "game_shengji_name",
		"sub_key": "game_shengji_sub",
		"desc_key": "game_shengji_desc",
		"icon": "♠♥",
		"bg":     Color(0.102, 0.173, 0.102),
		"accent": Color(0.941, 0.788, 0.416),
		"scene":  "res://scenes/shengji/main.tscn",
		"available": true,
		"has_help":  true,
		"deck_options": [2, 4],
	},
	{
		"name_key": "game_hearts_name",
		"sub_key": "game_hearts_sub",
		"desc_key": "game_hearts_desc",
		"icon": "♥",
		"mini_cards": "♥  ♠Q  ♥",
		"bg":     Color(0.086, 0.129, 0.196),
		"accent": Color(0.878, 0.353, 0.431),
		"scene":  "",
		"available": false,
	},
	{
		"name_key": "game_bridge_name",
		"sub_key": "game_bridge_sub",
		"desc_key": "game_bridge_desc",
		"icon": "♠♣",
		"mini_cards": "1♠  2♣  3NT",
		"bg":     Color(0.086, 0.129, 0.196),
		"accent": Color(0.353, 0.553, 0.878),
		"scene":  "",
		"available": false,
	},
	{
		"name_key": "game_poker_name",
		"sub_key": "game_poker_sub",
		"desc_key": "game_poker_desc",
		"icon": "♦",
		"mini_cards": "A♦  K♠  Q♥",
		"bg":     Color(0.086, 0.129, 0.196),
		"accent": Color(0.690, 0.478, 0.243),
		"scene":  "",
		"available": false,
	},
]

var _sw: float
var _sh: float
var _pw: int
var _ph: int
var _py: int
var _gap: int
var _pws: float
var _phs: float

func _sy(y: float) -> int:
	return int(y * _phs)

func _sf(s: float) -> int:
	return max(9, int(s * _pws))

func _ready():
	var window_size = get_target_window_size()
	get_window().size = window_size
	get_window().min_size = window_size
	center_window(window_size)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not GameConfig.language_changed.is_connected(_on_language_changed):
		GameConfig.language_changed.connect(_on_language_changed)
	_build()

func _build():
	for child in get_children():
		child.queue_free()

	var vp = get_viewport_rect().size
	_sw = vp.x
	_sh = vp.y

	_gap = max(12, int(_sw * 0.012))
	_pw  = int((_sw - _gap * 5) / 4)
	_ph  = max(280, min(int(_sh * 0.42), int(_pw * 1.15), 420))
	_py  = max(152, int(_sh * 0.22))
	_pws = _pw / 300.0
	_phs = _ph / 320.0

	_build_bg()
	_build_header()
	_build_score_bar()
	_build_game_panels()
	_build_card_style_selector()
	_build_footer()

func _build_bg():
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.051, 0.106, 0.165)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

func _build_header():
	var hs = _sh / 720.0

	var title = Label.new()
	title.text = GameConfig.text("app_title")
	title.position = Vector2(0, int(14 * hs))
	title.size = Vector2(_sw, int(40 * hs))
	title.add_theme_font_size_override("font_size", max(22, int(30 * hs)))
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.38))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var sub = Label.new()
	sub.text = GameConfig.text("app_title")
	sub.position = Vector2(0, int(56 * hs))
	sub.size = Vector2(_sw, int(22 * hs))
	sub.add_theme_font_size_override("font_size", max(11, int(13 * hs)))
	sub.add_theme_color_override("font_color", Color(0.60, 0.74, 0.90, 0.65))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub)

	var div_w = 60
	var div = ColorRect.new()
	div.size = Vector2(div_w, 2)
	div.position = Vector2(int((_sw - div_w) / 2), int(82 * hs))
	div.color = Color(0.941, 0.788, 0.416, 0.75)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(div)

func _build_score_bar():
	var hs = _sh / 720.0
	var total_plays = GameConfig.total_plays
	var wins_count  = GameConfig.wins
	var win_rate_str: String = "—"
	if total_plays > 0:
		win_rate_str = "%d%%" % int(float(wins_count) / float(total_plays) * 100)

	var items = [
		[str(total_plays), GameConfig.text("plays")],
		[str(wins_count),  GameConfig.text("wins")],
		[win_rate_str,     GameConfig.text("win_rate")],
	]

	var bar_w   = int(_sw * 0.32)
	var bx      = int((_sw - bar_w) / 2)
	var by      = int(96 * hs)
	var item_w  = int(bar_w / 3)

	for k in items.size():
		var val_lbl = Label.new()
		val_lbl.text = items[k][0]
		val_lbl.position = Vector2(bx + k * item_w, by)
		val_lbl.size = Vector2(item_w, int(22 * hs))
		val_lbl.add_theme_font_size_override("font_size", max(13, int(16 * hs)))
		val_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.38))
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(val_lbl)

		var key_lbl = Label.new()
		key_lbl.text = items[k][1]
		key_lbl.position = Vector2(bx + k * item_w, by + int(22 * hs))
		key_lbl.size = Vector2(item_w, int(16 * hs))
		key_lbl.add_theme_font_size_override("font_size", max(9, int(11 * hs)))
		key_lbl.add_theme_color_override("font_color", Color(0.60, 0.74, 0.90, 0.55))
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(key_lbl)

func _build_game_panels():
	for i in GAMES.size():
		var g  = GAMES[i]
		var px = _gap + i * (_pw + _gap)
		_build_panel(g, px)

func _build_panel(g: Dictionary, px: float):
	var panel = Panel.new()
	panel.position = Vector2(px, _py)
	panel.size = Vector2(_pw, _ph)
	panel.clip_contents = true

	var ps = StyleBoxFlat.new()
	ps.bg_color = g["bg"]
	ps.set_corner_radius_all(12)
	ps.border_color = Color(g["accent"], 0.45 if g["available"] else 0.18)
	ps.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", ps)

	if not g["available"]:
		panel.modulate = Color(1, 1, 1, 0.75)

	add_child(panel)

	# スートアイコン
	var gc = g["accent"]
	var icon_lbl = Label.new()
	icon_lbl.text = g["icon"]
	icon_lbl.position = Vector2(int(12 * _pws), _sy(10))
	icon_lbl.size = Vector2(_pw - int(24 * _pws), _sy(36))
	icon_lbl.add_theme_font_size_override("font_size", _sf(18))
	icon_lbl.add_theme_color_override("font_color", Color(gc.r, gc.g, gc.b, 0.85 if g["available"] else 0.40))
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon_lbl)

	# ゲーム名
	var name_lbl = Label.new()
	name_lbl.text = GameConfig.text(g["name_key"])
	name_lbl.position = Vector2(int(12 * _pws), _sy(52))
	name_lbl.size = Vector2(_pw - int(24 * _pws), _sy(26))
	name_lbl.add_theme_font_size_override("font_size", _sf(15))
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1) if g["available"] else Color(0.85, 0.85, 0.85, 0.65))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(name_lbl)

	# サブタイトル
	var sub_lbl = Label.new()
	sub_lbl.text = GameConfig.text(g["sub_key"])
	sub_lbl.position = Vector2(int(12 * _pws), _sy(78))
	sub_lbl.size = Vector2(_pw - int(24 * _pws), _sy(18))
	sub_lbl.add_theme_font_size_override("font_size", _sf(11))
	sub_lbl.add_theme_color_override("font_color", Color(0.70, 0.80, 0.70, 0.70) if g["available"] else Color(0.55, 0.55, 0.55, 0.50))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(sub_lbl)

	var sep = ColorRect.new()
	sep.position = Vector2(int(12 * _pws), _sy(102))
	sep.size = Vector2(_pw - int(24 * _pws), 1)
	sep.color = Color(gc.r, gc.g, gc.b, 0.20 if g["available"] else 0.10)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(sep)

	# 説明文
	var desc_lbl = Label.new()
	desc_lbl.text = GameConfig.text(g["desc_key"])
	desc_lbl.position = Vector2(int(12 * _pws), _sy(110))
	desc_lbl.size = Vector2(_pw - int(24 * _pws), _sy(56))
	desc_lbl.add_theme_font_size_override("font_size", _sf(11))
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75, 0.80) if g["available"] else Color(0.50, 0.50, 0.50, 0.55))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(desc_lbl)

	var bottom_pad = _sy(12)
	var link_h     = _sy(16)
	var link_gap   = _sy(8)
	var btn_h      = _sy(36)

	if g["available"]:
		if g.has("deck_options"):
			_build_deck_selector(panel, g)

		var btn_y: int
		if g.get("has_help", false):
			btn_y = _ph - bottom_pad - link_h - link_gap - btn_h
		else:
			btn_y = _ph - bottom_pad - btn_h

		var play_btn = Button.new()
		play_btn.text = "▶  %s" % GameConfig.text("play_game")
		play_btn.position = Vector2(int(12 * _pws), btn_y)
		play_btn.size = Vector2(_pw - int(24 * _pws), btn_h)
		play_btn.add_theme_font_size_override("font_size", _sf(15))
		play_btn.add_theme_color_override("font_color", Color(0.08, 0.06, 0.02))
		var acc = g["accent"]
		var mk_play = func(col: Color) -> StyleBoxFlat:
			var s = StyleBoxFlat.new()
			s.bg_color = col
			s.set_corner_radius_all(8)
			s.set_border_width_all(0)
			s.content_margin_left  = 6
			s.content_margin_right = 6
			return s
		play_btn.add_theme_stylebox_override("normal",  mk_play.call(acc))
		play_btn.add_theme_stylebox_override("hover",   mk_play.call(acc.lightened(0.15)))
		play_btn.add_theme_stylebox_override("pressed", mk_play.call(acc.darkened(0.12)))
		var scene_path = g["scene"]
		play_btn.pressed.connect(func(): _on_play_pressed(scene_path))
		panel.add_child(play_btn)

		if g.get("has_help", false):
			var help_btn = Button.new()
			help_btn.text = GameConfig.text("how_to_play")
			help_btn.position = Vector2(int(12 * _pws), _ph - bottom_pad - link_h)
			help_btn.size = Vector2(_pw - int(24 * _pws), link_h)
			help_btn.add_theme_font_size_override("font_size", _sf(11))
			help_btn.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0, 0.75))
			var ts = StyleBoxEmpty.new()
			help_btn.add_theme_stylebox_override("normal",  ts)
			help_btn.add_theme_stylebox_override("hover",   ts)
			help_btn.add_theme_stylebox_override("pressed", ts)
			help_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
			help_btn.pressed.connect(_on_help_pressed)
			panel.add_child(help_btn)
	else:
		if g.has("mini_cards"):
			var mc = Label.new()
			mc.text = g["mini_cards"]
			mc.position = Vector2(int(12 * _pws), _sy(174))
			mc.size = Vector2(_pw - int(24 * _pws), _sy(28))
			mc.add_theme_font_size_override("font_size", _sf(13))
			mc.add_theme_color_override("font_color", Color(gc.r, gc.g, gc.b, 0.50))
			mc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(mc)

		var badge_w = int(82 * _pws)
		var badge_h = _sy(22)
		var badge = Button.new()
		badge.text = GameConfig.text("coming_soon")
		badge.position = Vector2(int((_pw - badge_w) / 2), _ph - bottom_pad - badge_h)
		badge.size = Vector2(badge_w, badge_h)
		badge.disabled = true
		badge.add_theme_font_size_override("font_size", _sf(11))
		badge.add_theme_color_override("font_color", Color(gc.r, gc.g, gc.b, 0.65))
		var bs = StyleBoxFlat.new()
		bs.bg_color     = Color(0, 0, 0, 0)
		bs.border_color = Color(gc.r, gc.g, gc.b, 0.38)
		bs.set_border_width_all(1)
		bs.set_corner_radius_all(11)
		badge.add_theme_stylebox_override("normal",   bs)
		badge.add_theme_stylebox_override("disabled", bs)
		panel.add_child(badge)

func _build_deck_selector(panel: Panel, g: Dictionary):
	var deck_opts: Array = g["deck_options"]
	var deck_btns: Array = []
	var acc = g["accent"]
	var dbw = int(48 * _pws)
	var dbh = _sy(20)
	var dbx = int(12 * _pws)
	var dby = _sy(172)

	for val in deck_opts:
		var db = Button.new()
		db.text = "×%d" % val
		db.position = Vector2(dbx, dby)
		db.size = Vector2(dbw, dbh)
		db.add_theme_font_size_override("font_size", _sf(11))
		panel.add_child(db)
		deck_btns.append(db)
		dbx += dbw + int(6 * _pws)

	var refresh_deck = func():
		for k in deck_btns.size():
			var act = GameConfig.num_decks == deck_opts[k]
			var sn = StyleBoxFlat.new()
			sn.bg_color     = Color(acc.r * 0.22, acc.g * 0.22, acc.b * 0.08, 0.85) if act else Color(0, 0, 0, 0)
			sn.border_color = Color(acc, 0.80 if act else 0.28)
			sn.set_border_width_all(1)
			sn.set_corner_radius_all(10)
			sn.content_margin_left  = 4
			sn.content_margin_right = 4
			deck_btns[k].add_theme_stylebox_override("normal", sn)
			var snh = sn.duplicate()
			snh.bg_color = Color(acc.r * 0.18, acc.g * 0.18, acc.b * 0.06, 0.70)
			deck_btns[k].add_theme_stylebox_override("hover", snh)
			deck_btns[k].add_theme_color_override("font_color",
				Color(acc, 1.0) if act else Color(acc.r, acc.g, acc.b, 0.55))

	for k in deck_btns.size():
		var opt_val = deck_opts[k]
		deck_btns[k].pressed.connect(func():
			SoundManager.play_card_click()
			GameConfig.num_decks = opt_val
			refresh_deck.call()
		)
	refresh_deck.call()

func _build_card_style_selector():
	var style_ids = GameConfig.CARD_STYLES.keys()
	if style_ids.is_empty():
		return

	var label_w = int(132 * _pws)
	var btn_w = int(112 * _pws)
	var btn_h = int(30 * _phs)
	var gap = int(8 * _pws)
	var total_w = label_w + gap + style_ids.size() * btn_w + max(0, style_ids.size() - 1) * gap
	var x = int((_sw - total_w) * 0.5)
	var y = int(_py + _ph + max(14.0, (_sh - _py - _ph) * 0.16))

	var label = Label.new()
	label.text = GameConfig.text("card_design")
	label.position = Vector2(x, y + 4)
	label.size = Vector2(label_w, btn_h)
	label.add_theme_font_size_override("font_size", _sf(12))
	label.add_theme_color_override("font_color", Color(0.60, 0.74, 0.90, 0.70))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	x += label_w + gap
	for style_id in style_ids:
		var style_to_set = String(style_id)
		var btn = Button.new()
		btn.text = GameConfig.get_card_style_name(style_to_set)
		btn.position = Vector2(x, y)
		btn.size = Vector2(btn_w, btn_h)
		btn.add_theme_font_size_override("font_size", _sf(12))
		_style_card_style_button(btn, style_to_set == GameConfig.card_style)
		btn.pressed.connect(func():
			SoundManager.play_card_click()
			GameConfig.set_card_style(style_to_set)
			_build()
		)
		add_child(btn)
		x += btn_w + gap

func _style_card_style_button(btn: Button, active: bool):
	var acc = Color(0.941, 0.788, 0.416)
	var mk = func(bg: Color, border: Color) -> StyleBoxFlat:
		var s = StyleBoxFlat.new()
		s.bg_color = bg
		s.border_color = border
		s.set_border_width_all(1)
		s.set_corner_radius_all(8)
		s.content_margin_left = 8
		s.content_margin_right = 8
		return s
	if active:
		btn.add_theme_stylebox_override("normal", mk.call(Color(acc, 0.95), Color(acc, 1.0)))
		btn.add_theme_stylebox_override("hover", mk.call(Color(acc.lightened(0.10), 1.0), Color(acc, 1.0)))
		btn.add_theme_stylebox_override("pressed", mk.call(Color(acc.darkened(0.12), 1.0), Color(acc, 1.0)))
		btn.add_theme_color_override("font_color", Color(0.08, 0.06, 0.02))
	else:
		btn.add_theme_stylebox_override("normal", mk.call(Color(0.03, 0.07, 0.11, 0.65), Color(acc, 0.28)))
		btn.add_theme_stylebox_override("hover", mk.call(Color(0.05, 0.11, 0.17, 0.85), Color(acc, 0.48)))
		btn.add_theme_stylebox_override("pressed", mk.call(Color(0.025, 0.055, 0.085, 0.85), Color(acc, 0.55)))
		btn.add_theme_color_override("font_color", Color(acc, 0.78))

func _build_footer():
	var btn_w   = int(160 * _pws)
	var btn_h   = int(38 * _phs)
	var btn_gap = int(20 * _pws)
	var total_w = btn_w * 2 + btn_gap
	var bx      = int((_sw - total_w) / 2)
	var by      = int(_py + _ph + (_sh - _py - _ph) * 0.54)

	_add_footer_button(GameConfig.text("settings"), Vector2(bx, by), btn_w, btn_h,
		Color(0.40, 0.70, 1.00), _on_settings_pressed)
	_add_footer_button(GameConfig.text("quit"), Vector2(bx + btn_w + btn_gap, by), btn_w, btn_h,
		Color(1.00, 0.40, 0.50), _on_quit_pressed)

func _add_footer_button(text: String, pos: Vector2, w: int, h: int, accent: Color, callback: Callable):
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = Vector2(w, h)
	btn.add_theme_font_size_override("font_size", _sf(15))
	btn.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.88))
	var mk = func(alpha: float) -> StyleBoxFlat:
		var s = StyleBoxFlat.new()
		s.bg_color     = Color(accent.r, accent.g, accent.b, alpha)
		s.border_color = Color(accent.r, accent.g, accent.b, 0.50)
		s.set_border_width_all(1)
		s.set_corner_radius_all(8)
		return s
	btn.add_theme_stylebox_override("normal",  mk.call(0.0))
	btn.add_theme_stylebox_override("hover",   mk.call(0.12))
	btn.add_theme_stylebox_override("pressed", mk.call(0.22))
	btn.pressed.connect(callback)
	add_child(btn)

func _on_play_pressed(scene_path: String):
	SoundManager.play_card_click()
	get_tree().change_scene_to_file(scene_path)

func _on_help_pressed():
	SoundManager.play_card_click()
	var help = HelpScreenScene.new()
	add_child(help)

func _on_settings_pressed():
	SoundManager.play_card_click()
	var settings = SettingsScreenScene.new()
	settings.closed.connect(_build)
	add_child(settings)

func _on_language_changed(_language: String):
	if get_children().any(func(child): return child is SettingsScreen):
		return
	_build()

func _on_quit_pressed():
	SoundManager.play_card_click()
	get_tree().quit()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

func get_target_window_size() -> Vector2i:
	var screen = DisplayServer.window_get_current_screen()
	var usable_rect = DisplayServer.screen_get_usable_rect(screen)
	return Vector2i(
		max(1280, int(float(usable_rect.size.x) * 0.8)),
		max(720, int(float(usable_rect.size.y) * 0.8))
	)

func center_window(window_size: Vector2i):
	var screen = DisplayServer.window_get_current_screen()
	var usable_rect = DisplayServer.screen_get_usable_rect(screen)
	get_window().position = usable_rect.position + (usable_rect.size - window_size) / 2
