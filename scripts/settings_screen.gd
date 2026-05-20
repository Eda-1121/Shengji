# settings_screen.gd - 設定オーバーレイ
extends Control
class_name SettingsScreen

signal closed

var _sound_btn_on: Button
var _sound_btn_off: Button
var _lang_btn_ja: Button
var _lang_btn_en: Button

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui():
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.65)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vp = get_viewport_rect().size
	var panel = Control.new()
	panel.position = Vector2(int((vp.x - 500) / 2), int((vp.y - 340) / 2))
	panel.size = Vector2(500, 340)
	add_child(panel)

	var panel_bg = ColorRect.new()
	panel_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_bg.color = Color(0.05, 0.16, 0.07)
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(panel_bg)

	for rect in [
		[Vector2(0,   0),   Vector2(500, 2)],
		[Vector2(0,   338), Vector2(500, 2)],
		[Vector2(0,   0),   Vector2(2,   340)],
		[Vector2(498, 0),   Vector2(2,   340)],
	]:
		var border = ColorRect.new()
		border.position = rect[0]
		border.size     = rect[1]
		border.color    = Color(0.4, 0.7, 0.4, 0.55)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(border)

	var title = Label.new()
	title.text = "設　定"
	title.position = Vector2(0, 16)
	title.size = Vector2(500, 48)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.38))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title)

	_add_separator(panel, 70)

	_add_row_label(panel, "サウンド", 84)
	_sound_btn_on  = _make_button("ON",  Vector2(100, 118))
	_sound_btn_off = _make_button("OFF", Vector2(260, 118))
	_sound_btn_on.pressed.connect(_on_sound_on)
	_sound_btn_off.pressed.connect(_on_sound_off)
	panel.add_child(_sound_btn_on)
	panel.add_child(_sound_btn_off)

	_add_separator(panel, 178)

	_add_row_label(panel, "言語 / Language", 192)
	_lang_btn_ja = _make_button("日本語", Vector2(100, 226))
	_lang_btn_en = _make_button("English", Vector2(260, 226))
	_lang_btn_ja.pressed.connect(_on_lang_ja)
	_lang_btn_en.pressed.connect(_on_lang_en)
	panel.add_child(_lang_btn_ja)
	panel.add_child(_lang_btn_en)

	_add_separator(panel, 282)

	var close_btn = _make_button("閉じる", Vector2(170, 292))
	close_btn.size = Vector2(160, 40)
	close_btn.pressed.connect(_on_close)
	panel.add_child(close_btn)

	_update_sound_buttons()
	_update_lang_buttons()

func _add_separator(parent: Control, y: int):
	var sep = ColorRect.new()
	sep.position = Vector2(50, y)
	sep.size = Vector2(400, 1)
	sep.color = Color(0.4, 0.7, 0.4, 0.35)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sep)

func _add_row_label(parent: Control, text: String, y: int):
	var lbl = Label.new()
	lbl.text = text
	lbl.position = Vector2(50, y)
	lbl.size = Vector2(400, 30)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.92, 0.75))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)

func _make_button(text: String, pos: Vector2) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = Vector2(140, 48)
	btn.add_theme_font_size_override("font_size", 20)
	return btn

func _set_button_active(btn: Button, active: bool):
	var mk = func(color: Color) -> StyleBoxFlat:
		var s = StyleBoxFlat.new()
		s.bg_color = color
		s.border_color = Color(0.55, 0.80, 0.45, 0.75) if active else Color(0.35, 0.55, 0.35, 0.45)
		s.set_border_width_all(1)
		s.set_corner_radius_all(6)
		s.content_margin_left  = 8
		s.content_margin_right = 8
		return s

	var base_color = Color(0.16, 0.48, 0.20) if active else Color(0.09, 0.24, 0.12)
	btn.add_theme_stylebox_override("normal",  mk.call(base_color))
	btn.add_theme_stylebox_override("hover",   mk.call(base_color.lightened(0.15)))
	btn.add_theme_stylebox_override("pressed", mk.call(base_color.darkened(0.10)))
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.85) if active else Color(0.70, 0.85, 0.70))

func _update_sound_buttons():
	_set_button_active(_sound_btn_on,  GameConfig.sound_enabled)
	_set_button_active(_sound_btn_off, not GameConfig.sound_enabled)

func _update_lang_buttons():
	_set_button_active(_lang_btn_ja, GameConfig.language == "ja")
	_set_button_active(_lang_btn_en, GameConfig.language == "en")

func _on_lang_ja():
	SoundManager.play_card_click()
	GameConfig.language = "ja"
	_update_lang_buttons()

func _on_lang_en():
	SoundManager.play_card_click()
	GameConfig.language = "en"
	_update_lang_buttons()

func _on_sound_on():
	GameConfig.sound_enabled = true
	SoundManager.play_card_click()
	_update_sound_buttons()

func _on_sound_off():
	GameConfig.sound_enabled = false
	_update_sound_buttons()

func _on_close():
	SoundManager.play_card_click()
	closed.emit()
	queue_free()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close()
