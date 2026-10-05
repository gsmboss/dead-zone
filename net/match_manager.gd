class_name MatchManager
extends Node3D
## Матч по сети в обычном уровне (создаёт MissionManager, если Net.in_match).
## У всех: копии других игроков (Player с is_remote), отправка своего состояния 20 раз/с,
## урон по чужим игрокам и зомби уходит их владельцу, своё возрождение, табло и итоги.
## Хост: волны зомби через ZombieSpawner уровня, рассылка зомби 10 раз/с, очки, таймер, конец матча.

const PLAYER_SCENE: String = "res://player/player.tscn"
const ZOMBIE_TYPES_MISSION: String = "res://missions/data/mission_endless.tres"
const STATE_INTERVAL: float = 0.05
const ZOMBIE_INTERVAL: float = 0.1
const SCORES_INTERVAL: float = 0.5
## Ждём загрузки всех игроков не дольше этого
const LOAD_TIMEOUT: float = 10.0
const RESPAWN_TIME: float = 5.0
const TIME_LIMIT: float = 300.0
const FFA_KILL_LIMIT: int = 10
const TEAM_KILL_LIMIT: int = 15
## Очки: зомби, игрок (PvP), бонус победителю (монеты)
const ZOMBIE_POINTS: int = 1
const PLAYER_POINTS: int = 3
const COINS_PER_ZOMBIE: int = 5
const COINS_PER_PLAYER: int = 20
const WINNER_COINS: int = 100
## Если не было урона от игрока дольше этого — смерть засчитывается зомби
const ATTACKER_MEMORY: float = 5.0
## Поля пакета состояния игрока
const STATE_SIZE: int = 12
const ZOMBIE_STATE_SIZE: int = 7
const TEAM_COLORS: Array[Color] = [Color(0.35, 0.65, 1.0), Color(1.0, 0.4, 0.3)]
const FFA_COLOR: Color = Color(1.0, 0.85, 0.4)

var spawner: ZombieSpawner

var _player: Player
var _hud: MatchHUD
var _proxies: Dictionary = {}   # peer_id -> Player (копия)
var _zombies: Dictionary = {}   # net_id -> Zombie (хост — настоящие, клиент — копии)
var _scores: Dictionary = {}    # peer_id -> {"score", "kills", "zkills", "deaths", "alive", "survived"}
var _spawn_points: Array[Vector3] = []
var _start_position: Vector3 = Vector3.ZERO
var _started: bool = false
var _finished: bool = false
var _time_left: float = TIME_LIMIT
var _elapsed: float = 0.0
var _state_timer: float = 0.0
var _zombie_timer: float = 0.0
var _scores_timer: float = 0.0
var _scores_dirty: bool = false
var _load_timer: float = 0.0
var _respawn_left: float = 0.0
var _shots: int = 0
var _last_attacker: int = 0
var _last_attacker_time: float = -100.0
var _state_buffer := PackedFloat32Array()
var _zombie_buffer := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
# Хост: зомби
var _next_zombie_id: int = 1
var _zombie_attacker: Dictionary = {}  # net_id -> peer_id
var _pending_attacker: int = 0
var _types: MissionData
var _wave: int = 0
var _wave_left: int = 0
var _wave_pause: float = 3.0
var _spawn_timer: float = 0.0
var _zombie_container: Node3D
var _applying_remote: bool = false


func _ready() -> void:
	name = "MatchManager"
	_rng.randomize()
	Net.match_manager = self
	_zombie_container = Node3D.new()
	_zombie_container.name = "NetZombies"
	add_child(_zombie_container)
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		push_error("MatchManager: нет локального игрока")
		return
	if ResourceLoader.exists(ZOMBIE_TYPES_MISSION):
		_types = load(ZOMBIE_TYPES_MISSION) as MissionData
	_collect_spawn_points()
	for peer_id: int in Net.players:
		_scores[peer_id] = {"score": 0, "kills": 0, "zkills": 0, "deaths": 0, "alive": true, "survived": 0.0}
	_player.input_enabled = false
	_player.global_position = _spawn_for(Net.my_id(), true)
	_player.set_safe_position(_player.global_position)
	if _player.health != null:
		_player.health.died.connect(_on_local_died)
	if _player.weapon_manager != null:
		_player.weapon_manager.fired.connect(func(_w: WeaponData) -> void: _shots += 1)
	for peer_id: int in Net.players:
		if peer_id != Net.my_id():
			_create_proxy(peer_id)
	_hud = MatchHUD.new()
	var hud_layer: Node = _player.touch_controls.get_parent() if _player.touch_controls != null else self
	hud_layer.add_child(_hud)
	_hud.setup(self)
	_hud.announce("ЖДЁМ ИГРОКОВ…")
	Zombie.multi_target = Net.is_host()
	if Net.is_host():
		if spawner != null:
			spawner.aggressive = true
			spawner.zombie_spawned.connect(_on_host_zombie_spawned)
		net_loaded(Net.my_id())
	else:
		Net.rpc_loaded.rpc_id(1)


