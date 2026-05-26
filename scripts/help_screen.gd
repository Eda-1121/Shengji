# help_screen.gd - ゲーム内遊び方ガイド
extends Control
class_name HelpScreen

signal closed

const SECTIONS = ["概要", "チーム", "カード", "トランプ", "ゲームの流れ", "出牌ルール", "点数・升级", "コツ"]

const C_TITLE   = "#ffd700"  # 金：大見出し
const C_HEAD    = "#7ec8e3"  # 水色：小見出し
const C_CARD    = "#ffb347"  # オレンジ：カード名
const C_KEY     = "#90ee90"  # 緑：キーワード
const C_WARN    = "#ffff88"  # 黄：注意
const C_DIM     = "#8899aa"  # グレー：補足
const C_GOOD    = "#66dd66"  # 明るい緑
const C_BAD     = "#ff7777"  # 赤

var _section_btns: Array[Button] = []
var _rich: RichTextLabel
var _scroll: ScrollContainer

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

# ================================================================
#  UI構築
# ================================================================

func _build_ui():
	# 背景オーバーレイ
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.80)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# ── パネル本体 ──────────────────────────────────────
	var vp  = get_viewport_rect().size
	var mx  = int(vp.x * 0.021)   # 横マージン（≈30px @1440）
	var my  = int(vp.y * 0.015)   # 縦マージン（≈12px @810）
	var PW  = int(vp.x - mx * 2)
	var PH  = int(vp.y - my * 2)

	var panel = Control.new()
	panel.position = Vector2(mx, my)
	panel.size     = Vector2(PW, PH)
	add_child(panel)

	# パネル背景
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.051, 0.106, 0.165)
	ps.border_color = Color(0.941, 0.788, 0.416, 0.38)
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", ps) if panel is Panel else null
	var pbg = ColorRect.new()
	pbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pbg.color = Color(0.051, 0.106, 0.165)
	pbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pbg)

	# ── ヘッダーバー ──────────────────────────────────
	var hdr = ColorRect.new()
	hdr.position = Vector2(0, 0)
	hdr.size     = Vector2(PW, 52)
	hdr.color    = Color(0.035, 0.070, 0.110)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hdr)

	# ヘッダーゴールドライン
	var accent = ColorRect.new()
	accent.position = Vector2(0, 0)
	accent.size     = Vector2(4, 52)
	accent.color    = Color(0.941, 0.788, 0.416)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(accent)

	var title_lbl = Label.new()
	title_lbl.text = "  遊び方ガイド  —  升级 / 拖拉機"
	title_lbl.position = Vector2(8, 8)
	title_lbl.size = Vector2(1100, 36)
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.38))
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = "✕  閉じる"
	close_btn.position = Vector2(PW - 144, 9)
	close_btn.size = Vector2(132, 34)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(_on_close)
	panel.add_child(close_btn)

	# ── タブ行 ────────────────────────────────────────
	var tab_bg = ColorRect.new()
	tab_bg.position = Vector2(0, 52)
	tab_bg.size     = Vector2(PW, 38)
	tab_bg.color    = Color(0.035, 0.070, 0.110)
	tab_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(tab_bg)

	var tab_w = float(PW) / SECTIONS.size()
	for i in SECTIONS.size():
		var btn = Button.new()
		btn.text     = SECTIONS[i]
		btn.position = Vector2(i * tab_w, 52)
		btn.size     = Vector2(tab_w - 1, 38)
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(func(): _switch_section(i))
		panel.add_child(btn)
		_section_btns.append(btn)

	# ヘッダー下の仕切り
	var sep = ColorRect.new()
	sep.position = Vector2(0, 90)
	sep.size     = Vector2(PW, 1)
	sep.color    = Color(0.941, 0.788, 0.416, 0.30)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(sep)

	# ── コンテンツ（スクロール） ─────────────────────
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 92)
	_scroll.size     = Vector2(PW, PH - 92)
	panel.add_child(_scroll)

	_rich = RichTextLabel.new()
	_rich.custom_minimum_size = Vector2(PW - 20, 0)
	_rich.size = Vector2(PW - 20, 0)
	_rich.fit_content = true
	_rich.bbcode_enabled = true
	_rich.scroll_active = false
	_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rich.add_theme_constant_override("line_separation", 4)
	var rich_style = StyleBoxFlat.new()
	rich_style.content_margin_left  = 20
	rich_style.content_margin_right = 20
	rich_style.content_margin_top   = 8
	rich_style.bg_color = Color(0, 0, 0, 0)
	_rich.add_theme_stylebox_override("normal", rich_style)
	_scroll.add_child(_rich)

	# パネル外枠
	for r in [
		[Vector2(0,    0),      Vector2(PW,  1)],
		[Vector2(0,    PH - 1), Vector2(PW,  1)],
		[Vector2(0,    0),      Vector2(1,   PH)],
		[Vector2(PW-1, 0),      Vector2(1,   PH)],
	]:
		var b = ColorRect.new()
		b.position = r[0]; b.size = r[1]
		b.color = Color(0.941, 0.788, 0.416, 0.35)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(b)

	_switch_section(0)

