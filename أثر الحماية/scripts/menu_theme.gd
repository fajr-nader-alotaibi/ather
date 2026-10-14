extends RefCounted

const CREAM := Color("fff4d7")
const GOLD := Color("f4d58a")

static func install_backdrop(root: Control) -> void:
	var background := TextureRect.new()
	background.texture = load("res://assets/menu_world.svg")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var particles := Control.new()
	particles.set_script(load("res://scripts/menu_ambience.gd"))
	particles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(particles)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.12, 0.15, 0.16)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

static func label(value: String, font_size := 20, color := CREAM) -> Label:
	var item := Label.new()
	item.text = value
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.add_theme_color_override("font_outline_color", Color("173839"))
	item.add_theme_constant_override("outline_size", 2)
	item.text_direction = Control.TEXT_DIRECTION_AUTO
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return item

static func button(value: String, primary := false) -> Button:
	var item := Button.new()
	item.text = value
	item.custom_minimum_size = Vector2(0, 56)
	item.add_theme_font_size_override("font_size", 19)
	item.add_theme_color_override("font_color", CREAM)
	item.add_theme_color_override("font_hover_color", Color.WHITE)
	item.add_theme_color_override("font_pressed_color", GOLD)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("3f8145") if primary else Color("164f55")
	normal.bg_color.a = 0.95
	normal.border_color = Color("c4df7f") if primary else Color("8dcab7")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(22)
	normal.set_content_margin_all(9)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("579c50") if primary else Color("217078")
	item.add_theme_stylebox_override("normal", normal)
	item.add_theme_stylebox_override("hover", hover)
	item.add_theme_stylebox_override("pressed", hover)
	item.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	item.pressed.connect(GameSession.play_ui_click)
	return item

static func card(parent: Control, min_size := Vector2.ZERO) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.16, 0.18, 0.90)
	style.border_color = Color("9ecb9e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(26)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

static func style_edit(edit: LineEdit) -> void:
	edit.add_theme_font_size_override("font_size", 17)
	edit.add_theme_color_override("font_color", CREAM)
	edit.add_theme_color_override("font_placeholder_color", Color("acc9b4"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0a2f36")
	style.border_color = Color("79b89f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	edit.add_theme_stylebox_override("normal", style)
	edit.add_theme_stylebox_override("focus", style)

static func direction(root: Control) -> void:
	root.layout_direction = Control.LAYOUT_DIRECTION_RTL if GameSession.language == "ar" else Control.LAYOUT_DIRECTION_LTR

static func place(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
