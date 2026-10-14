extends Control

const Ui = preload("res://scripts/menu_theme.gd")
const TextCatalog = preload("res://scripts/localization.gd")
const CharacterLibrary = preload("res://scripts/character_library.gd")

var _character_index := 0
var _color_index := 0
var _cards: Array[Button] = []
var _previews: Array[AnimatedSprite2D] = []
var _swatches: Array[Button] = []
var _selected_label: Label


func _ready() -> void:
	Ui.direction(self)
	Ui.install_backdrop(self)
	_character_index = clampi(GameSession.character_index, 0, 1)
	_color_index = clampi(GameSession.outfit_index, 0, 5)
	_build()
	_refresh()


func _build() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 42
	layout.offset_right = -42
	layout.offset_top = 22
	layout.offset_bottom = -24
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	header.add_child(Ui.label(_t("character_title"), 37, Ui.GOLD))
	header.add_child(Ui.label("ATHAR  ·  GUARDIANS OF NATURE", 13, Color("c5ddce")))
	layout.add_child(header)

	var character_row := HBoxContainer.new()
	character_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_row.add_theme_constant_override("separation", 18)
	character_row.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(character_row)
	for index in range(2):
		var card := _build_character_card(index)
		_cards.append(card)
		character_row.add_child(card)

	var palette_panel := PanelContainer.new()
	var palette_style := StyleBoxFlat.new()
	palette_style.bg_color = Color(0.025, 0.12, 0.15, 0.82)
	palette_style.border_color = Color(0.42, 0.66, 0.59, 0.56)
	palette_style.set_border_width_all(1)
	palette_style.set_corner_radius_all(20)
	palette_style.set_content_margin_all(10)
	palette_panel.add_theme_stylebox_override("panel", palette_style)
	layout.add_child(palette_panel)

	var palette_row := HBoxContainer.new()
	palette_row.alignment = BoxContainer.ALIGNMENT_CENTER
	palette_row.add_theme_constant_override("separation", 12)
	palette_panel.add_child(palette_row)
	palette_row.add_child(Ui.label(_t("character_color"), 17, Color("e4d39d")))
	for index in range(CharacterLibrary.PALETTE_HEX.size()):
		var swatch := _build_swatch(index)
		_swatches.append(swatch)
		palette_row.add_child(swatch)
	_selected_label = Ui.label("", 16, Color("e4e7cf"))
	_selected_label.custom_minimum_size.x = 230
	palette_row.add_child(_selected_label)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 14)
	layout.add_child(footer)
	var back := Ui.button(_t("back"))
	back.custom_minimum_size = Vector2(190, 50)
	back.pressed.connect(func() -> void: GameSession.change_scene("res://scenes/main_menu.tscn"))
	footer.add_child(back)
	var confirm := Ui.button(_t("character_save"), true)
	confirm.custom_minimum_size = Vector2(260, 50)
	confirm.pressed.connect(_save)
	footer.add_child(confirm)


func _build_character_card(index: int) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(420, 370)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.pressed.connect(_select_character.bind(index))
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 3)
	card.add_child(content)

	var name_label := Ui.label(CharacterLibrary.character_name(index, GameSession.language), 23, Color("fff0c5"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)
	var role := Ui.label("✦  %s" % ("حارسة الطبيعة" if index == 0 else "مستكشف الدروب") if GameSession.language == "ar" else ("✦  Forest keeper" if index == 0 else "✦  Trail scout"), 13, Color("bbd9ca"))
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(role)

	var preview_box := SubViewportContainer.new()
	preview_box.stretch = true
	preview_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_box.custom_minimum_size = Vector2(240, 232)
	preview_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(preview_box)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(240, 232)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_box.add_child(viewport)
	var sprite := AnimatedSprite2D.new()
	sprite.position = Vector2(120, 116)
	CharacterLibrary.configure_sprite(sprite, index, _color_index)
	viewport.add_child(sprite)
	_previews.append(sprite)

	var description := Ui.label(CharacterLibrary.character_description(index, GameSession.language), 14, Color("e1e6d2"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 36
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(description)
	return card


func _build_swatch(index: int) -> Button:
	var swatch := Button.new()
	swatch.custom_minimum_size = Vector2(46, 46)
	swatch.focus_mode = Control.FOCUS_ALL
	swatch.pressed.connect(_select_color.bind(index))
	var marker := Label.new()
	marker.name = "SelectedMark"
	marker.text = "✓"
	marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_theme_font_size_override("font_size", 24)
	marker.add_theme_color_override("font_color", Color.WHITE)
	marker.add_theme_color_override("font_outline_color", Color("303c36"))
	marker.add_theme_constant_override("outline_size", 4)
	swatch.add_child(marker)
	return swatch


func _refresh() -> void:
	for index in range(_cards.size()):
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.035, 0.15, 0.17, 0.91)
		style.border_color = Color("f4d58a") if index == _character_index else Color("75aaa0")
		style.set_border_width_all(4 if index == _character_index else 2)
		style.set_corner_radius_all(25)
		style.set_content_margin_all(14)
		_cards[index].add_theme_stylebox_override("normal", style)
		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.08, 0.22, 0.22, 0.96)
		_cards[index].add_theme_stylebox_override("hover", hover)
		_cards[index].add_theme_stylebox_override("pressed", style)
	for index in range(_swatches.size()):
		var swatch_style := StyleBoxFlat.new()
		swatch_style.bg_color = CharacterLibrary.palette_color(index)
		swatch_style.border_color = Color("fff1c4") if index == _color_index else Color(0.04, 0.10, 0.13, 0.88)
		swatch_style.set_border_width_all(4 if index == _color_index else 2)
		swatch_style.set_corner_radius_all(25)
		swatch_style.content_margin_left = 0
		swatch_style.content_margin_right = 0
		swatch_style.content_margin_top = 0
		swatch_style.content_margin_bottom = 0
		_swatches[index].add_theme_stylebox_override("normal", swatch_style)
		_swatches[index].add_theme_stylebox_override("hover", swatch_style)
		_swatches[index].add_theme_stylebox_override("pressed", swatch_style)
		_swatches[index].get_node("SelectedMark").visible = index == _color_index
	for index in range(_previews.size()):
		CharacterLibrary.apply_palette(_previews[index], _color_index, index)
	_selected_label.text = CharacterLibrary.palette_name(_color_index, GameSession.language)


func _select_character(index: int) -> void:
	_character_index = clampi(index, 0, 1)
	GameSession.play_ui_click()
	_refresh()


func _select_color(index: int) -> void:
	_color_index = clampi(index, 0, CharacterLibrary.PALETTE_HEX.size() - 1)
	GameSession.play_ui_click()
	_refresh()


func _save() -> void:
	GameSession.character_index = _character_index
	GameSession.outfit_index = _color_index
	GameSession.save_profile()
	GameSession.change_scene("res://scenes/main_menu.tscn")


func _t(key: String) -> String:
	return TextCatalog.text(key, GameSession.language)
