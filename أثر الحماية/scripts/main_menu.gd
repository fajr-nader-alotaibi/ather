extends Control

const Ui = preload("res://scripts/menu_theme.gd")
const TextCatalog = preload("res://scripts/localization.gd")
const CharacterLibrary = preload("res://scripts/character_library.gd")

var _hero: TextureRect
var _hero_sprite: AnimatedSprite2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	Ui.install_backdrop(self)
	_build()


func _build() -> void:
	var logo := VBoxContainer.new()
	Ui.place(logo, 0.10, 0.025, 0.63, 0.265)
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	logo.add_theme_constant_override("separation", -4)
	add_child(logo)

	var title := Ui.label("ATHAR", 84, Ui.GOLD)
	title.add_theme_color_override("font_outline_color", Color("493721"))
	title.add_theme_constant_override("outline_size", 5)
	logo.add_child(title)
	var arabic := Ui.label("أثــر", 40, Color("fff3cf"))
	arabic.add_theme_color_override("font_outline_color", Color("43543b"))
	logo.add_child(arabic)
	logo.add_child(Ui.label("—  GUARDIANS OF NATURE  —", 19, Color("fff1ce")))

	var tagline := Ui.label(_t("menu_tagline"), 17, Color("fff8e4"))
	Ui.place(tagline, 0.12, 0.265, 0.62, 0.335)
	add_child(tagline)

	_build_hero()
	_build_top_controls()
	_build_menu_panel()

	var chapter := Ui.label(_t("menu_chapter"), 16, Color("fff0c5"))
	Ui.place(chapter, 0.37, 0.94, 0.65, 0.99)
	chapter.add_theme_color_override("font_outline_color", Color("193c39"))
	chapter.add_theme_constant_override("outline_size", 3)
	add_child(chapter)


func _build_hero() -> void:
	var hero_view := SubViewport.new()
	hero_view.size = Vector2i(320, 360)
	hero_view.transparent_bg = true
	hero_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(hero_view)

	_hero_sprite = AnimatedSprite2D.new()
	_hero_sprite.position = Vector2(160.0, 204.0)
	_hero_sprite.scale = Vector2.ONE * 1.1
	CharacterLibrary.configure_sprite(_hero_sprite, GameSession.character_index, GameSession.outfit_index)
	hero_view.add_child(_hero_sprite)

	_hero = TextureRect.new()
	_hero.texture = hero_view.get_texture()
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.place(_hero, 0.105, 0.405, 0.37, 0.98)
	add_child(_hero)

	var companion := TextureRect.new()
	companion.texture = load("res://assets/companion.svg")
	companion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	companion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	companion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.place(companion, 0.335, 0.575, 0.405, 0.705)
	add_child(companion)


func _build_top_controls() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.anchor_left = 1.0
	top.anchor_right = 1.0
	top.offset_left = -234.0
	top.offset_right = -26.0
	top.offset_top = 22.0
	top.offset_bottom = 70.0
	add_child(top)

	var language_group := HBoxContainer.new()
	language_group.add_theme_constant_override("separation", 0)
	language_group.custom_minimum_size = Vector2(136, 48)
	top.add_child(language_group)
	var arabic := Ui.button("العربية", GameSession.language == "ar")
	arabic.custom_minimum_size = Vector2(88, 48)
	arabic.pressed.connect(_set_language.bind("ar"))
	language_group.add_child(arabic)
	var english := Ui.button("EN", GameSession.language == "en")
	english.custom_minimum_size = Vector2(48, 48)
	english.pressed.connect(_set_language.bind("en"))
	language_group.add_child(english)
	var sound := Ui.button("♪" if GameSession.muted else "♫")
	sound.custom_minimum_size = Vector2(64, 48)
	sound.pressed.connect(_toggle_sound.bind(sound))
	top.add_child(sound)


