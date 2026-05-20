# game_hub.gd - ゲーム選択ハブ（レスポンシブレイアウト）
extends Control

const GAMES = [
	{
		"name": "升级 / 拖拉機",
		"name_sub": "Shengji · 昇級",
		"desc": "4人・2チーム制\n中国式トリックテイキング",
		"icon": "♠♥♣♦",
		"bg":    Color(0.05, 0.18, 0.08),
		"accent": Color(1.00, 0.88, 0.28),
		"scene": "res://scenes/shengji/main.tscn",
		"available": true,
		"has_help": true,
		"deck_options": [2, 4],
	},
	{
		"name": "Hearts",
		"name_sub": "ハーツ",
		"desc": "4人・個人戦\nハートと♠Qを避けろ",
		"icon": "♥",
		"bg":    Color(0.18, 0.04, 0.04),
		"accent": Color(1.00, 0.52, 0.52),
		"scene": "",
		"available": false,
	},
	{
		"name": "Bridge",
		"name_sub": "ブリッジ",
		"desc": "4人・2チーム制\nビッドしてトリックを取れ",
		"icon": "♠♣",
		"bg":    Color(0.04, 0.07, 0.20),
		"accent": Color(0.55, 0.72, 1.00),
		"scene": "",
		"available": false,
	},
	{
		"name": "Poker",
		"name_sub": "テキサスホールデム",
		"desc": "2〜9人・個人戦\nブラフと戦略で勝利",
		"icon": "🂠",
		"bg":    Color(0.16, 0.10, 0.03),
		"accent": Color(1.00, 0.80, 0.36),
		"scene": "",
		"available": false,
	},
]

# ---- スクリーン計算値（_ready で設定） ----
var _sw: float   # 画面幅
var _sh: float   # 画面高さ
var _pw: int     # パネル幅
var _ph: int     # パネル高さ
var _py: int     # パネル Y 開始位置
var _gap: int    # パネル間ギャップ
var _pws: float  # パネル幅スケール（pw / 272）
var _phs: float  # パネル高さスケール（ph / 452）

# y 座標をパネル高さ比でスケール
func _sy(y: float) -> int:
	return int(y * _phs)

# フォントサイズをパネル幅比でスケール（最低 10pt）
func _sf(s: float) -> int:
	return max(10, int(s * _pws))

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vp = get_viewport_rect().size
	_sw = vp.x
	_sh = vp.y

	# ギャップを画面幅の 1.5% に固定し、残りをパネル4枚で等分
	_gap = max(16, int(_sw * 0.015))
	_pw  = int((_sw - _gap * 5) / 4)
	# パネル高さ：画面高さの 62% を基本にパネル幅比でキャップ
	_ph  = max(420, min(int(_sh * 0.62), int(_pw * 1.65)))
	# パネル開始 Y：ヘッダー下に余白を確保
	_py  = max(148, int(_sh * 0.19))
	_pws = _pw / 272.0
	_phs = _ph / 452.0

	_build_bg()
	_build_header()
	_build_game_panels()
	_build_footer()

# ---- 背景 ----

func _build_bg():
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.06, 0.12)
	add_child(bg)
	for y in [0.0, _sh - 4]:
		var line = ColorRect.new()
		line.position = Vector2(0, y)
		line.size     = Vector2(_sw, 4)
		line.color    = Color(0.3, 0.5, 0.8, 0.4)
		add_child(line)

# ---- ヘッダー ----

func _build_header():
	var hs = _sh / 720.0  # 縦スケール（720px 基準）

	var title = Label.new()
	title.text = "世界のカードゲーム"
	title.position = Vector2(0, int(18 * hs))
	title.size = Vector2(_sw, int(70 * hs))
	title.add_theme_font_size_override("font_size", max(40, int(56 * hs)))
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.38))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var sub = Label.new()
	sub.text = "World Card Games"
	sub.position = Vector2(0, int(92 * hs))
	sub.size = Vector2(_sw, int(30 * hs))
	sub.add_theme_font_size_override("font_size", max(16, int(22 * hs)))
	sub.add_theme_color_override("font_color", Color(0.60, 0.74, 0.90))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub)

	var sep_w = int(_sw * 0.667)
	var sep = ColorRect.new()
	sep.position = Vector2((_sw - sep_w) / 2, int(130 * hs))
	sep.size     = Vector2(sep_w, 1)
	sep.color    = Color(0.35, 0.50, 0.75, 0.45)
	add_child(sep)

# ---- ゲームパネル ----

func _build_game_panels():
	for i in GAMES.size():
		var g = GAMES[i]
		var px = _gap + i * (_pw + _gap)
		_build_panel(g, px)