func _exit_tree() -> void:
	Zombie.multi_target = false
	if Net.match_manager == self:
		Net.match_manager = null


# ---------- Публичное для HUD ----------

func get_scores() -> Dictionary:
	return _scores


func get_time_left() -> float:
	return _time_left


func get_respawn_left() -> float:
	return _respawn_left


func get_mode() -> int:
	return Net.match_mode


func color_for(peer_id: int) -> Color:
	if Net.match_mode == Net.Mode.TEAMS:
		return TEAM_COLORS[Net.get_team(peer_id) % TEAM_COLORS.size()]
	return FFA_COLOR if peer_id != Net.my_id() else UIKit.GOOD


# ---------- Цикл ----------

func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if not _started:
		if Net.is_host():
			_load_timer += delta
			if _load_timer >= LOAD_TIMEOUT:
				_go_all()
		return
	if _finished:
		return
	_elapsed += delta
	if Net.match_mode != Net.Mode.LAST_STANDING:
		_time_left = maxf(_time_left - delta, 0.0)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state_timer = STATE_INTERVAL
		_send_state()
	_process_respawn(delta)
	if Net.is_host():
		_host_process(delta)


func _host_process(delta: float) -> void:
	_process_waves(delta)
	_zombie_timer -= delta
	if _zombie_timer <= 0.0:
		_zombie_timer = ZOMBIE_INTERVAL
		_send_zombies()
	_scores_timer -= delta
	if _scores_dirty and _scores_timer <= 0.0:
		_scores_timer = SCORES_INTERVAL
		_scores_dirty = false
		Net.rpc_scores.rpc(_scores)
	_check_end()


# ---------- Загрузка и старт ----------

func net_loaded(peer_id: int) -> void:
	if not Net.is_host() or _started:
		return
	if Net.players.has(peer_id):
		Net.players[peer_id]["loaded"] = true
	for id: int in Net.players:
		if not bool(Net.players[id].get("loaded", false)):
			return
	_go_all()


func _go_all() -> void:
	if _started:
		return
	var limit: float = 0.0 if Net.match_mode == Net.Mode.LAST_STANDING else TIME_LIMIT
	Net.rpc_go.rpc(limit)


func net_go(time_limit: float) -> void:
	_started = true
	_time_left = time_limit
	_player.input_enabled = true
	_hud.announce("В БОЙ!  %s" % Net.MODE_NAMES[Net.match_mode])


# ---------- Свой игрок ----------

func _send_state() -> void:
	var dead: bool = _player.health != null and _player.health.is_dead
	_state_buffer.resize(STATE_SIZE)
	var p: Vector3 = _player.global_position
	_state_buffer[0] = p.x
	_state_buffer[1] = p.y
	_state_buffer[2] = p.z
	_state_buffer[3] = _player.rotation.y
	_state_buffer[4] = _player.get_pitch()
	_state_buffer[5] = Vector2(_player.velocity.x, _player.velocity.z).length()
	_state_buffer[6] = 1.0 if _player.is_on_floor() else 0.0
	_state_buffer[7] = _player.health.current if _player.health != null else 100.0
	_state_buffer[8] = _player.health.max_health if _player.health != null else 100.0
	_state_buffer[9] = float(_weapon_index())
	_state_buffer[10] = float(_shots)
	_state_buffer[11] = 0.0 if dead else 1.0
	Net.rpc_player_state.rpc(_state_buffer)


