extends Node
## Автозагрузка "Net": игра с друзьями по Wi-Fi или точке доступа телефона (ENet, до 4 игроков).
## Хост создаёт игру и рассылает о ней UDP-объявления в локальной сети; клиенты видят список
## игр, подключаются по найденному адресу, к точке доступа (шлюз x.x.x.1) или по IP вручную.
## Лобби: игроки, режим, карта; хост жмёт СТАРТ — все загружают уровень, где матч ведёт
## MatchManager. Все RPC — здесь (путь /root/Net одинаков у всех), матчу они передаются дальше.

signal lobby_changed
signal hosts_changed
signal status_changed(text: String)
signal disconnected(reason: String)

enum Mode { AUTO, COOP_SCORE, FREE_FOR_ALL, TEAMS, LAST_STANDING }
const MODE_NAMES: PackedStringArray = ["АВТО", "КТО БОЛЬШЕ УБЬЁТ", "КАЖДЫЙ САМ ЗА СЕБЯ", "КОМАНДЫ",
	"ПОСЛЕДНИЙ ЖИВОЙ"]
const MODE_HINTS: PackedStringArray = [
	"2 ИГРОКА — ДУЭЛЬ, 3 — КАЖДЫЙ САМ ЗА СЕБЯ, 4 — КОМАНДЫ 2×2",
	"ВМЕСТЕ ПРОТИВ ЗОМБИ, ОЧКИ ЗА КАЖДОГО УБИТОГО",
	"PVP: СТРЕЛЯЙТЕ ДРУГ В ДРУГА, ЗОМБИ МЕШАЮТ ВСЕМ",
	"PVP КОМАНДА НА КОМАНДУ, СВОИХ РАНИТЬ НЕЛЬЗЯ",
	"ВОЛНЫ ВСЁ СИЛЬНЕЕ, БЕЗ ВОЗРОЖДЕНИЯ — ПОБЕЖДАЕТ ПОСЛЕДНИЙ ЖИВОЙ",
]
const MAPS: Array[String] = ["res://levels/yard_level.tscn", "res://levels/street_level.tscn",
	"res://levels/graveyard_level.tscn", "res://levels/test_level.tscn", "res://levels/city_level.tscn"]
const MAP_NAMES: PackedStringArray = ["СТОЯНКА", "УЛИЦА", "КЛАДБИЩЕ", "ПОЛИГОН", "ГОРОД"]
const HUB_SCENE: String = "res://hub/hub.tscn"

const PORT: int = 24680
const DISCOVERY_PORT: int = 24681
const MAX_PLAYERS: int = 4
## Версия протокола: разные версии игры не соединяются
const PROTOCOL: int = 4
const DISCOVERY_TAG: String = "DEADZONE"
const ANNOUNCE_INTERVAL: float = 1.0
## Игра пропадает из списка, если о ней не слышно столько секунд
const HOST_TIMEOUT: float = 4.0
const CONNECT_TIMEOUT: float = 6.0
## Сколько ENet ждёт ответа соседа, мс: телефон на загрузке карты молчит несколько секунд,
## по умолчанию (~5 с) соединение рвалось прямо на старте матча
const PEER_TIMEOUT_MIN: int = 30000
const PEER_TIMEOUT_MAX: int = 60000

## peer_id -> {"name": String, "skin": String, "team": int, "loaded": bool}
var players: Dictionary = {}
## Выбранный в лобби режим (AUTO решается при старте) и итоговый режим матча
var mode: int = Mode.AUTO
var match_mode: int = Mode.COOP_SCORE
var map_index: int = 0
var in_match: bool = false
## Найденные игры: ip -> {"name": String, "players": int, "mode": int, "seen": float}
var hosts: Dictionary = {}
## Текущий матч (ставит себя сам)
var match_manager: Node
## Старт матча пришёл раньше, чем загрузился уровень (MatchManager заберёт при появлении); <0 — нет
var pending_go: float = -1.0

