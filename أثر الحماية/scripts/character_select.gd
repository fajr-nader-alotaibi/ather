extends Control

const Ui = preload("res://scripts/menu_theme.gd")
const TextCatalog = preload("res://scripts/localization.gd")

var _index := 0
var _preview: TextureRect
var _name_label: Label

func _ready() -> void:
	Ui.direction(self)
	Ui.install_backdrop(self)
	_index = clampi(GameSession.outfit_index, 0, 5)
	_build()
	_refresh()

func _build() -> void:
	var panel := Ui.card(self, Vector2(760, 520))
	Ui.place(panel, 0.20, 0.12, 0.80, 0.88)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	panel.add_child(stack)
	stack.add_child(Ui.label(_t("character_title"), 34, Ui.GOLD))
	_name_label = Ui.label(_t("character_description"), 17)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_name_label)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(280, 250)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_preview)
	var colors := HBoxContainer.new()
	colors.alignment = BoxContainer.ALIGNMENT_CENTER
	colors.add_theme_constant_override("separation", 10)
	for index in range(6):
		var swatch := Button.new()
		swatch.text = str(index + 1)
		swatch.custom_minimum_size = Vector2(58, 48)
		swatch.add_theme_font_size_override("font_size", 17)
		var style := StyleBoxFlat.new()
		style.bg_color = [Color("bf3a2b"), Color("e5a238"), Color("6eaa79"), Color("687fbb"), Color("a277ad"), Color("d9828a")][index]
		style.set_corner_radius_all(18)
		style.set_border_width_all(2)
		style.border_color = Color("fff2cb")
		swatch.add_theme_stylebox_override("normal", style)
		swatch.pressed.connect(_set_index.bind(index))
		colors.add_child(swatch)
	stack.add_child(colors)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	var back := Ui.button(_t("back"))
	back.pressed.connect(func() -> void: GameSession.change_scene("res://scenes/main_menu.tscn"))
	buttons.add_child(back)
	var confirm := Ui.button(_t("character_save"), true)
	confirm.pressed.connect(_save)
	buttons.add_child(confirm)
	stack.add_child(buttons)

func _refresh() -> void:
	_preview.texture = load("res://assets/outfits/explorer_%d.svg" % _index)
	_name_label.text = "%s  ·  %d/6" % [_t("character_description"), _index + 1]

func _set_index(value: int) -> void:
	_index = clampi(value, 0, 5)
	GameSession.play_ui_click()
	_refresh()

func _save() -> void:
	GameSession.outfit_index = _index
	GameSession.save_profile()
	GameSession.change_scene("res://scenes/main_menu.tscn")

func _t(key: String) -> String:
	return TextCatalog.text(key, GameSession.language)