# ================================================================
#  タブ切り替え
# ================================================================

func _switch_section(idx: int):
	for i in _section_btns.size():
		var s = StyleBoxFlat.new()
		var active = (i == idx)
		s.bg_color     = Color(0.08, 0.14, 0.10, 0.90) if active else Color(0.035, 0.070, 0.110)
		s.border_color = Color(0.941, 0.788, 0.416, 0.80) if active else Color(0.941, 0.788, 0.416, 0.18)
		s.set_border_width_all(0)
		s.border_width_bottom = 3 if active else 1
		s.set_corner_radius_all(0)
		_section_btns[i].add_theme_stylebox_override("normal", s)
		_section_btns[i].add_theme_stylebox_override("hover",  s if active else _hover_style())
		var fc = Color(1.0, 0.92, 0.38) if active else Color(0.75, 0.87, 1.00)
		_section_btns[i].add_theme_color_override("font_color", fc)
	_rich.text = _get_content(idx)
	_scroll.scroll_vertical = 0

func _hover_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.10, 0.16)
	s.border_width_bottom = 1
	s.border_color = Color(0.941, 0.788, 0.416, 0.30)
	return s

# ================================================================
#  BBCode ヘルパー
# ================================================================

func H(text: String) -> String:
	return "\n[bgcolor=#0d1e35][color=%s][b]  %s  [/b][/color][/bgcolor]\n" % [C_TITLE, text]

func H2(text: String) -> String:
	return "\n[color=%s][b]▌ %s[/b][/color]\n" % [C_HEAD, text]

func T(text: String) -> String:
	return "[indent]%s[/indent]\n" % text

func Bullet(items: Array) -> String:
	var s = ""
	for item in items:
		s += "[indent]  •  %s[/indent]\n" % item
	return s

func card(t: String) -> String:
	return "[color=%s][b]%s[/b][/color]" % [C_CARD, t]

func key(t: String) -> String:
	return "[color=%s][b]%s[/b][/color]" % [C_KEY, t]

func warn(t: String) -> String:
	return "[indent][bgcolor=#2a2800][color=%s]  ⚠  %s  [/color][/bgcolor][/indent]\n" % [C_WARN, t]

func dim(t: String) -> String:
	return "[color=%s]%s[/color]" % [C_DIM, t]

# ================================================================
#  セクション別コンテンツ
# ================================================================

func _get_content(idx: int) -> String:
	match idx:
		0: return _s_overview()
		1: return _s_teams()
		2: return _s_cards()
		3: return _s_trump()
		4: return _s_flow()
		5: return _s_play_rules()
		6: return _s_scoring()
		7: return _s_tips()
	return ""