var _peer: ENetMultiplayerPeer
var _announcer: PacketPeerUDP
var _listener: PacketPeerUDP
var _announce_timer: float = 0.0
var _time: float = 0.0
var _connect_left: float = 0.0
var _host_address: String = ""
# Фоновая загрузка карты матча (соединение продолжает работать, экран не «замерзает»)
var _loading_path: String = ""
var _loading_progress: Array = []
var _loading_layer: CanvasLayer
var _loading_bar: ProgressBar


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# ---------- Состояние ----------

func is_online() -> bool:
	return _peer != null and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_host() -> bool:
	return _peer != null and multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if _peer != null else 1


func get_player_name(peer_id: int) -> String:
	return str((players.get(peer_id, {}) as Dictionary).get("name", "ИГРОК %d" % peer_id))


func get_team(peer_id: int) -> int:
	return int((players.get(peer_id, {}) as Dictionary).get("team", 0))


## Адреса этого устройства в локальной сети (для подсказки «IP ХОСТА»)
func get_local_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for address: String in IP.get_local_addresses():
		if _is_private_ipv4(address):
			result.append(address)
	return result


## Можно ли ранить игрока peer_id в текущем режиме
func is_enemy(peer_id: int) -> bool:
	match match_mode:
		Mode.FREE_FOR_ALL:
			return true
		Mode.TEAMS:
			return get_team(peer_id) != get_team(my_id())
	return false


func mode_allows_respawn(match_type: int) -> bool:
	return match_type != Mode.LAST_STANDING


# ---------- Хост и подключение ----------

func host_game() -> bool:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		_peer = null
		status_changed.emit("НЕ УДАЛОСЬ СОЗДАТЬ ИГРУ (%s)" % error_string(err))
		return false
	multiplayer.multiplayer_peer = _peer
	players.clear()
	players[1] = _my_info()
	players[1]["team"] = 0
	_start_announcer()
	status_changed.emit("ИГРА СОЗДАНА")
	lobby_changed.emit()
	return true


func join_game(address: String) -> void:
	address = address.strip_edges()
	if not address.is_valid_ip_address():
		status_changed.emit("НЕВЕРНЫЙ IP: %s" % address)
		return
	leave()
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_client(address, PORT)
	if err != OK:
		_peer = null
		status_changed.emit("ОШИБКА ПОДКЛЮЧЕНИЯ (%s)" % error_string(err))
		return
	multiplayer.multiplayer_peer = _peer
	_host_address = address
	_connect_left = CONNECT_TIMEOUT
	status_changed.emit("ПОДКЛЮЧЕНИЕ К %s…" % address)


## Подключиться к телефону, раздающему точку доступа: он — шлюз сети (адрес x.x.x.1)
func join_hotspot() -> void:
	for address: String in get_local_addresses():
		var parts: PackedStringArray = address.split(".")
		if parts.size() == 4 and parts[3] != "1":
			join_game("%s.%s.%s.1" % [parts[0], parts[1], parts[2]])
			return
	status_changed.emit("НЕТ СЕТИ: ПОДКЛЮЧИСЬ К ТОЧКЕ ДОСТУПА ДРУГА")


func leave() -> void:
	_stop_announcer()
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	in_match = false
	_connect_left = 0.0
	_loading_path = ""
	hide_loading()
	lobby_changed.emit()


## Хост: сменить режим или карту в лобби
func set_lobby_options(new_mode: int, new_map: int) -> void:
	if not is_host():
		return
	mode = clampi(new_mode, 0, MODE_NAMES.size() - 1)
	map_index = clampi(new_map, 0, MAPS.size() - 1)
	_assign_teams()
	_rpc_lobby.rpc(players, mode, map_index)
	lobby_changed.emit()


## Хост: начать матч у всех
func start_match() -> void:
	if not is_host() or in_match:
		return
	var effective: int = mode
	if effective == Mode.AUTO:
		match players.size():
			1:
				effective = Mode.COOP_SCORE
			2, 3:
				effective = Mode.FREE_FOR_ALL
			_:
				effective = Mode.TEAMS
	match_mode = effective
	_assign_teams()
	for peer_id: int in players:
		players[peer_id]["loaded"] = false
	_rpc_begin_match.rpc(players, effective, map_index)