func _weapon_index() -> int:
	if _player.weapon_manager == null or GameState.catalog == null:
		return -1
	var weapon: WeaponData = _player.weapon_manager.get_current_weapon()
	if weapon == null:
		return -1
	for i in GameState.catalog.weapons.size():
		if GameState.catalog.weapons[i] != null and GameState.catalog.weapons[i].id == weapon.id:
			return i
	return -1


func net_damage_player(amount: float, attacker: int, is_head: bool, from_position: Vector3) -> void:
	if not _started or _finished or _player.health == null or _player.health.is_dead:
		return
	if attacker > 0:
		_last_attacker = attacker
		_last_attacker_time = _elapsed
	_player.health.take_damage(amount, from_position, is_head)


func _on_local_died() -> void:
	var killer: int = _last_attacker if _elapsed - _last_attacker_time <= ATTACKER_MEMORY else 0
	if Net.is_host():
		net_player_died(Net.my_id(), killer)
	else:
		Net.rpc_player_died.rpc_id(1, killer)
	if Net.mode_allows_respawn(Net.match_mode) and not _finished:
		_respawn_left = RESPAWN_TIME


func _process_respawn(delta: float) -> void:
	if _respawn_left <= 0.0:
		return
	_respawn_left -= delta
	if _respawn_left <= 0.0:
		_player.respawn(_spawn_for(Net.my_id(), false))


# ---------- Чужие игроки ----------

func _create_proxy(peer_id: int) -> void:
	var scene: PackedScene = load(PLAYER_SCENE) as PackedScene
	if scene == null:
		push_error("MatchManager: нет %s" % PLAYER_SCENE)
		return
	var proxy := scene.instantiate() as Player
	if proxy == null:
		return
	# Без оружия и ввода: только тело, здоровье и хитбоксы
	var manager: Node = proxy.get_node_or_null(^"Head/Camera3D/WeaponManager")
	if manager != null:
		manager.free()
	proxy.is_remote = true
	proxy.peer_id = peer_id
	proxy.name = "Remote_%d" % peer_id
	add_child(proxy)
	proxy.global_position = _spawn_for(peer_id, true)
	var skin: PlayerSkin = GameState.get_skin(str(Net.players[peer_id].get("skin", "")))
	proxy.body.set_skin(skin if skin != null else GameState.get_selected_skin())
	if proxy.health != null:
		proxy.health.damaged.connect(_on_proxy_damaged.bind(peer_id))
	if Net.is_enemy(peer_id):
		_add_pvp_hitboxes(proxy)
	_add_name_tag(proxy, peer_id)
	proxy.set_meta(&"shots", 0)
	proxy.set_meta(&"weapon", -2)
	_proxies[peer_id] = proxy


func _add_pvp_hitboxes(proxy: Player) -> void:
	var body_box := Hitbox.new()
	body_box.name = "BodyHitbox"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.45
	var body_shape := CollisionShape3D.new()
	body_shape.shape = capsule
	body_shape.position = Vector3(0.0, 0.75, 0.0)
	body_box.add_child(body_shape)
	proxy.add_child(body_box)
	var head_box := Hitbox.new()
	head_box.name = "HeadHitbox"
	head_box.is_head = true
	head_box.damage_multiplier = 2.0
	var sphere := SphereShape3D.new()
	sphere.radius = 0.24
	var head_shape := CollisionShape3D.new()
	head_shape.shape = sphere
	head_shape.position = Vector3(0.0, 1.62, 0.0)
	head_box.add_child(head_shape)
	proxy.add_child(head_box)


func _add_name_tag(proxy: Player, peer_id: int) -> void:
	var tag := Label3D.new()
	tag.text = Net.get_player_name(peer_id)
	tag.font_size = 48
	tag.outline_size = 12
	tag.pixel_size = 0.005
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.modulate = color_for(peer_id)
	tag.position = Vector3(0.0, 2.15, 0.0)
	proxy.add_child(tag)


