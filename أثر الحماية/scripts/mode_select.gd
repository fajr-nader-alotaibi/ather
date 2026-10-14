extends Control

const Ui = preload("res://scripts/menu_theme.gd")
const TextCatalog = preload("res://scripts/localization.gd")

var _difficulty: OptionButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Ui.direction(self)
	Ui.install_backdrop(self)
	GameSession.game_started.connect(_on_game_started)
	_build()

func _build() -> void:
	var panel := Ui.card(self, Vector2(620, 440))
	Ui.place(panel, 0.25, 0.18, 0.75, 0.82)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	panel.add_child(stack)
	stack.add_child(Ui.label(_t("mode_title"), 34, Ui.GOLD))
	stack.add_child(Ui.label(_t("mode_subtitle"), 17))
	_difficulty = OptionButton.new()
	_difficulty.add_item(_t("difficulty_easy"))
	_difficulty.set_item_metadata(0, "easy")
	_difficulty.add_item(_t("difficulty_normal"))
	_difficulty.set_item_metadata(1, "normal")
	_difficulty.add_item(_t("difficulty_hard"))
	_difficulty.set_item_metadata(2, "hard")
	_difficulty.item_selected.connect(_on_difficulty_selected)
	stack.add_child(_row(_t("difficulty"), _difficulty))
	_select_difficulty()
	var solo := Ui.button(_t("mode_solo"), true)
	solo.pressed.connect(_start_solo)
	stack.add_child(solo)
	var host := Ui.button(_t("mode_host"))
	host.pressed.connect(func() -> void: GameSession.change_scene("res://scenes/lobby.tscn"))
	stack.add_child(host)
	var join := Ui.button(_t("mode_join"))
	join.pressed.connect(func() -> void: GameSession.change_scene("res://scenes/lobby.tscn"))
	stack.add_child(join)
	var back := Ui.button(_t("back"))
	back.pressed.connect(func() -> void: GameSession.change_scene("res://scenes/main_menu.tscn"))
	stack.add_child(back)

func _row(caption: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label := Ui.label(caption, 17)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	control.custom_minimum_size = Vector2(250, 48)
	row.add_child(control)
	return row

func _select_difficulty() -> void:
	for index in range(_difficulty.item_count):
		if str(_difficulty.get_item_metadata(index)) == GameSession.difficulty:
			_difficulty.select(index)
			return

func _on_difficulty_selected(index: int) -> void:
	GameSession.difficulty = str(_difficulty.get_item_metadata(index))
	GameSession.save_profile()

func _start_solo() -> void:
	GameSession.play_ui_click()
	GameSession.start_solo()

func _on_game_started(_settings: Dictionary) -> void:
	GameSession.change_scene("res://scenes/hope_forest.tscn")

func _t(key: String) -> String:
	return TextCatalog.text(key, GameSession.language)
