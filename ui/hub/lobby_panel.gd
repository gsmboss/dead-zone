class_name LobbyPanel
extends HubWindow
## Окно «ИГРА ПО СЕТИ»: имя, создать игру, найденные игры в сети, подключение к точке
## доступа или по IP; в лобби — игроки, режим, карта и СТАРТ (у хоста).

const HELP: String = "КАК ИГРАТЬ ВМЕСТЕ: ОДИН ТЕЛЕФОН ВКЛЮЧАЕТ ТОЧКУ ДОСТУПА (ИЛИ ВСЕ В ОДНОЙ WI-FI СЕТИ) " \
	+ "И НАЖИМАЕТ «СОЗДАТЬ ИГРУ». ДРУЗЬЯ ПОДКЛЮЧАЮТСЯ К ЕГО СЕТИ И ВЫБИРАЮТ ИГРУ ИЗ СПИСКА, " \
	+ "«К ТОЧКЕ ДОСТУПА» ИЛИ ВВОДЯТ IP ХОСТА. ДО 4 ИГРОКОВ."

var _status: String = ""
var _ip_text: String = ""


func _ready() -> void:
	window_title = "ИГРА ПО СЕТИ"
	Net.lobby_changed.connect(_refresh_soon)
	Net.hosts_changed.connect(_refresh_soon)
	Net.status_changed.connect(_on_status)
	Net.disconnected.connect(_on_status)
	if not Net.is_online():
		Net.start_discovery()
	super._ready()


func _exit_tree() -> void:
	Net.stop_discovery()


func _build_content() -> void:
	if not _status.is_empty():
		UIKit.label(_status, 24, content).modulate = UIKit.ACCENT
	if Net.is_online() or Net.is_host():
		_build_lobby()
	else:
		_build_menu()


# ---------- Не подключены ----------

func _build_menu() -> void:
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override(&"separation", 12)
	content.add_child(name_row)
	UIKit.label("ИМЯ:", 26, name_row)
	var name_edit := _line_edit(Settings.player_name, "ВВЕДИ ИМЯ")
	name_edit.max_length = 16
	name_edit.text_changed.connect(func(text: String) -> void: Settings.set_value(&"player_name", text))
	name_row.add_child(name_edit)

	var host := UIKit.button("СОЗДАТЬ ИГРУ", 30)
	host.custom_minimum_size.y = 92.0
	host.pressed.connect(func() -> void:
		Net.stop_discovery()
		Net.host_game())
	content.add_child(host)

	UIKit.label("НАЙДЕННЫЕ ИГРЫ", 28, content).modulate = UIKit.ACCENT
	if Net.hosts.is_empty():
		UIKit.label("ИЩЕМ ИГРЫ В СЕТИ…", 22, content).modulate = UIKit.DIM
	for address: String in Net.hosts:
		var info: Dictionary = Net.hosts[address]
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 12)
		content.add_child(row)
		var mode_index: int = clampi(int(info["mode"]), 0, Net.MODE_NAMES.size() - 1)
		var label := UIKit.label("%s  •  %d/%d  •  %s" % [info["name"], int(info["players"]), Net.MAX_PLAYERS,
			Net.MODE_NAMES[mode_index]], 24, row)
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		var join := UIKit.button("ВОЙТИ", 24, 200.0)
		join.pressed.connect(func() -> void: Net.join_game(address))
		row.add_child(join)

	var hotspot := UIKit.button("ПОДКЛЮЧИТЬСЯ К ТОЧКЕ ДОСТУПА ДРУГА", 24)
	hotspot.pressed.connect(Net.join_hotspot)
	content.add_child(hotspot)

	var ip_row := HBoxContainer.new()
	ip_row.add_theme_constant_override(&"separation", 12)
	content.add_child(ip_row)
	UIKit.label("IP:", 26, ip_row)
	var ip_edit := _line_edit(_ip_text, "192.168.43.1")
	ip_edit.text_changed.connect(func(text: String) -> void: _ip_text = text)
	ip_row.add_child(ip_edit)
	var join_ip := UIKit.button("ВОЙТИ", 24, 200.0)
	join_ip.pressed.connect(func() -> void: Net.join_game(_ip_text))
	ip_row.add_child(join_ip)

	UIKit.label(HELP, 20, content).modulate = UIKit.DIM