func net_player_state(peer_id: int, state: PackedFloat32Array) -> void:
	var proxy: Player = _proxies.get(peer_id) as Player
	if proxy == null or not is_instance_valid(proxy) or state.size() < STATE_SIZE:
		return
	proxy.apply_net_state(Vector3(state[0], state[1], state[2]), state[3], state[4], state[5], state[6] > 0.5)
	var alive: bool = state[11] > 0.5
	if proxy.health != null:
		proxy.health.max_health = maxf(state[8], 1.0)
		proxy.health.current = clampf(state[7], 0.0, proxy.health.max_health)
		var was_dead: bool = proxy.health.is_dead
		proxy.health.is_dead = not alive
		if was_dead and alive:
			proxy.body.revive()
		elif not was_dead and not alive:
			proxy.body.on_died()
	var weapon_index: int = int(state[9])
	var weapon: WeaponData = null
	if GameState.catalog != null and weapon_index >= 0 and weapon_index < GameState.catalog.weapons.size():
		weapon = GameState.catalog.weapons[weapon_index]
	if int(proxy.get_meta(&"weapon")) != weapon_index:
		proxy.set_meta(&"weapon", weapon_index)
		proxy.body.set_weapon(weapon)
	var shots: int = int(state[10])
	if shots > int(proxy.get_meta(&"shots")):
		proxy.set_meta(&"shots", shots)
		proxy.body.on_fired(weapon)
		if weapon != null and weapon.fire_sound != null:
			Sfx.play_3d(weapon.fire_sound, proxy.global_position + Vector3.UP * 1.4, weapon.fire_volume_db)


## Чужая копия получила урон здесь: передаём владельцу (выстрел — от нас, удар зомби — только на хосте)
func _on_proxy_damaged(amount: float, hit_position: Vector3, is_head: bool, peer_id: int) -> void:
	if not _started or _finished:
		return
	var attacker: int = Net.my_id() if Hitbox.applying else 0
	if attacker == 0 and not Net.is_host():
		return
	if attacker != 0 and not Net.is_enemy(peer_id):
		return
	Net.rpc_damage_player.rpc_id(peer_id, amount, attacker, is_head, hit_position)


func on_peer_left(peer_id: int) -> void:
	var proxy: Player = _proxies.get(peer_id) as Player
	if proxy != null and is_instance_valid(proxy):
		proxy.queue_free()
	_proxies.erase(peer_id)
	_scores.erase(peer_id)
	if _hud != null:
		_hud.feed("%s ВЫШЕЛ" % Net.get_player_name(peer_id))
		_hud.refresh_scores()


# ---------- Очки (хост) ----------

func net_player_died(peer_id: int, killer: int) -> void:
	if not Net.is_host() or not _scores.has(peer_id):
		return
	var entry: Dictionary = _scores[peer_id]
	entry["deaths"] = int(entry["deaths"]) + 1
	entry["alive"] = Net.mode_allows_respawn(Net.match_mode)
	entry["survived"] = _elapsed
	if killer > 0 and killer != peer_id and _scores.has(killer):
		var killer_entry: Dictionary = _scores[killer]
		killer_entry["kills"] = int(killer_entry["kills"]) + 1
		killer_entry["score"] = int(killer_entry["score"]) + PLAYER_POINTS
	Net.rpc_kill_feed.rpc(killer, peer_id, "")
	_scores_dirty = true
	_scores_timer = 0.0


func net_kill_feed(killer: int, victim: int, zombie_name: String) -> void:
	if _hud == null:
		return
	var victim_name: String = Net.get_player_name(victim)
	if killer > 0:
		_hud.feed("%s  ✖  %s" % [Net.get_player_name(killer), victim_name])
	elif not zombie_name.is_empty():
		_hud.feed("%s  ✖  %s" % [Net.get_player_name(victim), zombie_name])
	else:
		_hud.feed("%s ПОГИБ" % victim_name)


func net_scores(table: Dictionary) -> void:
	_scores = table
	if _hud != null:
		_hud.refresh_scores()


func net_announce(text: String) -> void:
	if _hud != null:
		_hud.announce(text)