func _build_panel(g: Dictionary, px: float):
	var panel = Control.new()
	panel.position = Vector2(px, _py)
	panel.size     = Vector2(_pw, _ph)
	add_child(panel)

	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = g["bg"]
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)

	# アクセントボーダー
	var border_color = g["accent"] if g["available"] else Color(g["accent"], 0.35)
	for rect in [
		[Vector2(0,        0),          Vector2(_pw,  3)],
		[Vector2(0,        _ph - 3),    Vector2(_pw,  3)],
		[Vector2(0,        0),          Vector2(3,    _ph)],
		[Vector2(_pw - 3,  0),          Vector2(3,    _ph)],
	]:
		var b = ColorRect.new()
		b.position = rect[0]
		b.size     = rect[1]
		b.color    = border_color
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(b)

	# スートアイコン（背景装飾）
	var deco = Label.new()
	deco.text = g["icon"]
	deco.position = Vector2(0, _sy(32))
	deco.size = Vector2(_pw, _sy(108))
	deco.add_theme_font_size_override("font_size", _sf(72))
	var dc = g["accent"]
	deco.add_theme_color_override("font_color", Color(dc.r, dc.g, dc.b, 0.18 if g["available"] else 0.10))
	deco.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(deco)

	# ゲーム名
	var name_lbl = Label.new()
	name_lbl.text = g["name"]
	name_lbl.position = Vector2(8, _sy(128))
	name_lbl.size = Vector2(_pw - 16, _sy(44))
	name_lbl.add_theme_font_size_override("font_size", _sf(26))
	name_lbl.add_theme_color_override("font_color", g["accent"] if g["available"] else Color(g["accent"], 0.50))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(name_lbl)

	# サブタイトル
	var sub_lbl = Label.new()
	sub_lbl.text = g["name_sub"]
	sub_lbl.position = Vector2(8, _sy(172))
	sub_lbl.size = Vector2(_pw - 16, _sy(28))
	sub_lbl.add_theme_font_size_override("font_size", _sf(16))
	sub_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7, 0.8) if g["available"] else Color(0.5, 0.5, 0.5, 0.6))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(sub_lbl)

	var sep1 = ColorRect.new()
	sep1.position = Vector2(int(24 * _pws), _sy(208))
	sep1.size     = Vector2(_pw - int(48 * _pws), 1)
	sep1.color    = Color(g["accent"], 0.25) if g["available"] else Color(0.4, 0.4, 0.4, 0.25)
	sep1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(sep1)

	# 説明文
	var desc_lbl = Label.new()
	desc_lbl.text = g["desc"]
	desc_lbl.position = Vector2(8, _sy(217))
	desc_lbl.size = Vector2(_pw - 16, _sy(74))
	desc_lbl.add_theme_font_size_override("font_size", _sf(16))
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75) if g["available"] else Color(0.45, 0.45, 0.45))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(desc_lbl)

	# デッキ数選択（対応ゲームのみ）
	if g.has("deck_options") and g["available"]:
		var deck_sep = ColorRect.new()
		deck_sep.position = Vector2(int(24 * _pws), _sy(298))
		deck_sep.size     = Vector2(_pw - int(48 * _pws), 1)
		deck_sep.color    = Color(g["accent"], 0.20)
		deck_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(deck_sep)

		var dlbl = Label.new()
		dlbl.text = "デッキ数"
		dlbl.position = Vector2(int(24 * _pws), _sy(304))
		dlbl.size = Vector2(int(76 * _pws), _sy(24))
		dlbl.add_theme_font_size_override("font_size", _sf(13))
		dlbl.add_theme_color_override("font_color", Color(0.65, 0.80, 0.65))
		dlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(dlbl)

		var deck_opts: Array = g["deck_options"]
		var deck_btns: Array = []
		var dbw = int(56 * _pws)
		var dbh = _sy(26)
		var dbx = int(110 * _pws)
		for val in deck_opts:
			var db = Button.new()
			db.text = "×%d" % val
			db.position = Vector2(dbx, _sy(302))
			db.size = Vector2(dbw, dbh)
			db.add_theme_font_size_override("font_size", _sf(13))
			panel.add_child(db)
			deck_btns.append(db)
			dbx += dbw + int(6 * _pws)

		var acc = g["accent"]
		var refresh_deck = func():
			for k in deck_btns.size():
				var act = GameConfig.num_decks == deck_opts[k]
				var sn = StyleBoxFlat.new()
				sn.bg_color     = Color(0.13, 0.26, 0.10) if act else Color(0.05, 0.09, 0.05)
				sn.border_color = Color(acc, 0.85 if act else 0.28)
				sn.set_border_width_all(1)
				sn.set_corner_radius_all(4)
				deck_btns[k].add_theme_stylebox_override("normal", sn)
				var snh = sn.duplicate()
				snh.bg_color = sn.bg_color.lightened(0.10)
				deck_btns[k].add_theme_stylebox_override("hover", snh)
				deck_btns[k].add_theme_color_override("font_color",
					Color(acc, 1.0) if act else Color(0.55, 0.70, 0.55))

		for k in deck_btns.size():
			var opt_val = deck_opts[k]
			deck_btns[k].pressed.connect(func():
				SoundManager.play_card_click()
				GameConfig.num_decks = opt_val
				refresh_deck.call()
			)
		refresh_deck.call()

	var mk_style = func(col: Color) -> StyleBoxFlat:
		var s = StyleBoxFlat.new()
		s.bg_color = col
		s.border_color = g["accent"] if g["available"] else Color(0.4, 0.4, 0.4)
		s.set_border_width_all(1)
		s.set_corner_radius_all(6)
		s.content_margin_left  = 8
		s.content_margin_right = 8
		return s

	# プレイ / 準備中ボタン
	var btn_h   = _sy(44)
	var help_h  = _sy(32)
	var help_gap = _sy(16)
	var bottom_pad = _sy(20)
	var btn_y   = _ph - bottom_pad - help_h - help_gap - btn_h

	var btn = Button.new()
	btn.position = Vector2(int(24 * _pws), btn_y)
	btn.size     = Vector2(_pw - int(48 * _pws), btn_h)
	btn.add_theme_font_size_override("font_size", _sf(20))

	if g["available"]:
		btn.text = "プレイ"
		btn.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08))
		var btn_col = g["accent"]
		btn.add_theme_stylebox_override("normal",  mk_style.call(btn_col))
		btn.add_theme_stylebox_override("hover",   mk_style.call(btn_col.lightened(0.18)))
		btn.add_theme_stylebox_override("pressed", mk_style.call(btn_col.darkened(0.14)))
		var scene_path = g["scene"]
		btn.pressed.connect(func(): _on_play_pressed(scene_path))
	else:
		btn.text = "準備中"
		btn.disabled = true
		btn.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
		btn.add_theme_stylebox_override("disabled", mk_style.call(Color(0.10, 0.10, 0.14)))
		btn.add_theme_stylebox_override("normal",   mk_style.call(Color(0.10, 0.10, 0.14)))

	panel.add_child(btn)

	# 遊び方ボタン（ヘルプがあるゲームのみ）
	if g.get("has_help", false):
		var help_btn = Button.new()
		help_btn.text = "📖  遊び方・ルール"
		help_btn.position = Vector2(int(24 * _pws), _ph - bottom_pad - help_h)
		help_btn.size     = Vector2(_pw - int(48 * _pws), help_h)
		help_btn.add_theme_font_size_override("font_size", _sf(14))
		help_btn.add_theme_color_override("font_color", Color(0.75, 0.88, 1.00))
		var hs = StyleBoxFlat.new()
		hs.bg_color     = Color(0.08, 0.16, 0.30)
		hs.border_color = Color(0.35, 0.55, 0.80, 0.55)
		hs.set_border_width_all(1)
		hs.set_corner_radius_all(4)
		var hsh = hs.duplicate()
		hsh.bg_color = Color(0.12, 0.22, 0.42)
		help_btn.add_theme_stylebox_override("normal", hs)
		help_btn.add_theme_stylebox_override("hover",  hsh)
		help_btn.pressed.connect(_on_help_pressed)
		panel.add_child(help_btn)