# ---------- Лобби ----------

func _build_lobby() -> void:
	var host: bool = Net.is_host()
	if host:
		var addresses: PackedStringArray = Net.get_local_addresses()
		var ip_line: String = ", ".join(addresses) if not addresses.is_empty() else "НЕТ СЕТИ"
		UIKit.label("IP ХОСТА: %s" % ip_line, 26, content).modulate = UIKit.GOOD

	UIKit.label("ИГРОКИ (%d/%d)" % [Net.players.size(), Net.MAX_PLAYERS], 28, content).modulate = UIKit.ACCENT
	var ids: Array = Net.players.keys()
	ids.sort()
	for peer_id: int in ids:
		var info: Dictionary = Net.players[peer_id]
		var text: String = str(info.get("name", "?"))
		if peer_id == 1:
			text += "  (ХОСТ)"
		if peer_id == Net.my_id():
			text += "  — ТЫ"
		if Net.mode == Net.Mode.TEAMS:
			text += "  • %s" % ("СИНИЕ" if int(info.get("team", 0)) == 0 else "КРАСНЫЕ")
		UIKit.label(text, 24, content)

	if host:
		_choice_row("РЕЖИМ", Net.MODE_NAMES, Net.mode, func(index: int) -> void:
			Net.set_lobby_options(index, Net.map_index))
		UIKit.label(Net.MODE_HINTS[Net.mode], 20, content).modulate = UIKit.DIM
		_choice_row("КАРТА", Net.MAP_NAMES, Net.map_index, func(index: int) -> void:
			Net.set_lobby_options(Net.mode, index))
		var start := UIKit.button("СТАРТ", 34)
		start.custom_minimum_size.y = 92.0
		start.modulate = UIKit.GOOD
		start.pressed.connect(Net.start_match)
		content.add_child(start)
	else:
		UIKit.label("РЕЖИМ: %s  •  КАРТА: %s" % [Net.MODE_NAMES[Net.mode], Net.MAP_NAMES[Net.map_index]], 24, content)
		UIKit.label("ЖДЁМ, КОГДА ХОСТ НАЖМЁТ СТАРТ…", 24, content).modulate = UIKit.DIM

	var leave := UIKit.button("ВЫЙТИ ИЗ ЛОББИ", 24)
	leave.pressed.connect(func() -> void:
		Net.leave()
		Net.start_discovery()
		refresh())
	content.add_child(leave)


func _choice_row(title: String, names: PackedStringArray, current: int, on_pick: Callable) -> void:
	UIKit.label(title, 24, content)
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", 10)
	row.add_theme_constant_override(&"v_separation", 10)
	content.add_child(row)
	for i in names.size():
		var button := UIKit.button(names[i], 22, 160.0)
		button.modulate = UIKit.ACCENT if i == current else Color(1.0, 1.0, 1.0, 0.75)
		button.pressed.connect(func() -> void: on_pick.call(i))
		row.add_child(button)


func _line_edit(text: String, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(360.0, UIKit.BUTTON_HEIGHT)
	edit.size_flags_horizontal = SIZE_EXPAND_FILL
	edit.add_theme_font_size_override(&"font_size", 26)
	return edit


func _on_status(text: String) -> void:
	_status = text
	_refresh_soon()


## Перестроить окно один раз за кадр (сигналы сети приходят пачками)
func _refresh_soon() -> void:
	if not is_inside_tree() or has_meta(&"refresh_queued"):
		return
	set_meta(&"refresh_queued", true)
	await get_tree().process_frame
	if not is_inside_tree():
		return
	remove_meta(&"refresh_queued")
	refresh()
