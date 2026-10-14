extends Control

const Ui = preload("res://scripts/menu_theme.gd")
const TextCatalog = preload("res://scripts/localization.gd")

var _companion: TextureRect
var _hero: TextureRect
var _clock := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	Ui.direction(self)
	Ui.install_backdrop(self)
	_build()

func _process(delta: float) -> void:
	_clock += delta
	if is_instance_valid(_companion):
		_companion.rotation = sin(_clock * 1.3) * 0.035
		_companion.offset_top = sin(_clock * 1.8) * 8.0
		_companion.offset_bottom = _companion.offset_top + _companion.size.y
	if is_instance_valid(_hero):
		_hero.offset_top = sin(_clock * 1.15) * 3.0
		_hero.offset_bottom = _hero.offset_top + _hero.size.y

func _build() -> void:
	var logo := VBoxContainer.new()
	Ui.place(logo, 0.31, 0.025, 0.79, 0.285)
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	logo.add_theme_constant_override("separation", -5)
	add_child(logo)
	var title := Ui.label("ATHAR", 84, Ui.GOLD)
	title.add_theme_color_override("font_outline_color", Color("543f28"))
	title.add_theme_constant_override("outline_size", 5)
	logo.add_child(title)
	var arabic := Ui.label("أثــر", 40, Color("fff0c4"))
	logo.add_child(arabic)
	logo.add_child(Ui.label("—  GUARDIANS OF NATURE  —", 19, Color("fff1c9")))
	var tagline := Ui.label(_t("menu_tagline"), 16)
	Ui.place(tagline, 0.37, 0.285, 0.73, 0.345)
	add_child(tagline)

	_hero = TextureRect.new()
	_hero.texture = load("res://assets/outfits/explorer_%d.svg" % clampi(GameSession.outfit_index, 0, 5))
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	Ui.place(_hero, 0.60, 0.42, 0.81, 0.92)
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hero)
	_companion = TextureRect.new()
	_companion.texture = load("res://assets/companion.svg")
	_companion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_companion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	Ui.place(_companion, 0.52, 0.50, 0.62, 0.65)
	_companion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_companion)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.anchor_left = 1.0
	top.anchor_right = 1.0
	top.offset_left = -240
	top.offset_right = -26
	top.offset_top = 22
	top.offset_bottom = 70
	add_child(top)
	var language := Ui.button("العربية  |  EN")
	language.custom_minimum_size = Vector2(145, 48)
	language.pressed.connect(_toggle_language)
	top.add_child(language)
	var sound := Ui.button("♪" if GameSession.muted else "♫")
	sound.custom_minimum_size = Vector2(64, 48)
	sound.pressed.connect(_toggle_sound.bind(sound))
	top.add_child(sound)

	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.025, 0.13, 0.16, 0.76)
	frame_style.border_color = Color(0.66, 0.83, 0.51, 0.88)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(30)
	frame_style.set_content_margin_all(14)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.anchor_left = 0.045
	frame.anchor_right = 0.365
	frame.anchor_top = 0.30
	frame.anchor_bottom = 0.92
	add_child(frame)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	frame.add_child(menu)
	_add(menu, _t("menu_start"), true, func(): GameSession.change_scene("res://scenes/mode_select.tscn"))
	_add(menu, _t("menu_character"), false, func(): GameSession.change_scene("res://scenes/character_select.tscn"))
	_add(menu, _t("menu_multiplayer"), false, func(): GameSession.change_scene("res://scenes/lobby.tscn"))
	_add(menu, _t("menu_settings"), false, func(): GameSession.change_scene("res://scenes/settings.tscn"))
	_add(menu, _t("menu_team"), false, _show_team)
	_add(menu, _t("menu_exit"), false, func(): get_tree().quit())
	var chapter := Ui.label(_t("menu_chapter"), 15, Color("fff0c5"))
	chapter.anchor_left = 0.37
	chapter.anchor_right = 0.72
	chapter.anchor_top = 0.92
	chapter.anchor_bottom = 0.98
	add_child(chapter)

func _add(parent: VBoxContainer, caption: String, primary: bool, action: Callable) -> void:
	var b := Ui.button(caption, primary)
	b.custom_minimum_size.y = 55
	b.pressed.connect(action)
	parent.add_child(b)

func _t(key: String) -> String:
	return TextCatalog.text(key, GameSession.language)

func _toggle_language() -> void:
	GameSession.language = "en" if GameSession.language == "ar" else "ar"
	GameSession.save_profile()
	GameSession.change_scene("res://scenes/main_menu.tscn")

func _toggle_sound(button: Button) -> void:
	GameSession.muted = not GameSession.muted
	GameSession.apply_audio_settings()
	GameSession.save_profile()
	button.text = "♪" if GameSession.muted else "♫"

func _show_team() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = _t("menu_team")
	dialog.dialog_text = _t("team_about")
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(480, 220))
