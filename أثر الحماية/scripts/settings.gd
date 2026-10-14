extends Control

const Ui = preload("res://scripts/menu_theme.gd")
const TextCatalog = preload("res://scripts/localization.gd")

var _status: Label

func _ready() -> void:
	Ui.direction(self)
	Ui.install_backdrop(self)
	_build()

func _build() -> void:
	var panel := Ui.card(self, Vector2(760, 600))
	Ui.place(panel, 0.18, 0.08, 0.82, 0.92)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	panel.add_child(stack)
	stack.add_child(Ui.label(_t("settings_title"), 31, Ui.GOLD))
	stack.add_child(Ui.label(_t("audio"), 18, Ui.GOLD))
	stack.add_child(_volume_row("music", GameSession.music_volume, func(value: float) -> void: GameSession.music_volume = value))
	stack.add_child(_volume_row("sfx", GameSession.sfx_volume, func(value: float) -> void: GameSession.sfx_volume = value))
	stack.add_child(_volume_row("ui_volume", GameSession.ui_volume, func(value: float) -> void: GameSession.ui_volume = value))
	var audio_buttons := HBoxContainer.new()
	var mute := Ui.button(_t("mute") if not GameSession.muted else _t("unmute"))
	mute.pressed.connect(func() -> void:
		GameSession.muted = not GameSession.muted
		GameSession.apply_audio_settings()
		GameSession.save_profile()
		mute.text = _t("mute") if not GameSession.muted else _t("unmute")
	)
	audio_buttons.add_child(mute)
	var language := Ui.button(_t("language") + "  ·  " + ("العربية" if GameSession.language == "ar" else "English"))
	language.pressed.connect(func() -> void:
		GameSession.language = "en" if GameSession.language == "ar" else "ar"
		GameSession.save_profile()
		GameSession.change_scene("res://scenes/settings.tscn")
	)
	audio_buttons.add_child(language)
	stack.add_child(audio_buttons)
	stack.add_child(Ui.label(_t("graphics"), 18, Ui.GOLD))
	var quality := OptionButton.new()
	quality.add_item(_t("quality_low"))
	quality.set_item_metadata(0, "low")
	quality.add_item(_t("quality_balanced"))
	quality.set_item_metadata(1, "balanced")
	quality.add_item(_t("quality_high"))
	quality.set_item_metadata(2, "high")
	quality.item_selected.connect(func(index: int) -> void:
		GameSession.graphics_quality = str(quality.get_item_metadata(index))
		GameSession.apply_audio_settings()
		GameSession.save_profile()
	)
	for index in range(quality.item_count):
		if str(quality.get_item_metadata(index)) == GameSession.graphics_quality:
			quality.select(index)
	stack.add_child(quality)
	stack.add_child(Ui.label(_t("controls_title") + ":  A / D أو الأسهم · Space · E / F · Esc", 15))
	stack.add_child(Ui.label(_t("touch_info"), 14))
	_status = Ui.label(_t("settings_saved"), 14)
	stack.add_child(_status)
	var buttons := HBoxContainer.new()
	var reset := Ui.button(_t("reset_settings"))
	reset.pressed.connect(func() -> void:
		GameSession.restore_defaults()
		GameSession.change_scene("res://scenes/settings.tscn")
	)
	buttons.add_child(reset)
	var back := Ui.button(_t("back"))
	back.pressed.connect(func() -> void: GameSession.change_scene("res://scenes/main_menu.tscn"))
	buttons.add_child(back)
	stack.add_child(buttons)

func _volume_row(key: String, initial: float, setter: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Ui.label(_t(key), 15)
	label.custom_minimum_size.x = 145
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float) -> void:
		setter.call(value)
		GameSession.apply_audio_settings()
		GameSession.save_profile()
	)
	row.add_child(slider)
	return row

func _t(key: String) -> String:
	return TextCatalog.text(key, GameSession.language)