func _check_end() -> void:
	if not _started or _finished:
		return
	var reason: String = ""
	var match_type: int = Net.match_mode
	if match_type == Net.Mode.LAST_STANDING:
		var alive: int = 0
		for peer_id: int in _scores:
			if bool(_scores[peer_id]["alive"]):
				alive += 1
		if alive == 0 or (alive <= 1 and _scores.size() > 1):
			reason = "last"
	elif match_type == Net.Mode.FREE_FOR_ALL:
		for peer_id: int in _scores:
			if int(_scores[peer_id]["kills"]) >= FFA_KILL_LIMIT:
				reason = "limit"
	elif match_type == Net.Mode.TEAMS:
		for team in 2:
			if _team_kills(team) >= TEAM_KILL_LIMIT:
				reason = "limit"
	if reason.is_empty() and Net.match_mode != Net.Mode.LAST_STANDING and _time_left <= 0.0:
		reason = "time"
	if Net.match_mode == Net.Mode.COOP_SCORE:
		var anyone_alive: bool = false
		for peer_id: int in _scores:
			anyone_alive = anyone_alive or bool(_scores[peer_id]["alive"])
		if not anyone_alive:
			reason = "dead"
	if reason.is_empty():
		return
	# Выжившим в «последнем живом» — время до конца
	for peer_id: int in _scores:
		if bool(_scores[peer_id]["alive"]):
			_scores[peer_id]["survived"] = _elapsed
	Net.rpc_match_end.rpc(_scores, _winner_text())


func _team_kills(team: int) -> int:
	var total: int = 0
	for peer_id: int in _scores:
		if Net.get_team(peer_id) == team:
			total += int(_scores[peer_id]["kills"])
	return total


func _winner_text() -> String:
	if Net.match_mode == Net.Mode.TEAMS:
		var a: int = _team_kills(0)
		var b: int = _team_kills(1)
		if a == b:
			return "НИЧЬЯ  %d : %d" % [a, b]
		return "ПОБЕДА КОМАНДЫ %s  %d : %d" % ["СИНИХ" if a > b else "КРАСНЫХ", maxi(a, b), mini(a, b)]
	var best: int = winner_id()
	return "ПОБЕДИТЕЛЬ: %s" % Net.get_player_name(best) if best > 0 else "НИЧЬЯ"


## Лучший игрок (для «последнего живого» — кто дольше продержался)
func winner_id() -> int:
	var best: int = 0
	var best_value: float = -1.0
	for peer_id: int in _scores:
		var entry: Dictionary = _scores[peer_id]
		var value: float = float(entry["score"])
		if Net.match_mode == Net.Mode.LAST_STANDING:
			value = float(entry["survived"]) + (10000.0 if bool(entry["alive"]) else 0.0)
		if value > best_value:
			best_value = value
			best = peer_id
	return best


func net_match_end(table: Dictionary, winner_text: String) -> void:
	if _finished:
		return
	_finished = true
	_scores = table
	_player.input_enabled = false
	_respawn_left = 0.0
	if _player.touch_controls != null:
		_player.touch_controls.reset_all()
	var mine: Dictionary = table.get(Net.my_id(), {})
	var coins: int = int(mine.get("zkills", 0)) * COINS_PER_ZOMBIE + int(mine.get("kills", 0)) * COINS_PER_PLAYER
	var won: bool = false
	if Net.match_mode == Net.Mode.TEAMS:
		var mine_team: int = Net.get_team(Net.my_id())
		won = _team_kills(mine_team) > _team_kills(1 - mine_team)
	else:
		won = winner_id() == Net.my_id()
	if won:
		coins += WINNER_COINS
	GameState.add_coins(coins)
	_hud.show_results(winner_text, won, coins)


# ---------- Точки появления ----------

func _collect_spawn_points() -> void:
	_start_position = _player.global_position
	for node: Node in get_tree().get_nodes_in_group(&"item_spawn"):
		var node_3d := node as Node3D
		if node_3d != null:
			_spawn_points.append(node_3d.global_position + Vector3.UP * 0.2)
	# Одинаковый порядок у всех игроков
	_spawn_points.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x or (a.x == b.x and a.z < b.z))
	if _spawn_points.is_empty():
		_spawn_points.append(_start_position)


