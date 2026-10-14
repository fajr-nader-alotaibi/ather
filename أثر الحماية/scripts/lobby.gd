extends Control

const Ui = preload("res://scripts/menu_theme.gd")
const TextCatalog = preload("res://scripts/localization.gd")

var _ip: LineEdit
var _status: Label
var _players: Label
var _start: Button
var _difficulty: OptionButton

func _ready() -> void:
	Ui.direction(self)
	Ui.install_backdrop(self)
	GameSession.lobby_changed.connect(_refresh)
	GameSession.connection_status_changed.connect(_on_status)
	GameSession.game_started.connect(_on_game_started)
	_build()
	_refresh()

func _build() -> void:
	var panel := Ui.card(self, Vector2(760, 590))
	Ui.place(panel, 0.18, 0.07, 0.82, 0.93)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)
	stack.add_child(Ui.label(_t("lobby_title"), 32, Ui.GOLD))
	var note := Ui.label(_t("lobby_note"), 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(note)
	var network := HBoxContainer.new()
	var host := Ui.button(_t("host"), true)
	host.pressed.connect(_host)
	network.add_child(host)
	_ip = LineEdit.new()
	_ip.placeholder_text = _t("ip_address")
	_ip.text = GameSession.local_ip_address()
	Ui.style_edit(_ip)
	_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	network.add_child(_ip)
	var join := Ui.button(_t("join"))
	join.pressed.connect(_join)
	network.add_child(join)
	stack.add_child(network)
	var room := HBoxContainer.new()
	var copy := Ui.button(_t("copy_invite"))
	copy.pressed.connect(_copy_address)
	room.add_child(copy)
	_difficulty = OptionButton.new()
	for pair in [[_t("difficulty_easy"), "easy"], [_t("difficulty_normal"), "normal"], [_t("difficulty_hard"), "hard"]]:
		_difficulty.add_item(str(pair[0]))
		_difficulty.set_item_metadata(_difficulty.item_count - 1, pair[1])
	for index in range(_difficulty.item_count):
		if str(_difficulty.get_item_metadata(index)) == GameSession.difficulty:
			_difficulty.select(index)
	_difficulty.item_selected.connect(_difficulty_changed)
	room.add_child(_difficulty)
	stack.add_child(room)
	_players = Ui.label("", 18)
	_players.custom_minimum_size.y = 90
	stack.add_child(_players)
	_status = Ui.label("", 15, Color("f6dfaa"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_status)
	var bottom := HBoxContainer.new()
	_start = Ui.button(_t("start_online"), true)
	_start.pressed.connect(GameSession.host_start_game)
	bottom.add_child(_start)
	var leave := Ui.button(_t("leave_room"))
	leave.pressed.connect(_leave)
	bottom.add_child(leave)
	stack.add_child(bottom)

func _host() -> void:
	var result := GameSession.host_lobby()
	if result == OK:
		_refresh()

func _join() -> void:
	var parts := _ip.text.strip_edges().split(":")
	var host := str(parts[0]).strip_edges()
	var port := GameSession.DEFAULT_PORT
	if parts.size() > 1:
		port = clampi(int(parts[1]), 1, 65535)
	GameSession.join_lobby(host, port)
	_refresh()

func _copy_address() -> void:
	DisplayServer.clipboard_set("%s:%d" % [GameSession.local_ip_address(), GameSession.DEFAULT_PORT])
	GameSession.status_message = _t("copy_done")
	_refresh()

func _difficulty_changed(index: int) -> void:
	GameSession.difficulty = str(_difficulty.get_item_metadata(index))
	GameSession.save_profile()

func _refresh() -> void:
	if not is_instance_valid(_players):
		return
	var rows: Array[String] = []
	var ids: Array = GameSession.lobby_names.keys()
	ids.sort()
	for peer_id in ids:
		rows.append("•  %s" % str(GameSession.lobby_names[peer_id]))
	_players.text = _t("players") + "\n" + ("\n".join(rows) if not rows.is_empty() else _t("connection_waiting"))
	_status.text = GameSession.status_message
	_start.disabled = not GameSession.is_host

func _on_status(message: String) -> void:
	if is_instance_valid(_status):
		_status.text = message

func _on_game_started(_settings: Dictionary) -> void:
	GameSession.change_scene("res://scenes/hope_forest.tscn")

func _leave() -> void:
	GameSession.leave_lobby()
	GameSession.change_scene("res://scenes/main_menu.tscn")

func _t(key: String) -> String:
	return TextCatalog.text(key, GameSession.language)