## Вернуться в убежище после матча (соединение и лобби сохраняются)
func return_to_lobby() -> void:
	in_match = false
	match_manager = null
	get_tree().paused = false
	get_tree().change_scene_to_file(HUB_SCENE)


# ---------- Поиск игр в сети ----------

func start_discovery() -> void:
	if _listener != null:
		return
	_listener = PacketPeerUDP.new()
	var err: Error = _listener.bind(DISCOVERY_PORT)
	if err != OK:
		push_warning("Net: не удалось слушать порт поиска %d: %s" % [DISCOVERY_PORT, error_string(err)])
		_listener = null


func stop_discovery() -> void:
	if _listener != null:
		_listener.close()
	_listener = null
	hosts.clear()


func _start_announcer() -> void:
	_announcer = PacketPeerUDP.new()
	_announcer.set_broadcast_enabled(true)
	_announce_timer = 0.0


func _stop_announcer() -> void:
	if _announcer != null:
		_announcer.close()
	_announcer = null


func _process(delta: float) -> void:
	_time += delta
	if not _loading_path.is_empty():
		_poll_map_loading()
	if _connect_left > 0.0:
		_connect_left -= delta
		if _connect_left <= 0.0 and not is_online():
			status_changed.emit("ХОСТ НЕ ОТВЕЧАЕТ — ПРОВЕРЬ IP И ЧТО ВЫ В ОДНОЙ СЕТИ")
			leave()
	if _announcer != null and not in_match:
		_announce_timer -= delta
		if _announce_timer <= 0.0:
			_announce_timer = ANNOUNCE_INTERVAL
			_announce()
	if _listener != null:
		_listen()


func _announce() -> void:
	var text: String = "%s|%d|%s|%d|%d" % [DISCOVERY_TAG, PROTOCOL, get_player_name(1), players.size(), mode]
	var packet: PackedByteArray = text.to_utf8_buffer()
	# Общий широковещательный адрес и широковещательные адреса подсетей (точка доступа)
	var targets: PackedStringArray = ["255.255.255.255"]
	for address: String in get_local_addresses():
		var parts: PackedStringArray = address.split(".")
		targets.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	for target: String in targets:
		_announcer.set_dest_address(target, DISCOVERY_PORT)
		_announcer.put_packet(packet)


func _listen() -> void:
	var changed: bool = false
	while _listener.get_available_packet_count() > 0:
		var packet: PackedByteArray = _listener.get_packet()
		var address: String = _listener.get_packet_ip()
		var parts: PackedStringArray = packet.get_string_from_utf8().split("|")
		if parts.size() < 5 or parts[0] != DISCOVERY_TAG or int(parts[1]) != PROTOCOL:
			continue
		if address.is_empty() or address in get_local_addresses():
			continue
		if not hosts.has(address):
			changed = true
		hosts[address] = {"name": parts[2], "players": int(parts[3]), "mode": int(parts[4]), "seen": _time}
	for address: String in hosts.keys():
		if _time - float(hosts[address]["seen"]) > HOST_TIMEOUT:
			hosts.erase(address)
			changed = true
	if changed:
		hosts_changed.emit()


# ---------- События сети ----------

func _on_peer_connected(peer_id: int) -> void:
	_extend_timeout(peer_id)
	if is_host() and in_match:
		_rpc_rejected.rpc_id(peer_id, "ИГРА УЖЕ ИДЁТ — ДОЖДИСЬ КОНЦА МАТЧА")
		# Отключаем чуть позже, чтобы сообщение успело дойти
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if _peer != null:
				_peer.disconnect_peer(peer_id))


func _on_peer_disconnected(peer_id: int) -> void:
	if players.has(peer_id):
		players.erase(peer_id)
		if is_host():
			_assign_teams()
			_rpc_lobby.rpc(players, mode, map_index)
		lobby_changed.emit()
	if is_host() and in_match:
		_free_car_seats(peer_id, null)  # вышедший освобождает место в машине
	if match_manager != null and match_manager.has_method(&"on_peer_left"):
		match_manager.call(&"on_peer_left", peer_id)