func _build_menu_panel() -> void:
	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.025, 0.12, 0.15, 0.84)
	frame_style.border_color = Color(0.69, 0.85, 0.56, 0.94)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(30)
	frame_style.set_content_margin_all(15)
	frame_style.shadow_color = Color(0.015, 0.055, 0.065, 0.45)
	frame_style.shadow_size = 16
	frame_style.shadow_offset = Vector2(0, 7)
	frame.add_theme_stylebox_override("panel", frame_style)
	Ui.place(frame, 0.675, 0.275, 0.975, 0.945)
	add_child(frame)

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 7)
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	frame.add_child(menu)

	var heading := Ui.label(_t("menu_panel_title"), 21, Color("d6e8a0"))
	heading.custom_minimum_size.y = 34
	menu.add_child(heading)
	_add(menu, _t("menu_start"), true, func(): GameSession.change_scene("res://scenes/mode_select.tscn"))
	_add(menu, _t("menu_character"), false, func(): GameSession.change_scene("res://scenes/character_select.tscn"))
	_add(menu, _t("menu_multiplayer"), false, func(): GameSession.change_scene("res://scenes/lobby.tscn"))
	_add(menu, _t("menu_settings"), false, func(): GameSession.change_scene("res://scenes/settings.tscn"))
	_add(menu, _t("menu_team"), false, _show_team)
	_add(menu, _t("menu_exit"), false, func(): get_tree().quit())


func _add(parent: VBoxContainer, caption: String, primary: bool, action: Callable) -> void:
	var button := Ui.button(caption, primary)
	button.custom_minimum_size = Vector2(0, 50)
	var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
	if normal != null:
		normal.shadow_color = Color(0.01, 0.05, 0.05, 0.3)
		normal.shadow_size = 4
		normal.shadow_offset = Vector2(0, 3)
	var hover := button.get_theme_stylebox("hover") as StyleBoxFlat
	if hover != null:
		hover.border_color = Color("e0ef9d") if primary else Color("b7e4c6")
		hover.set_border_width_all(3)
		hover.shadow_color = Color(0.45, 0.78, 0.46, 0.28)
		hover.shadow_size = 8
	var pressed := button.get_theme_stylebox("pressed") as StyleBoxFlat
	if pressed != null:
		pressed.bg_color = Color("326c43") if primary else Color("123f4a")
		pressed.border_color = Color("f3dc8e")
	button.pressed.connect(action)
	parent.add_child(button)


func _t(key: String) -> String:
	return TextCatalog.text(key, GameSession.language)


func _set_language(language: String) -> void:
	if GameSession.language == language:
		return
	GameSession.language = language
	GameSession.save_profile()
	GameSession.change_scene("res://scenes/main_menu.tscn")


func _toggle_sound(button: Button) -> void:
	GameSession.muted = not GameSession.muted
	GameSession.apply_audio_settings()
	GameSession.save_profile()
	button.text = "♪" if GameSession.muted else "♫"


func _show_team() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.015, 0.045, 0.055, 0.64)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var dialog := PanelContainer.new()
	dialog.anchor_left = 0.5
	dialog.anchor_right = 0.5
	dialog.anchor_top = 0.5
	dialog.anchor_bottom = 0.5
	dialog.offset_left = -260.0
	dialog.offset_right = 260.0
	dialog.offset_top = -150.0
	dialog.offset_bottom = 150.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.15, 0.17, 0.98)
	panel_style.border_color = Color("b5d889")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(26)
	panel_style.set_content_margin_all(26)
	panel_style.shadow_color = Color(0.0, 0.02, 0.03, 0.55)
	panel_style.shadow_size = 18
	panel_style.shadow_offset = Vector2(0, 8)
	dialog.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(dialog)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	dialog.add_child(content)
	var title := Ui.label(_t("menu_team"), 28, Ui.GOLD)
	content.add_child(title)
	var about := Ui.label(_t("team_about"), 19, Ui.CREAM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size.y = 112
	content.add_child(about)
	var close := Ui.button(_t("close"), true)
	close.custom_minimum_size.y = 48
	close.pressed.connect(overlay.queue_free)
	content.add_child(close)