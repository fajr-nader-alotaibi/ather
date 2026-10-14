extends Control
## Purpose-built game HUD: quiet night-sky panels, leaf seams, warm seed counters.

const TextCatalog = preload("res://scripts/localization.gd")

signal pause_changed(is_paused: bool)
signal restart_requested
signal main_menu_requested

var language := "ar"
var _seeds := 0
var _restored := false
var _has_won := false
var _is_paused := false
var _hint := ""

var _objective: Label
var _seed_counter: Label
var _hint_label: Label
var _pause_layer: ColorRect
var _win_layer: ColorRect
var _chapter_label: Label
var _seed_title: Label
var _party_label: Label

const NIGHT := Color("172f38")
const NIGHT_SOFT := Color("23464a")
const MINT := Color("9bd7c2")
const GOLD := Color("f3c875")
const CREAM := Color("fff3dc")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	language = GameSession.language
	_build_panels()
	_build_pause_layer()
	_build_touch_controls()
	refresh()


func set_world_state(seed_count: int, restored: bool, has_won: bool, hint: String) -> void:
	_seeds = seed_count
	_restored = restored
	_has_won = has_won
	_hint = hint
	refresh()


func _build_panels() -> void:
	var objective_panel := _panel(Vector2(26, 24), Vector2(450, 126))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	objective_panel.add_child(content)
	var title := _label(_text("title"), 24, GOLD)
	title.add_theme_color_override("font_outline_color", Color("293c3c"))
	content.add_child(title)
	_chapter_label = _label("", 16, MINT)
	content.add_child(_chapter_label)
	_objective = _label("", 17, CREAM)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_objective)

	var seed_panel := _panel(Vector2(0, 24), Vector2(282, 90))
	seed_panel.anchor_left = 1.0
	seed_panel.anchor_right = 1.0
	seed_panel.offset_left = -380.0
	seed_panel.offset_right = -98.0
	var seed_box := VBoxContainer.new()
	seed_box.add_theme_constant_override("separation", 4)
	seed_panel.add_child(seed_box)
	_seed_title = _label("", 15, MINT)
	seed_box.add_child(_seed_title)
	_seed_counter = _label("", 26, GOLD)
	_seed_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_counter.text_direction = Control.TEXT_DIRECTION_LTR
	seed_box.add_child(_seed_counter)
	var party_panel := _panel(Vector2(0, 24), Vector2(260, 70))
	party_panel.anchor_left = 0.5
	party_panel.anchor_right = 0.5
	party_panel.offset_left = -130.0
	party_panel.offset_right = 130.0
	_party_label = _label("", 15, MINT)
	_party_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_party_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	party_panel.add_child(_party_label)

	var pause_button := _button("Ⅱ", Vector2.ZERO, Vector2(62, 58), true)
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.offset_left = -78.0
	pause_button.offset_right = -16.0
	pause_button.offset_top = 28.0
	pause_button.offset_bottom = 86.0
	pause_button.pressed.connect(_on_pause_pressed)

	var hint_panel := _panel(Vector2.ZERO, Vector2(780, 56), true)
	hint_panel.anchor_left = 0.5
	hint_panel.anchor_right = 0.5
	hint_panel.anchor_top = 1.0
	hint_panel.anchor_bottom = 1.0
	hint_panel.offset_left = -390.0
	hint_panel.offset_right = 390.0
	hint_panel.offset_top = -85.0
	hint_panel.offset_bottom = -29.0
	if DisplayServer.is_touchscreen_available():
		hint_panel.position.y = 548.0
	_hint_label = _label("", 17, CREAM)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_panel.add_child(_hint_label)