# ---- フッター ----

func _build_footer():
	var btn_w = int(180 * _pws)
	var btn_h = int(46 * _phs)
	var btn_gap = int(20 * _pws)
	var total_w = btn_w * 2 + btn_gap
	var bx = int((_sw - total_w) / 2)
	# パネル下端から画面下端の 35% の位置
	var by = int(_py + _ph + (_sh - _py - _ph) * 0.35)

	_add_footer_button("設　　定",  Vector2(bx,                  by), btn_w, btn_h, Color(0.10, 0.26, 0.20), _on_settings_pressed)
	_add_footer_button("ゲーム終了", Vector2(bx + btn_w + btn_gap, by), btn_w, btn_h, Color(0.28, 0.10, 0.10), _on_quit_pressed)

func _add_footer_button(text: String, pos: Vector2, w: int, h: int, bg_color: Color, callback: Callable):
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = Vector2(w, h)
	btn.add_theme_font_size_override("font_size", _sf(20))
	var mk = func(col: Color) -> StyleBoxFlat:
		var s = StyleBoxFlat.new()
		s.bg_color = col
		s.border_color = Color(0.45, 0.60, 0.45, 0.50)
		s.set_border_width_all(1)
		s.set_corner_radius_all(6)
		return s
	btn.add_theme_stylebox_override("normal",  mk.call(bg_color))
	btn.add_theme_stylebox_override("hover",   mk.call(bg_color.lightened(0.18)))
	btn.add_theme_stylebox_override("pressed", mk.call(bg_color.darkened(0.12)))
	btn.pressed.connect(callback)
	add_child(btn)

# ---- コールバック ----

func _on_play_pressed(scene_path: String):
	SoundManager.play_card_click()
	get_tree().change_scene_to_file(scene_path)

func _on_help_pressed():
	SoundManager.play_card_click()
	var help = HelpScreen.new()
	add_child(help)

func _on_settings_pressed():
	SoundManager.play_card_click()
	var settings = SettingsScreen.new()
	add_child(settings)

func _on_quit_pressed():
	SoundManager.play_card_click()
	get_tree().quit()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