## first = начало матча (у всех одинаково), иначе — возрождение подальше от врагов
func _spawn_for(peer_id: int, first: bool) -> Vector3:
	var ids: Array = Net.players.keys()
	ids.sort()
	var index: int = maxi(ids.find(peer_id), 0)
	var pvp: bool = Net.match_mode == Net.Mode.FREE_FOR_ALL or Net.match_mode == Net.Mode.TEAMS
	if not pvp:
		var angle: float = TAU * index / maxf(ids.size(), 1.0)
		return _start_position + Vector3(cos(angle), 0.0, sin(angle)) * 2.5
	if first:
		if Net.match_mode == Net.Mode.TEAMS:
			# Команды — с разных концов карты
			var team: int = Net.get_team(peer_id)
			var slot: int = int(index / 2.0)
			var list_index: int = slot if team == 0 else _spawn_points.size() - 1 - slot
			return _spawn_points[clampi(list_index, 0, _spawn_points.size() - 1)]
		var step: int = maxi(int(_spawn_points.size() / maxf(ids.size(), 1.0)), 1)
		return _spawn_points[(index * step) % _spawn_points.size()]
	# Возрождение: точка, дальше всего от живых врагов
	var best: Vector3 = _spawn_points[_rng.randi() % _spawn_points.size()]
	var best_distance: float = -1.0
	for point: Vector3 in _spawn_points:
		var nearest: float = INF
		for other: int in _proxies:
			var proxy: Player = _proxies[other] as Player
			if proxy != null and is_instance_valid(proxy) and Net.is_enemy(other):
				nearest = minf(nearest, point.distance_to(proxy.global_position))
		if nearest > best_distance:
			best_distance = nearest
			best = point
	return best


# ---------- Зомби: хост ----------

func _process_waves(delta: float) -> void:
	if spawner == null or _types == null:
		return
	var pvp: bool = Net.match_mode == Net.Mode.FREE_FOR_ALL or Net.match_mode == Net.Mode.TEAMS
	var players_count: int = maxi(Net.players.size(), 1)
	_spawn_timer -= delta
	if pvp:
		# Немного зомби всё время — мешают всем
		if _zombies.size() < mini(3 + players_count, 8) and _spawn_timer <= 0.0:
			_spawn_timer = 4.0
			_spawn_zombie(_pick_type(), 1.0)
		return
	if _wave_left <= 0:
		if _zombies.is_empty():
			_wave_pause -= delta
			if _wave_pause <= 0.0:
				_wave += 1
				_wave_left = 4 + _wave * 2 + players_count * 2
				_wave_pause = 5.0
				Net.rpc_announce.rpc("ВОЛНА %d" % _wave)
				if _wave % 4 == 0 and _types.boss != null:
					_spawn_zombie(_types.boss, 1.0 + 0.3 * (players_count - 1))
		return
	if _zombies.size() < 14 and _spawn_timer <= 0.0:
		_spawn_timer = 0.9
		var health_multiplier: float = (1.0 + 0.2 * (players_count - 1)) * pow(1.08, _wave - 1)
		if _spawn_zombie(_pick_type(), health_multiplier):
			_wave_left -= 1


func _pick_type() -> ZombieData:
	var roll: float = _rng.randf()
	var runner_chance: float = 0.15 + 0.03 * _wave
	var tank_chance: float = 0.04 + 0.02 * _wave
	if not _types.specials.is_empty() and roll < 0.15:
		var special: ZombieData = _types.specials[_rng.randi() % _types.specials.size()]
		if special != null:
			return special
	if _types.tank != null and roll < 0.15 + tank_chance:
		return _types.tank
	if _types.runner != null and roll < 0.15 + tank_chance + runner_chance:
		return _types.runner
	return _types.walker


func _spawn_zombie(data: ZombieData, health_multiplier: float) -> bool:
	if data == null:
		return false
	return spawner.spawn(data, health_multiplier, 1.0) != null


func _on_host_zombie_spawned(zombie: Zombie) -> void:
	var net_id: int = _next_zombie_id
	_next_zombie_id += 1
	zombie.net_id = net_id
	_zombies[net_id] = zombie
	zombie.died.connect(_on_host_zombie_died.bind(net_id))
	zombie.despawned.connect(_on_host_zombie_removed.bind(net_id))
	if zombie.health != null:
		zombie.health.damaged.connect(_on_host_zombie_damaged.bind(net_id))
	Net.rpc_zombie_spawn.rpc(net_id, zombie.data.resource_path, zombie.global_position, zombie.rotation.y,
		zombie.health_multiplier)


func _on_host_zombie_damaged(_amount: float, _hit_position: Vector3, _is_head: bool, net_id: int) -> void:
	if _pending_attacker != 0:
		_zombie_attacker[net_id] = _pending_attacker
	elif Hitbox.applying:
		_zombie_attacker[net_id] = Net.my_id()


