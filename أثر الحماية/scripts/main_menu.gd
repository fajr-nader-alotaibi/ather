extends Control
## Atmospheric start screen, profile settings, character palette, and direct-IP co-op lobby.

const PALETTE := [
	Color("79c4a0"), Color("7fb6e8"), Color("d49be2"),
	Color("e88fa0"), Color("efbd69"), Color("d4df86")
]
const OUTFIT_FILES := [
	"res://assets/outfits/explorer_0.svg", "res://assets/outfits/explorer_1.svg",
	"res://assets/outfits/explorer_2.svg", "res://assets/outfits/explorer_3.svg",
	"res://assets/outfits/explorer_4.svg", "res://assets/outfits/explorer_5.svg"
]

var _name_edit: LineEdit
var _address_edit: LineEdit
var _status_label: Label
var _lobby_list: Label
var _online_panel: PanelContainer
var _start_online: Button
var _title: Label
var _subtitle: Label
var _settings_title: Label
var _language_title: Label
var _difficulty_title: Label
var _name_title: Label
var _lobby_title: Label
var _solo_button: Button
var _online_button: Button
var _customize_button: Button
var _host_button: Button
var _join_button: Button
var _back_button: Button
var _arabic_button: Button
var _english_button: Button
var _difficulty_buttons: Array[Button] = []
var _outfit_buttons: Array[Button] = []
var _portrait: TextureRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_screen()
	_refresh_copy()
	GameSession.connection_status_changed.connect(_on_status_changed)
	GameSession.lobby_changed.connect(_refresh_lobby)
	GameSession.game_started.connect(_enter_game)
	_refresh_lobby()