func _on_connected_to_server() -> void:
	_connect_left = 0.0
	_extend_timeout(1)
	status_changed.emit("ПОДКЛЮЧЕНО К %s" % _host_address)
	var info: Dictionary = _my_info()
	_rpc_register.rpc_id(1, PROTOCOL, info["name"], info["skin"], info["car"])


func _on_connection_failed() -> void:
	status_changed.emit("НЕ УДАЛОСЬ ПОДКЛЮЧИТЬСЯ")
	leave()


func _on_server_disconnected() -> void:
	var was_in_match: bool = in_match
	leave()
	disconnected.emit("ХОСТ ОТКЛЮЧИЛСЯ")
	if was_in_match:
		return_to_lobby()


func _extend_timeout(peer_id: int) -> void:
	if _peer == null:
		return
	var packet_peer: ENetPacketPeer = _peer.get_peer(peer_id)
	if packet_peer != null:
		packet_peer.set_timeout(0, PEER_TIMEOUT_MIN, PEER_TIMEOUT_MAX)


func _my_info() -> Dictionary:
	var skin: PlayerSkin = GameState.get_selected_skin()
	var player_name: String = Settings.player_name.strip_edges()
	if player_name.is_empty():
		player_name = "ВЫЖИВШИЙ"
	return {"name": player_name.substr(0, 16), "skin": skin.id if skin != null else "", "team": 0,
		"loaded": false, "car": GameState.get_car_net_info()}


## Команды: по очереди 0, 1, 0, 1 (1×1, 2×1, 2×2)
func _assign_teams() -> void:
	var ids: Array = players.keys()
	ids.sort()
	for i in ids.size():
		players[ids[i]]["team"] = i % 2


static func _is_private_ipv4(address: String) -> bool:
	if not address.is_valid_ip_address() or ":" in address:
		return false
	return address.begins_with("192.168.") or address.begins_with("10.") \
		or (address.begins_with("172.") and int(address.split(".")[1]) >= 16 and int(address.split(".")[1]) <= 31)


# ---------- RPC: лобби ----------

@rpc("any_peer", "call_remote", "reliable")
func _rpc_register(protocol: int, player_name: String, skin_id: String, car_info: String) -> void:
	if not is_host():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		_rpc_rejected.rpc_id(sender, "РАЗНЫЕ ВЕРСИИ ИГРЫ — ОБНОВИТЕ ИГРУ")
		return
	if players.size() >= MAX_PLAYERS:
		_rpc_rejected.rpc_id(sender, "ЛОББИ ЗАПОЛНЕНО")
		return
	players[sender] = {"name": player_name.substr(0, 16), "skin": skin_id, "team": 0, "loaded": false,
		"car": car_info.substr(0, 64)}
	_assign_teams()
	_rpc_lobby.rpc(players, mode, map_index)
	lobby_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_lobby(new_players: Dictionary, new_mode: int, new_map: int) -> void:
	players = new_players
	mode = new_mode
	map_index = new_map
	lobby_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_rejected(reason: String) -> void:
	leave()
	status_changed.emit(reason)
	disconnected.emit(reason)


@rpc("authority", "call_local", "reliable")
func _rpc_begin_match(new_players: Dictionary, new_mode: int, new_map: int) -> void:
	players = new_players
	match_mode = new_mode
	map_index = new_map
	in_match = true
	pending_go = -1.0
	match_manager = null
	get_tree().paused = false
	# Не грузим сцену внутри обработчика RPC и не блокируем поток: карта грузится в фоне
	_load_map.call_deferred(MAPS[clampi(new_map, 0, MAPS.size() - 1)])


# ---------- Загрузка карты матча ----------

func _load_map(path: String) -> void:
	Engine.time_scale = 1.0  # на случай прерванной кат-сцены
	Ads.hide_banner()  # баннер убежища не должен остаться поверх карты
	_show_loading()
	_loading_progress.clear()
	if ResourceLoader.load_threaded_request(path) != OK:
		push_warning("Net: фоновая загрузка %s не началась — грузим сразу" % path)
		get_tree().change_scene_to_file(path)
		return
	_loading_path = path


