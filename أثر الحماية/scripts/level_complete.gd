extends Control

const Ui = preload("res://scripts/menu_theme.gd")
const TextCatalog = preload("res://scripts/localization.gd")

func _ready() -> void:
	Ui.direction(self)
	Ui.install_backdrop(self)
	GameSession.restart_requested.connect(_restart_to_stage)
	_build()

func _build() -> void:
	var panel := Ui.card(self, Vector2(700, 520))
	Ui.place(panel, 0.23, 0.14, 0.77, 0.86)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	panel.add_child(stack)
	stack.add_child(Ui.label(_t("complete_title"), 34, Ui.GOLD))
	var story := Ui.label(_t("complete_body"), 18)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(story)
	var result := GameSession.run_result
	stack.add_child(Ui.label("%s: %s / 3" % [_t("stat_seeds"), str(result.get("seeds_collected", 0))], 18))
	stack.add_child(Ui.label("%s: %s" % [_t("stat_animals"), str(result.get("animals_rescued", 0))], 16))
	stack.add_child(Ui.label("%s: %s" % [_t("stat_puzzles"), str(result.get("puzzles_solved", 0))], 16))
	var next_note := Ui.label(_t("no_next_stage"), 15, Color("e1c8a0"))
	stack.add_child(next_note)
	var again := Ui.button(_t("play_again"), true)
	again.pressed.connect(GameSession.request_restart)
	stack.add_child(again)
	var menu := Ui.button(_t("main_menu"))
	menu.pressed.connect(func() -> void:
		GameSession.leave_lobby()
		GameSession.change_scene("res://scenes/main_menu.tscn")
	)
	stack.add_child(menu)

func _restart_to_stage() -> void:
	GameSession.change_scene("res://scenes/hope_forest.tscn")

func _t(key: String) -> String:
	return TextCatalog.text(key, GameSession.language)