func _s_overview() -> String:
	var t = H("🀄  升级 / 拖拉機（シェンジー）とは")
	t += T("中国で広く親しまれている [b]4人用トリックテイキングカードゲーム[/b] です。")
	t += T("2チームに分かれて対戦し、チームのレベルを [b]2 → 3 → 4 → … → A[/b] と上げていきます。")
	t += T(key("先にAを超えたチームが勝利") + "です。")
	t += H2("基本情報")
	t += Bullet([
		"プレイ人数：[b]4人[/b]（2チーム）",
		"使用デッキ：[b]2副（108枚）[/b] または [b]4副（216枚）[/b]　" + dim("（設定から変更可）"),
		"1ゲームの所要時間：[b]約30〜60分[/b]",
	])
	t += H2("ゲームの大まかな流れ")
	t += Bullet([
		"[b]① 発牌[/b]　カードを全員に配る",
		"[b]② 叫牌[/b]　主牌（切り札スート）を宣言する",
		"[b]③ 埋底[/b]　庄家が8枚を底牌として伏せる",
		"[b]④ 出牌[/b]　順番にカードを出してトリックを取り合う",
		"[b]⑤ 点数計算[/b]　攻撃チームが80点以上取れば勝利",
		"[b]⑥ 升级[/b]　勝ったチームのレベルが上がる → ①に戻る",
	])
	return t

func _s_teams() -> String:
	var t = H("👥  チームとポジション")
	t += T("向かい合う2人が同じチームです。")
	t += T("[b]チームA[/b]：1番（あなた）・3番（向かい）　　[b]チームB[/b]：2番（左）・4番（右）")
	t += H2("庄家チームと攻撃チーム")
	t += Bullet([
		key("庄家チーム（守備）") + "：叫牌で主牌を宣言したチーム。底牌を使える。自分たちのレベルを守る側。",
		key("攻撃チーム") + "：庄家に挑戦する側。[b]80点以上[/b]取れば勝利・庄家交代。",
	])
	t += H2("レベル（等級）")
	t += T("各チームには現在の [b]レベル（2〜A）[/b] があります。")
	t += T("そのラウンドの " + key("等級牌") + " は、庄家チームの現在レベルと同じ数字のカードです。")
	t += T(dim("例）チームAのレベルが 7 なら、今ラウンドの等級牌は「すべての7」"))
	t += warn("等級牌はどのスートでも特別なトランプ扱いになります（詳しくは「トランプ」タブ）。")
	return t

func _s_cards() -> String:
	var t = H("🃏  カードの種類と点数")
	t += T("標準トランプ（ジョーカー含む）を [b]2副（108枚）[/b] 使います。")
	t += H2("点数になるカード")
	t += T(card("5") + "　→　[b]5点[/b]　　" + card("10") + " ・ " + card("K") + "　→　[b]各10点[/b]　　それ以外　→　[b]0点[/b]")
	t += T(dim("1副あたり 5点×4 + 10点×8 = 計100点。2副なら合計200点が全体の得点です。"))
	t += H2("ジョーカー（大王・小王）")
	t += Bullet([
		card("大王（Big Joker）") + "：ゲーム中 [b]最強[/b] のカード。点数は0点。",
		card("小王（Small Joker）") + "：2番目に強いカード。点数は0点。",
		"どちらも常にトランプ扱い。スートは問いません。",
	])
	t += H2("カードの強さ（同スート内）")
	t += T("2 < 3 < 4 < 5 < 6 < 7 < 8 < 9 < 10 < J < Q < K < A")
	t += T(dim("スートをまたいだ比較は、トランプを除きできません。"))
	return t