func _poll_map_loading() -> void:
	var status: int = ResourceLoader.load_threaded_get_status(_loading_path, _loading_progress)
	if _loading_bar != null and not _loading_progress.is_empty():
		_loading_bar.value = float(_loading_progress[0]) * 100.0
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	var path: String = _loading_path
	_loading_path = ""
	var scene := ResourceLoader.load_threaded_get(path) as PackedScene if status == ResourceLoader.THREAD_LOAD_LOADED else null
	if scene == null:
		push_error("Net: не удалось загрузить карту %s" % path)
		get_tree().change_scene_to_file(path)
		return
	if _loading_bar != null:
		_loading_bar.value = 100.0
	get_tree().change_scene_to_packed(scene)
	# Экран загрузки снимет MatchManager, когда уровень готов; на всякий случай — и по таймеру
	get_tree().create_timer(15.0).timeout.connect(hide_loading)


func _show_loading() -> void:
	if _loading_layer != null:
		return
	_loading_layer = CanvasLayer.new()
	_loading_layer.layer = 120
	add_child(_loading_layer)
	var background := ColorRect.new()
	background.color = Color(0.06, 0.055, 0.05)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_layer.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 18)
	background.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -360.0
	box.offset_right = 360.0
	box.offset_top = -80.0
	box.offset_bottom = 80.0
	var title := UIKit.label("ЗАГРУЗКА КАРТЫ…", 40, box)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = UIKit.ACCENT
	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(0.0, 24.0)
	_loading_bar.show_percentage = false
	box.add_child(_loading_bar)
	var hint := UIKit.label("%s  •  %s" % [MAP_NAMES[clampi(map_index, 0, MAP_NAMES.size() - 1)],
		MODE_NAMES[clampi(match_mode, 0, MODE_NAMES.size() - 1)]], 24, box)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = UIKit.DIM


func hide_loading() -> void:
	if _loading_layer != null and is_instance_valid(_loading_layer):
		_loading_layer.queue_free()
	_loading_layer = null
	_loading_bar = null


# ---------- RPC: матч (передаются в MatchManager) ----------

func _forward(method: StringName, args: Array) -> void:
	if match_manager != null and is_instance_valid(match_manager):
		match_manager.callv(method, args)


@rpc("any_peer", "call_remote", "reliable")
func rpc_loaded() -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	# Хост мог ещё грузить уровень (MatchManager нет) — отметку не теряем
	if is_host() and players.has(sender):
		players[sender]["loaded"] = true
	_forward(&"net_loaded", [sender])


@rpc("authority", "call_local", "reliable")
func rpc_go(time_limit: float) -> void:
	if match_manager == null or not is_instance_valid(match_manager):
		pending_go = time_limit  # уровень ещё грузится — старт применится при его готовности
		return
	_forward(&"net_go", [time_limit])


@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_player_state(state: PackedFloat32Array) -> void:
	_forward(&"net_player_state", [multiplayer.get_remote_sender_id(), state])


## Урон игроку-владельцу: attacker 0 — зомби
@rpc("any_peer", "call_remote", "reliable")
func rpc_damage_player(amount: float, attacker: int, is_head: bool, from_position: Vector3) -> void:
	_forward(&"net_damage_player", [amount, attacker, is_head, from_position])


@rpc("any_peer", "call_remote", "reliable")
func rpc_player_died(killer: int) -> void:
	_forward(&"net_player_died", [multiplayer.get_remote_sender_id(), killer])


@rpc("authority", "call_local", "reliable")
func rpc_kill_feed(killer: int, victim: int, zombie_name: String) -> void:
	_forward(&"net_kill_feed", [killer, victim, zombie_name])


@rpc("authority", "call_local", "reliable")
func rpc_scores(table: Dictionary) -> void:
	_forward(&"net_scores", [table])


@rpc("authority", "call_local", "reliable")
func rpc_announce(text: String) -> void:
	_forward(&"net_announce", [text])