func _on_host_zombie_died(_zombie: Zombie, net_id: int) -> void:
	_zombies.erase(net_id)
	var killer: int = int(_zombie_attacker.get(net_id, 0))
	_zombie_attacker.erase(net_id)
	Net.rpc_zombie_dead.rpc(net_id)
	if killer > 0 and _scores.has(killer):
		var entry: Dictionary = _scores[killer]
		entry["zkills"] = int(entry["zkills"]) + 1
		entry["score"] = int(entry["score"]) + ZOMBIE_POINTS
		_scores_dirty = true


func _on_host_zombie_removed(_zombie: Zombie, net_id: int) -> void:
	_zombies.erase(net_id)
	_zombie_attacker.erase(net_id)
	Net.rpc_zombie_remove.rpc(net_id)


func net_zombie_damage(sender: int, net_id: int, amount: float, is_head: bool) -> void:
	var zombie: Zombie = _zombies.get(net_id) as Zombie
	if not Net.is_host() or zombie == null or not is_instance_valid(zombie) or zombie.health == null:
		return
	_pending_attacker = sender
	zombie.health.take_damage(amount, zombie.global_position + Vector3.UP, is_head)
	_pending_attacker = 0


func _send_zombies() -> void:
	if _zombies.is_empty():
		return
	_zombie_buffer.resize(_zombies.size() * ZOMBIE_STATE_SIZE)
	var i: int = 0
	for net_id: int in _zombies:
		var zombie: Zombie = _zombies[net_id] as Zombie
		if zombie == null or not is_instance_valid(zombie):
			continue
		var p: Vector3 = zombie.global_position
		_zombie_buffer[i] = float(net_id)
		_zombie_buffer[i + 1] = p.x
		_zombie_buffer[i + 2] = p.y
		_zombie_buffer[i + 3] = p.z
		_zombie_buffer[i + 4] = zombie.rotation.y
		_zombie_buffer[i + 5] = float(zombie.state)
		_zombie_buffer[i + 6] = zombie.health.current if zombie.health != null else 0.0
		i += ZOMBIE_STATE_SIZE
	_zombie_buffer.resize(i)
	Net.rpc_zombie_states.rpc(_zombie_buffer)


# ---------- Зомби: клиент (копии) ----------

func net_zombie_spawn(net_id: int, data_path: String, position_value: Vector3, yaw: float,
		health_multiplier: float) -> void:
	if spawner == null or spawner.zombie_scene == null or _zombies.has(net_id):
		return
	var data: ZombieData = load(data_path) as ZombieData if ResourceLoader.exists(data_path) else null
	var zombie := spawner.zombie_scene.instantiate() as Zombie
	if zombie == null:
		return
	zombie.data = data
	zombie.health_multiplier = health_multiplier
	zombie.net_puppet = true
	zombie.net_id = net_id
	zombie.position = position_value
	zombie.rotation.y = yaw
	_zombie_container.add_child(zombie)
	if zombie.health != null:
		zombie.health.damaged.connect(_on_puppet_damaged.bind(net_id))
	_zombies[net_id] = zombie


func _on_puppet_damaged(amount: float, _hit_position: Vector3, is_head: bool, net_id: int) -> void:
	if _applying_remote:
		return
	Net.rpc_zombie_damage.rpc_id(1, net_id, amount, is_head)


func net_zombie_states(states: PackedFloat32Array) -> void:
	var i: int = 0
	while i + ZOMBIE_STATE_SIZE <= states.size():
		var zombie: Zombie = _zombies.get(int(states[i])) as Zombie
		if zombie != null and is_instance_valid(zombie):
			zombie.net_apply_state(Vector3(states[i + 1], states[i + 2], states[i + 3]), states[i + 4],
				int(states[i + 5]), states[i + 6])
		i += ZOMBIE_STATE_SIZE


func net_zombie_dead(net_id: int) -> void:
	var zombie: Zombie = _zombies.get(net_id) as Zombie
	_zombies.erase(net_id)
	if zombie != null and is_instance_valid(zombie):
		_applying_remote = true
		zombie.net_kill()
		_applying_remote = false


func net_zombie_remove(net_id: int) -> void:
	var zombie: Zombie = _zombies.get(net_id) as Zombie
	_zombies.erase(net_id)
	if zombie != null and is_instance_valid(zombie):
		zombie.queue_free()