func _s_trump() -> String:
	var t = H("♠  トランプ（主牌）の序列")
	t += T("[b]主牌[/b] はどのスートのカードより強く、跟牌できないときにも出せます。")
	t += H2("主牌の強さ順（強い方から）")
	t += "\n"
	var ranks = [
		["①", "大王", "最強カード"],
		["②", "小王", "2番目"],
		["③", "主花色の等級牌", "例：主スート♠・レベル7 → 「♠7」"],
		["④", "他スートの等級牌", "例：「♥7」「♣7」「♦7」（互いに同じ強さ）"],
		["⑤", "主花色の通常牌", "例：♠A > ♠K > … > ♠2　（①〜④を除く）"],
	]
	for r in ranks:
		t += "[indent]  [color=%s][b]%s[/b][/color]  " % [C_HEAD, r[0]]
		t += card(r[1]) + "　" + dim(r[2]) + "[/indent]\n"
	t += "\n"
	t += warn("等級牌は自分のスートに関係なく、すべてトランプ扱いです！")
	t += H2("非主牌（通常スート）")
	t += T("主牌以外は通常スートです。同スート内での比較のみ有効。")
	t += H2("主牌の決め方（叫牌）")
	t += Bullet([
		"配牌中に等級牌を持っていれば [b]叫牌[/b] して主スートを宣言できます。",
		"[b]対子（2枚）[/b] での宣言は [b]単張（1枚）[/b] の宣言を上書きできます。",
		"誰も叫牌しなければ " + key("スペードが主牌") + " になります。",
	])
	return t

func _s_flow() -> String:
	var t = H("🔄  ゲームの流れ")

	t += H2("Step 1　発牌（配牌）")
	t += T("全員にカードが均等に配られます。")
	t += T("あなたの手牌は画面下に表示されます。配牌中も叫牌の機会があります。")

	t += H2("Step 2　叫牌（主牌宣言）")
	t += T("配牌中に等級牌を受け取ったとき、画面の [b]叫牌ボタン[/b] で宣言できます。")
	t += Bullet([
		"単張（1枚）で宣言 → 最初の叫牌",
		"対子（2枚）で宣言 → 単張の宣言を上書き可能",
		"配牌終了後、最後に叫牌した人が " + key("庄家") + " になります。",
	])

	t += H2("Step 3　埋底（底牌を埋める）")
	t += T("庄家は底牌8枚を受け取り、手牌から [b]8枚を選んで伏せます[/b]。")
	t += T("埋めたカードは最終トリックの勝者チームの得点に加算されます。")
	t += "\n"
	t += "[indent]カードのオーバーレイの意味：\n"
	t += "  [color=#ff6666][b]赤[/b][/color] = 絶対NG（トランプ・等級牌）　　"
	t += "[color=#ffff44][b]黄[/b][/color] = 注意（5・10・K）　　"
	t += "[color=#66ff66][b]緑[/b][/color] = 安全[/indent]\n"
	t += warn("おすすめ8枚が自動選択されます。変更は自由です。")

	t += H2("Step 4　出牌（トリックテイキング）")
	t += T("庄家から時計回りに1枚以上カードを出します。")
	t += T("4人全員が出し終えると [b]1トリック完了[/b]。トリック内の得点は勝者チームが獲得。")
	t += T("出牌の詳しいルールは「出牌ルール」タブへ。")
	return t

func _s_play_rules() -> String:
	var t = H("🎴  出牌のルール")
	t += T("カードは [b]4種類のパターン[/b] で出せます。")

	t += H2("① 単牌（シングル）")
	t += T("1枚のみ。例）" + card("♠K") + "、" + card("♥5"))

	t += H2("② 対子（ペア）")
	t += T("同じカード2枚。例）" + card("♣10 × 2") + "、" + card("大王 × 2"))

	t += H2("③ 拖拉機（トラクター）")
	t += T("[b]連続する対子[/b] を2組以上。最低4枚。")
	t += T("例）" + card("♠8×2  +  ♠9×2") + dim("（8の対子 → 9の対子）"))
	t += warn("等級牌はランクがスキップされます（レベル7なら 6・8が連続扱い）。")

	t += H2("④ 甩牌（スロー）")
	t += T("首出のみ使える特殊形。複数の異なるパターンを同時に出します。")
	t += T("他の全員が [b]どれか1枚も上回れない[/b] 場合のみ有効。失敗すると相手に管理されます。")

	t += H2("跟牌（フォロー）の優先順位")
	t += T("[b]リードと同スートのカードがあれば必ず出す義務[/b] があります。")
	t += "\n"
	t += "[indent]リードが [b]拖拉機[/b] のとき：\n"
	t += "  [color=%s]1位[/color] 同スートの拖拉機  →  [color=%s]2位[/color] 同スートの対子  →  [color=%s]3位[/color] 同スートの単牌  →  [color=%s]4位[/color] 何でも[/indent]\n\n" % [C_KEY, C_KEY, C_KEY, C_DIM]
	t += H2("トリックの勝敗")
	t += Bullet([
		"トランプが出ていれば " + key("最強のトランプ") + " が勝ち",
		"トランプがなければ " + key("リードと同スートの最強カード") + " が勝ち",
		"リードより強いカードが一切なければリードしたカードが勝ち",
	])
	return t