func _panel(position: Vector2, size: Vector2, subtle := false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = position
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(NIGHT.r, NIGHT.g, NIGHT.b, 0.88 if not subtle else 0.76)
	style.border_color = Color("527b70")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel


func _label(value: String, size: int, color: Color) -> Label:
	var item := Label.new()
	item.text = value
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	item.add_theme_color_override("font_outline_color", Color("18333a"))
	item.add_theme_constant_override("outline_size", 1)
	item.text_direction = Control.TEXT_DIRECTION_AUTO
	return item


func _button(value: String, position: Vector2, size: Vector2, round := false) -> Button:
	var button := Button.new()
	button.text = value
	button.position = position
	button.size = size
	button.add_theme_font_size_override("font_size", 22 if round else 18)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(NIGHT_SOFT.r, NIGHT_SOFT.g, NIGHT_SOFT.b, 0.95)
	normal.border_color = Color("88bba0")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(22 if round else 16)
	normal.set_content_margin_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("38635b")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_child(button)
	return button


func _build_pause_layer() -> void:
	_pause_layer = _overlay()
	_pause_layer.visible = false
	var panel := _center_panel(_pause_layer, Vector2(470, 360))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	panel.add_child(stack)
	var heading := _label("", 30, GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.name = "PauseHeading"
	stack.add_child(heading)
	var body := _label("", 17, CREAM)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.name = "PauseBody"
	stack.add_child(body)
	var resume := _button_inside("", stack, 58)
	resume.name = "Resume"
	resume.pressed.connect(_resume)
	var restart := _button_inside("", stack, 58)
	restart.name = "Restart"
	restart.pressed.connect(func() -> void:
		restart_requested.emit()
	)
	var pause_menu := _button_inside("", stack, 48)
	pause_menu.name = "PauseMenu"
	pause_menu.pressed.connect(func() -> void:
		main_menu_requested.emit()
	)
	_win_layer = _overlay()
	_win_layer.visible = false
	var win_panel := _center_panel(_win_layer, Vector2(500, 350))
	var win_stack := VBoxContainer.new()
	win_stack.add_theme_constant_override("separation", 17)
	win_panel.add_child(win_stack)
	var win_title := _label("", 30, GOLD)
	win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_title.name = "WinTitle"
	win_stack.add_child(win_title)
	var win_body := _label("", 18, CREAM)
	win_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win_body.name = "WinBody"
	win_stack.add_child(win_body)
	var again := _button_inside("", win_stack, 58)
	again.name = "PlayAgain"
	again.pressed.connect(func() -> void:
		restart_requested.emit()
	)
	var win_menu := _button_inside("", win_stack, 48)
	win_menu.name = "WinMenu"
	win_menu.pressed.connect(func() -> void:
		main_menu_requested.emit()
	)
	refresh()


func _overlay() -> ColorRect:
	var overlay := ColorRect.new()
	var overlay_color := Color("0b1a22")
	overlay_color.a = 0.78
	overlay.color = overlay_color
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	return overlay


func _center_panel(parent: Control, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size = size
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -size.x * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_bottom = size.y * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.102, 0.208, 0.243, 0.98)
	style.border_color = Color("96c6a6")
	style.set_border_width_all(3)
	style.set_corner_radius_all(30)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _button_inside(value: String, parent: Control, height: float) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", CREAM)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("315c59")
	style.border_color = Color("9cc997")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	parent.add_child(button)
	return button


func _build_touch_controls() -> void:
	if not DisplayServer.is_touchscreen_available():
		return
	_touch_button("‹", "move_left", Vector2(0, 1), Vector2(40, -150), Vector2(88, 88))
	_touch_button("›", "move_right", Vector2(0, 1), Vector2(138, -150), Vector2(88, 88))
	_touch_button(_text("jump"), "jump", Vector2(1, 1), Vector2(-194, -158), Vector2(142, 96))
	_touch_button(_text("use"), "interact", Vector2(1, 1), Vector2(-322, -138), Vector2(108, 78))


func _touch_button(value: String, action: String, anchor: Vector2, offset: Vector2, size: Vector2) -> void:
	var button := _button(value, Vector2.ZERO, size, true)
	button.anchor_left = anchor.x
	button.anchor_right = anchor.x
	button.anchor_top = anchor.y
	button.anchor_bottom = anchor.y
	button.offset_left = offset.x
	button.offset_top = offset.y
	button.offset_right = offset.x + size.x
	button.offset_bottom = offset.y + size.y
	button.add_theme_font_size_override("font_size", 18)
	button.button_down.connect(_press_action.bind(action))
	button.button_up.connect(_release_action.bind(action))
	button.mouse_exited.connect(_release_action.bind(action))


func _press_action(action: String) -> void:
	Input.action_press(action)


func _release_action(action: String) -> void:
	Input.action_release(action)


func _on_pause_pressed() -> void:
	_is_paused = not _is_paused
	_pause_layer.visible = _is_paused
	pause_changed.emit(_is_paused)
	refresh()


func _resume() -> void:
	_is_paused = false
	_pause_layer.visible = false
	pause_changed.emit(false)


func _show_win() -> void:
	_win_layer.visible = true
	_pause_layer.visible = false
	_is_paused = true
	pause_changed.emit(true)
	refresh()



func _text(key: String) -> String:
	return TextCatalog.text(key, language)


func refresh() -> void:
	if not is_instance_valid(_objective):
		return
	_chapter_label.text = _text("chapter")
	_objective.text = _text("objective") if not _restored else _text("objective_restored")
	_seed_title.text = _text("seeds")
	_seed_counter.text = "%d / 3   ✦" % _seeds
	_party_label.text = _text("solo") if not GameSession.is_networked else "%s  ·  %d/4" % [_text("team"), GameSession.active_peer_ids().size()]
	_hint_label.text = _hint
	var pause_heading := _pause_layer.find_child("PauseHeading", true, false) as Label
	var pause_body := _pause_layer.find_child("PauseBody", true, false) as Label
	var resume_button := _pause_layer.find_child("Resume", true, false) as Button
	var restart_button := _pause_layer.find_child("Restart", true, false) as Button
	if is_instance_valid(pause_heading):
		pause_heading.text = _text("pause_title")
		pause_body.text = _text("pause_body")
		resume_button.text = _text("resume")
		restart_button.text = _text("restart")
		var pause_menu := _pause_layer.find_child("PauseMenu", true, false) as Button
		if is_instance_valid(pause_menu):
			pause_menu.text = _text("main_menu")
	var win_title := _win_layer.find_child("WinTitle", true, false) as Label
	var win_body := _win_layer.find_child("WinBody", true, false) as Label
	if is_instance_valid(win_title):
		win_title.text = _text("win_title")
		win_body.text = _text("win_body")
		var again := _win_layer.find_child("PlayAgain", true, false) as Button
		if is_instance_valid(again):
			again.text = _text("play_again")
			var win_menu := _win_layer.find_child("WinMenu", true, false) as Button
			if is_instance_valid(win_menu):
				win_menu.text = _text("main_menu")