@rpc("authority", "call_local", "reliable")
func rpc_match_end(table: Dictionary, winner_text: String) -> void:
	_forward(&"net_match_end", [table, winner_text])


@rpc("authority", "call_remote", "reliable")
func rpc_zombie_spawn(net_id: int, data_path: String, position: Vector3, yaw: float, health_multiplier: float) -> void:
	_forward(&"net_zombie_spawn", [net_id, data_path, position, yaw, health_multiplier])


@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_zombie_states(states: PackedFloat32Array) -> void:
	_forward(&"net_zombie_states", [states])


@rpc("authority", "call_remote", "reliable")
func rpc_zombie_dead(net_id: int) -> void:
	_forward(&"net_zombie_dead", [net_id])


@rpc("authority", "call_remote", "reliable")
func rpc_zombie_remove(net_id: int) -> void:
	_forward(&"net_zombie_remove", [net_id])


## Взрывная бочка взорвалась у кого-то из игроков — взрываем её у всех
@rpc("any_peer", "call_remote", "reliable")
func rpc_barrel_explode(prop_path: NodePath) -> void:
	var prop: Node = get_tree().root.get_node_or_null(prop_path)
	var barrel := prop.get_node_or_null(^"ExplosiveBarrel") as ExplosiveBarrel if prop != null else null
	if barrel != null:
		barrel.explode_remote()


@rpc("any_peer", "call_remote", "reliable")
func rpc_zombie_damage(net_id: int, amount: float, is_head: bool) -> void:
	_forward(&"net_zombie_damage", [multiplayer.get_remote_sender_id(), net_id, amount, is_head])


# ---------- RPC: машины (места раздаёт хост, машину ведёт водитель) ----------

## Попросить место в машине: want 0 — сесть (за руль, если свободно, иначе пассажиром), -1 — выйти
func request_car_seat(car: DrivableCar, want: int) -> void:
	if car == null or not is_instance_valid(car):
		return
	if is_host():
		_handle_car_request(my_id(), car.get_path(), want)
	else:
		rpc_car_request.rpc_id(1, car.get_path(), want)


@rpc("any_peer", "call_remote", "reliable")
func rpc_car_request(car_path: NodePath, want: int) -> void:
	if is_host():
		_handle_car_request(multiplayer.get_remote_sender_id(), car_path, want)


func _handle_car_request(peer_id: int, car_path: NodePath, want: int) -> void:
	var car := get_tree().root.get_node_or_null(car_path) as DrivableCar
	if car == null:
		return
	_free_car_seats(peer_id, car)  # нельзя сидеть в двух машинах
	var seats: PackedInt32Array = car.seats.duplicate()
	var seat: int = seats.find(peer_id)
	if want < 0:
		if seat >= 0:
			seats[seat] = 0
	elif seat < 0:
		var free: int = seats.find(0)
		if free >= 0:
			seats[free] = peer_id
	# Рассылаем даже без изменений — просивший узнает, что мест нет
	rpc_car_seats.rpc(car_path, seats)


## Освободить места игрока во всех машинах, кроме except
func _free_car_seats(peer_id: int, except: DrivableCar) -> void:
	for node: Node in get_tree().get_nodes_in_group(DrivableCar.GROUP):
		var car := node as DrivableCar
		if car == null or car == except:
			continue
		var seat: int = car.seats.find(peer_id)
		if seat >= 0:
			var seats: PackedInt32Array = car.seats.duplicate()
			seats[seat] = 0
			rpc_car_seats.rpc(car.get_path(), seats)


@rpc("authority", "call_local", "reliable")
func rpc_car_seats(car_path: NodePath, seats: PackedInt32Array) -> void:
	var car := get_tree().root.get_node_or_null(car_path) as DrivableCar
	if car != null:
		car.set_seats(seats)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_car_state(car_path: NodePath, state: PackedFloat32Array) -> void:
	var car := get_tree().root.get_node_or_null(car_path) as DrivableCar
	if car != null:
		car.net_apply_state(multiplayer.get_remote_sender_id(), state)