func _s_scoring() -> String:
	var t = H("📊  点数計算と升级")
	t += T("[b]攻撃チームの獲得点数[/b] によってラウンドの結果と升级数が変わります。")

	t += H2("最終トリックのボーナス倍率（攻撃チームが勝った場合）")
	t += Bullet([
		"通常：底牌点数 × [b]2[/b]",
		"小王ペアで勝利：× [b]4[/b]",
		"大王ペアで勝利：× [b]8[/b]",
		"両ジョーカーペアで勝利：× [b]16[/b]",
	])

	t += H2("升级表")
	t += "\n"
	var rows = [
		[C_GOOD, "攻撃チーム 200点〜", "攻撃 +4レベル　（圧勝）"],
		[C_GOOD, "攻撃チーム 160〜199点", "攻撃 +3レベル"],
		[C_GOOD, "攻撃チーム 120〜159点", "攻撃 +2レベル"],
		[C_GOOD, "攻撃チーム  80〜119点", "攻撃 +1レベル　庄家交代"],
		[C_WARN, "攻撃チーム  40〜79点",  "庄家 +1レベル"],
		[C_WARN, "攻撃チーム   1〜39点",  "庄家 +2レベル"],
		[C_BAD,  "攻撃チーム   0点",      "庄家 +3レベル　（圧勝）"],
	]
	for r in rows:
		t += "[indent]  [color=%s]%-22s[/color]  →  [b]%s[/b][/indent]\n" % [r[0], r[1], r[2]]
	t += "\n"
	t += warn("攻撃チームが80点以上取ると庄家が交代します！")

	t += H2("ゲーム終了")
	t += T("いずれかのチームのレベルが [b]A（14）を超えたとき[/b]、そのチームが優勝！")
	return t

func _s_tips() -> String:
	var t = H("💡  上達のコツ")

	t += H2("埋底の選び方")
	t += Bullet([
		"[b]トランプ・等級牌は絶対に埋めない[/b]（最終トリックで相手に大量得点を与える）",
		"5・10・K も埋めると底牌ボーナスで得点が倍増するリスクあり",
		"同スートのカードをまとめて埋めると、そのスートを「切れ」にできて有利",
	])

	t += H2("出牌の戦略")
	t += Bullet([
		key("トランプを引き出す") + "：高トランプでリードして相手のトランプを消耗させる",
		key("仲間への点渡し") + "：仲間がトリックを取りそうなとき、5・10・K を乗せる",
		key("切れスート活用") + "：そのスートが切れた後は自由に出せるので積極的にリード",
	])

	t += H2("叫牌のタイミング")
	t += Bullet([
		"対子（2枚）を持っているなら積極的に叫牌する",
		"トランプが少ない状態での庄家はリスクが高い",
		"相手が叫牌したらより多くの枚数で「反叫（反主）」を狙う",
	])

	t += H2("画面の見方")
	t += Bullet([
		"[color=#5599ff]青いオーバーレイ[/color]　→　AI 推奨カード（参考程度に）",
		"[color=#66ff66]緑[/color]/[color=#ffff44]黄[/color]/[color=#ff6666]赤[/color] オーバーレイ　→　埋底時の安全度",
		"右上「前の手」ボタン　→　直前のトリック内容を確認",
		"画面左上のカード枚数表示　→　各AIプレイヤーの残り手牌数",
	])
	return t

# ================================================================
#  コールバック
# ================================================================

func _on_close():
	SoundManager.play_card_click()
	closed.emit()
	queue_free()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close()