func _build_screen() -> void:
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/hope_forest.svg")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.modulate = Color("b8ded0")
	add_child(backdrop)

	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.075, 0.09, 0.46)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(columns)

	var hero := VBoxContainer.new()
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.size_flags_stretch_ratio = 0.78
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_theme_constant_override("separation", 8)
	columns.add_child(hero)

	var eyebrow := _label("✦  ATHAR  ·  حماة الطبيعة", 17, Color("d4e9cf"))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(eyebrow)
	_title = _label("", 52, Color("fff2d3"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_outline_color", Color("183a37"))
	_title.add_theme_constant_override("outline_size", 4)
	hero.add_child(_title)
	_subtitle = _label("", 19, Color("d1e5d3"))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(_subtitle)

	var portrait_frame := _card()
	portrait_frame.custom_minimum_size = Vector2(280, 330)
	portrait_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var portrait_stack := VBoxContainer.new()
	portrait_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait_stack.add_theme_constant_override("separation", 4)
	portrait_frame.add_child(portrait_stack)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(230, 270)
	_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_stack.add_child(_portrait)
	var portrait_note := _label("❋   حارسة الغابة   ❋", 16, Color("f1d59d"))
	portrait_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_stack.add_child(portrait_note)
	hero.add_child(portrait_frame)
	var promise := _label("", 17, Color("f3efd8"))
	promise.name = "Promise"
	promise.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	promise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero.add_child(promise)

	var settings_card := _card()
	settings_card.custom_minimum_size = Vector2(560, 0)
	settings_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_card.size_flags_stretch_ratio = 1.0
	columns.add_child(settings_card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 13)
	settings_card.add_child(content)

	_settings_title = _label("", 27, Color("f4d48e"))
	content.add_child(_settings_title)
	_name_title = _label("", 15, Color("d0e5d0"))
	content.add_child(_name_title)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.y = 42
	_name_edit.max_length = 18
	_name_edit.text = GameSession.player_name
	_style_line_edit(_name_edit)
	_name_edit.text_submitted.connect(_save_name)
	_name_edit.focus_exited.connect(func() -> void: _save_name(_name_edit.text))
	content.add_child(_name_edit)

	_language_title = _label("", 15, Color("d0e5d0"))
	content.add_child(_language_title)
	var language_row := HBoxContainer.new()
	language_row.add_theme_constant_override("separation", 10)
	content.add_child(language_row)
	_arabic_button = _button("", false)
	_arabic_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arabic_button.pressed.connect(_select_language.bind("ar"))
	language_row.add_child(_arabic_button)
	_english_button = _button("", false)
	_english_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_english_button.pressed.connect(_select_language.bind("en"))
	language_row.add_child(_english_button)

	_difficulty_title = _label("", 15, Color("d0e5d0"))
	content.add_child(_difficulty_title)
	var difficulty_row := HBoxContainer.new()
	difficulty_row.add_theme_constant_override("separation", 8)
	content.add_child(difficulty_row)
	for value in ["easy", "normal", "hard"]:
		var difficulty_button := _button("", false)
		difficulty_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		difficulty_button.pressed.connect(_select_difficulty.bind(value))
		_difficulty_buttons.append(difficulty_button)
		difficulty_row.add_child(difficulty_button)

	var outfit_title := _label("", 15, Color("d0e5d0"))
	outfit_title.name = "OutfitTitle"
	content.add_child(outfit_title)
	var outfit_row := HBoxContainer.new()
	outfit_row.add_theme_constant_override("separation", 10)
	content.add_child(outfit_row)
	for index in range(PALETTE.size()):
		var color_button := Button.new()
		color_button.custom_minimum_size = Vector2(48, 42)
		color_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		color_button.tooltip_text = _localized(["نعناعي", "سماوي", "بنفسجي", "وردي", "ذهبي", "ورقي"][index], ["Mint", "Sky", "Violet", "Rose", "Amber", "Leaf"][index])
		_style_swatch(color_button, PALETTE[index], index == GameSession.outfit_index)
		color_button.pressed.connect(_select_outfit.bind(index))
		_outfit_buttons.append(color_button)
		outfit_row.add_child(color_button)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	_solo_button = _button("", true)
	_solo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_solo_button.pressed.connect(_start_solo)
	actions.add_child(_solo_button)
	_online_button = _button("", false)
	_online_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_online_button.pressed.connect(_show_lobby)
	actions.add_child(_online_button)
	_customize_button = _button("", false)
	_customize_button.pressed.connect(_focus_palette)
	content.add_child(_customize_button)

	_online_panel = _card()
	_online_panel.custom_minimum_size.y = 205
	_online_panel.visible = false
	content.add_child(_online_panel)
	var lobby_content := VBoxContainer.new()
	lobby_content.add_theme_constant_override("separation", 8)
	_online_panel.add_child(lobby_content)
	_lobby_title = _label("", 19, Color("f4d48e"))
	lobby_content.add_child(_lobby_title)
	var address_row := HBoxContainer.new()
	address_row.add_theme_constant_override("separation", 8)
	lobby_content.add_child(address_row)
	_address_edit = LineEdit.new()
	_address_edit.placeholder_text = "127.0.0.1"
	_address_edit.text = "127.0.0.1"
	_address_edit.custom_minimum_size.y = 40
	_address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(_address_edit)
	address_row.add_child(_address_edit)
	_host_button = _button("", false)
	_host_button.pressed.connect(_host_room)
	address_row.add_child(_host_button)
	_join_button = _button("", false)
	_join_button.pressed.connect(_join_room)
	address_row.add_child(_join_button)
	_status_label = _label("", 14, Color("d8e8d4"))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_content.add_child(_status_label)
	_lobby_list = _label("", 14, Color("d8e8d4"))
	_lobby_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_content.add_child(_lobby_list)
	_start_online = _button("", true)
	_start_online.visible = false
	_start_online.pressed.connect(GameSession.host_start_game)
	lobby_content.add_child(_start_online)
	_back_button = _button("", false)
	_back_button.pressed.connect(_close_lobby)
	lobby_content.add_child(_back_button)


func _card() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.13, 0.14, 0.90)
	style.border_color = Color("77aa87")
	style.set_border_width_all(2)
	style.set_corner_radius_all(28)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(value: String, size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_outline_color", Color("193735"))
	result.add_theme_constant_override("outline_size", 1)
	result.text_direction = Control.TEXT_DIRECTION_AUTO
	return result


func _button(value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 46
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("fff5dc"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("f4d48e"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("47775e") if primary else Color("244c4c")
	normal.border_color = Color("b5d889") if primary else Color("6d9d7c")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(16)
	normal.set_content_margin_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("5d936d") if primary else Color("32685d")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _style_line_edit(edit: LineEdit) -> void:
	edit.add_theme_font_size_override("font_size", 16)
	edit.add_theme_color_override("font_color", Color("fff4dc"))
	edit.add_theme_color_override("font_placeholder_color", Color("b4c7b5"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102c31")
	style.border_color = Color("648b72")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	edit.add_theme_stylebox_override("normal", style)
	edit.add_theme_stylebox_override("focus", style)


func _style_swatch(button: Button, color: Color, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_color = Color("fff1c7") if selected else Color("385446")
	normal.set_border_width_all(3 if selected else 2)
	normal.set_corner_radius_all(13)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)


func _localized(arabic: String, english: String) -> String:
	return arabic if GameSession.language == "ar" else english


func _refresh_copy() -> void:
	var ar := GameSession.language == "ar"
	_title.text = "أثر الحماية" if ar else "Guardians of Nature"
	_subtitle.text = "رحلة تعيد النور إلى غابة الأمل" if ar else "A little light can bring a forest back."
	_settings_title.text = "جهّزي رحلتك" if ar else "Prepare your journey"
	_name_title.text = "اسم الحارس" if ar else "Guardian name"
	_language_title.text = "اللغة" if ar else "Language"
	_difficulty_title.text = "مستوى التحدي" if ar else "Difficulty"
	_arabic_button.text = "العربية"
	_english_button.text = "English"
	_difficulty_buttons[0].text = "هادئ" if ar else "Gentle"
	_difficulty_buttons[1].text = "متوازن" if ar else "Balanced"
	_difficulty_buttons[2].text = "تحدي" if ar else "Brave"
	_solo_button.text = "ابدئي الرحلة" if ar else "Start journey"
	_online_button.text = "مع الأصدقاء" if ar else "Play together"
	_customize_button.text = "اختيار لون الزي  ·  ستة ألوان" if ar else "Choose outfit color  ·  6 palettes"
	_lobby_title.text = "تعاون مباشر · حتى ٤ لاعبين" if ar else "Direct co-op · up to 4 players"
	_host_button.text = "استضافة" if ar else "Host"
	_join_button.text = "انضمام" if ar else "Join"
	_back_button.text = "إغلاق" if ar else "Close"
	_start_online.text = "ابدأ اللعب الجماعي" if ar else "Start co-op"
	var outfit_label := find_child("OutfitTitle", true, false) as Label
	if is_instance_valid(outfit_label):
		outfit_label.text = "لون زي الحارس" if ar else "Guardian outfit"
	var promise := find_child("Promise", true, false) as Label
	if is_instance_valid(promise):
		promise.text = "اجمعي البذور، أيقظي الجسر، واتركي للغابة أثرًا جديدًا." if ar else "Gather moonseeds, wake the bridge, and leave the forest brighter."
	_arabic_button.disabled = ar
	_english_button.disabled = not ar
	for index in range(_difficulty_buttons.size()):
		_difficulty_buttons[index].disabled = GameSession.difficulty == ["easy", "normal", "hard"][index]
	_update_portrait()
	_refresh_lobby()


func _update_portrait() -> void:
	if is_instance_valid(_portrait):
		_portrait.texture = load(OUTFIT_FILES[clampi(GameSession.outfit_index, 0, OUTFIT_FILES.size() - 1)])
	for index in range(_outfit_buttons.size()):
		_style_swatch(_outfit_buttons[index], PALETTE[index], index == GameSession.outfit_index)


func _select_language(value: String) -> void:
	GameSession.language = value
	GameSession.save_profile()
	_refresh_copy()


func _select_difficulty(value: String) -> void:
	GameSession.difficulty = value
	GameSession.save_profile()
	_refresh_copy()


func _select_outfit(index: int) -> void:
	GameSession.outfit_index = index
	GameSession.save_profile()
	_update_portrait()


func _save_name(value: String) -> void:
	GameSession.set_player_name(value)


func _start_solo() -> void:
	_save_name(_name_edit.text)
	GameSession.start_solo()


func _show_lobby() -> void:
	_save_name(_name_edit.text)
	_online_panel.visible = true
	for child in _online_panel.get_parent().get_children():
		if child != _online_panel:
			child.visible = false
	GameSession.status_message = ""
	_status_label.text = _localized("اختر استضافة أو اكتب عنوان IP للمضيف.", "Host a room or enter the host's IP address.")
	_refresh_lobby()


func _close_lobby() -> void:
	GameSession.leave_lobby()
	_online_panel.visible = false
	for child in _online_panel.get_parent().get_children():
		if child != _online_panel:
			child.visible = true


func _host_room() -> void:
	_save_name(_name_edit.text)
	GameSession.host_lobby()


func _join_room() -> void:
	_save_name(_name_edit.text)
	GameSession.join_lobby(_address_edit.text)


func _refresh_lobby() -> void:
	if not is_instance_valid(_lobby_list):
		return
	var rows: PackedStringArray = []
	var peers: Array = []
	if GameSession.is_networked:
		peers = GameSession.active_peer_ids()
	else:
		peers = GameSession.lobby_names.keys()
	for peer_id in peers:
		if GameSession.lobby_names.has(peer_id):
			rows.append("• " + GameSession.name_for_peer(int(peer_id)))
	_lobby_list.text = "\n".join(rows)
	if not GameSession.status_message.is_empty():
		_status_label.text = GameSession.status_message
	_start_online.visible = GameSession.is_host
	_host_button.disabled = GameSession.is_networked
	_join_button.disabled = GameSession.is_networked


func _on_status_changed(message: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = message
	_refresh_lobby()


func _focus_palette() -> void:
	if not _outfit_buttons.is_empty():
		_outfit_buttons[GameSession.outfit_index].grab_focus()


func _enter_game(_settings: Dictionary) -> void:
	get_tree().change_scene_to_file("res://scenes/hope_forest.tscn")
