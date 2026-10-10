class_name MissionManager
extends Node
## Управляет миссией: спавн зомби и босса, цель (волны / убийства / выживание /
## оборона точки / сбор ящиков), дропы, победа и поражение, звёзды, монеты,
## события для ежедневных заданий. HUD подписывается на сигналы.

signal objective_changed(text: String)
signal announcement(text: String)
signal mission_finished(won: bool, stats: Dictionary)
signal boss_spawned(boss: Zombie)
## Игрок погиб: можно воскреснуть за рекламу (секунд на решение)
signal revive_offered(seconds: float)

enum State { STARTING, RUNNING, BETWEEN_WAVES, WON, LOST }

## Шаг роста сложности в режимах без волн
const DIFFICULTY_STEP_TIME: float = 30.0
## За столько секунд пауза спавна доходит до минимальной
const DIFFICULTY_RAMP_TIME: float = 120.0
const HORDE_PING_INTERVAL: float = 4.0
const RESULT_DELAY: float = 1.5
const MAX_TANK_CHANCE: float = 0.4
const MAX_RUNNER_CHANCE: float = 0.6
const MAX_SPECIAL_CHANCE: float = 0.35
## Ночью: чаще спавн и больше живых зомби
const NIGHT_SPAWN_BOOST: float = 0.7
const NIGHT_EXTRA_ALIVE: int = 5
const MAX_DROPS_ALIVE: int = 6
const DROP_LIFETIME: float = 20.0
const BOSS_RETRY_TIME: float = 2.0
## Урон зомби растёт медленнее здоровья (доля от прироста сложности)
const DAMAGE_DIFFICULTY_SHARE: float = 0.5

## Миссия по умолчанию (если уровень запущен напрямую, без убежища)
@export var mission: MissionData
## Пусто → дочерняя нода с zombie_spawner.gd
@export var spawner: ZombieSpawner

var state: State = State.STARTING
## Обучение выключает обычный спавн, пока игрок не пройдёт шаги (TutorialDirector включит)
var spawning_enabled: bool = true
var kills: int = 0
var score: int = 0
var elapsed: float = 0.0

var _wave: int = 0
var _wave_left_to_spawn: int = 0
var _alive: int = 0
var _spawn_timer: float = 0.0
var _phase_timer: float = 0.0
var _horde_timer: float = 0.0
var _objective_text: String = ""
var _player: Player
var _rng := RandomNumberGenerator.new()

# Сложность и награда (растут с каждым прохождением миссии)
var _level: int = 1
var _health_multiplier: float = 1.0
var _damage_multiplier: float = 1.0
var _reward_multiplier: float = 1.0
# Босс
var _boss_spawned: bool = false
var _boss_timer: float = 0.0
# DEFEND / COLLECT
var _defend_point: DefendPoint
var _defend_progress: float = 0.0
var _on_point: bool = false
var _items_collected: int = 0
var _items_total: int = 0
# Точность для звёзд
var _shots: int = 0
var _hits: int = 0
var _drops: Array[Pickup] = []
var _waves_cleared: int = 0
var _survivors_total: int = 0
var _event: DailyEventData
## Событие недели: свой тип зомби чаще и множитель монет
var _weekly: WeeklyEventData
var _survivors_rescued: int = 0
# Воскрешение за рекламу (один раз за миссию)
const REVIVE_DECISION_TIME: float = 8.0
const REVIVE_CLEAR_RADIUS: float = 6.0
var _revive_used: bool = false
var _revive_pending: bool = false
var _revive_left: float = 0.0
const OBJECTIVE_INTERVAL: float = 0.2
const VOICE_LINES_PATH: String = "res://cutscene/voice_lines.tres"
var _objective_timer: float = 0.0


func _add_edge_cover() -> void:
	EdgeCover.apply(get_tree().current_scene)


func _ready() -> void:
	add_to_group(&"mission_manager")
	# Край карты: земля, страховочный пол и туман (после того, как уровень построит свои стены)
	_add_edge_cover.call_deferred()
	# Миссия, выбранная в убежище, важнее миссии из инспектора
	if GameState.selected_mission != null:
		mission = GameState.selected_mission
	if mission == null:
		push_error("MissionManager: не назначена mission")
		set_process(false)
		return
	# Оформление уровня под главу и время суток (до сборки навмеша — он ждёт пару физических кадров)
	LevelDressing.apply.call_deferred(get_tree().current_scene, mission)
	if spawner == null:
		for child: Node in get_children():
			if child is ZombieSpawner:
				spawner = child
				break
	if spawner == null:
		push_error("MissionManager: нет дочерней ноды ZombieSpawner")
		set_process(false)
		return
	if Net.in_match:
		# Игра по сети: уровнем управляет MatchManager, миссия не идёт
		set_process(false)
		var match_manager := MatchManager.new()
		match_manager.spawner = spawner
		get_parent().add_child.call_deferred(match_manager)
		return
	_rng.randomize()
	_level = GameState.get_mission_level(mission.id)
	var difficulty: float = GameState.get_difficulty_multiplier(mission.id)
	_health_multiplier = difficulty
	_damage_multiplier = 1.0 + (difficulty - 1.0) * DAMAGE_DIFFICULTY_SHARE
	_reward_multiplier = GameState.get_reward_multiplier(mission.id)
	if GameState.is_raid_mission(mission):
		_reward_multiplier *= GameState.RAID_REWARD
	_event = GameState.get_daily_event()
	_weekly = GameState.get_weekly_event()
	spawning_enabled = not mission.tutorial
	_start.call_deferred()


# ---------- Публичный API ----------

func get_objective_text() -> String:
	return _objective_text


static func format_time(seconds: float) -> String:
	var total: int = maxi(ceili(seconds), 0)
	return "%d:%02d" % [floori(total / 60.0), total % 60]


# ---------- Цикл ----------

func _start() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player != null and _player.health != null:
		_player.health.died.connect(_on_player_died)
	else:
		push_warning("MissionManager: игрок или его Health не найдены")
	if _player != null and _player.weapon_manager != null:
		_player.weapon_manager.fired.connect(_on_player_fired)
		_player.weapon_manager.hit_landed.connect(_on_player_hit)

	GameState.on_mission_started()  # медпункт базы
	match mission.type:
		MissionData.Type.DEFEND:
			_setup_defend_point()
		MissionData.Type.COLLECT:
			_spawn_mission_items()

	state = State.STARTING
	_phase_timer = mission.start_delay
	await _play_intro()
	if not is_inside_tree():
		return
	var title: String = UIKit.t(mission.title) if _level <= 1 else UIKit.t("%s • УРОВЕНЬ %d") % [UIKit.t(mission.title), _level]
	if _event != null and (not is_equal_approx(_event.coin_multiplier, 1.0)
			or not is_equal_approx(_event.spawn_multiplier, 1.0) or not is_equal_approx(_event.drop_multiplier, 1.0)):
		title += UIKit.t("\nСОБЫТИЕ ДНЯ: %s") % UIKit.t(_event.title)
	if GameState.is_raid_mission(mission):
		title += "\n" + UIKit.t("НАБЕГ: НАГРАДА ×2, ЛОВУШКИ В СУМКЕ")
	announcement.emit(title)
	_update_objective()
	if mission.tutorial:
		var director := TutorialDirector.new()
		director.name = "Tutorial"
		director.manager = self
		add_child(director)


## Сколько зомби сейчас живо (для обучения)
func get_alive_count() -> int:
	return _alive


## Крикун позвал подмогу: count зомби сверх обычного спавна (обычные типы, не больше REINFORCE_EXTRA
## сверх лимита живых). Сразу знают, где игрок
const REINFORCE_EXTRA: int = 4


func call_reinforcements(count: int) -> void:
	if not spawning_enabled or spawner == null or count <= 0 \
			or (state != State.RUNNING and state != State.BETWEEN_WAVES):
		return
	var limit: int = maxi(roundi(mission.max_alive * Settings.get_crowd_factor()), 2) + REINFORCE_EXTRA
	for i in count:
		if _alive >= limit:
			return
		if mission.type == MissionData.Type.KILL_COUNT and kills + _alive >= mission.kill_target:
			return
		var data: ZombieData = mission.runner if mission.runner != null and _rng.randf() < 0.5 else mission.walker
		if data == null:
			return
		var zombie: Zombie = spawner.spawn(data, _health_multiplier, _damage_multiplier)
		if zombie == null:
			return
		zombie.died.connect(_on_zombie_died)
		zombie.despawned.connect(_on_zombie_despawned)
		_alive += 1
		if _player != null:
			zombie.notify_target(_player.global_position)
			zombie.boost(4.0, 1.25)


## Один зомби вне обычного спавна (обучение): самый простой тип
func spawn_single() -> Zombie:
	var data: ZombieData = mission.walker if mission.walker != null else _pick_zombie_type()
	if data == null or spawner == null:
		return null
	var zombie: Zombie = spawner.spawn(data, _health_multiplier, _damage_multiplier)
	if zombie == null:
		return null
	zombie.died.connect(_on_zombie_died)
	zombie.despawned.connect(_on_zombie_despawned)
	_alive += 1
	return zombie


# ---------- Кат-сцены ----------

## Облёт локации при первом заходе в миссию: обзор, цель, «В БОЙ!»
func _play_intro() -> void:
	var cutscene_id: String = "mission_%s" % mission.id
	if mission.tutorial or not Settings.cutscenes or _player == null or GameState.has_seen_cutscene(cutscene_id):
		return
	var p: Vector3 = _player.global_position
	var forward: Vector3 = -_player.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD
	var side: Vector3 = forward.cross(Vector3.UP)
	var head: Vector3 = p + Vector3.UP * 1.5

	var intro := CutsceneData.new()
	intro.id = cutscene_id
	intro.once = true
	intro.shots.append(_shot(p + Vector3(18.0, 14.0, 18.0), p + Vector3(10.0, 10.0, -12.0), p, p, 3.5,
		UIKit.t("ЛОКАЦИЯ: %s\n%s") % [UIKit.t(mission.get_location_name()), UIKit.t(mission.title)]))
	intro.shots.append(_shot(p + forward * 8.0 + Vector3.UP * 2.0, p + forward * 4.0 + Vector3.UP * 1.8 + side * 2.0,
		head, head, 3.0, UIKit.t("ЦЕЛЬ: %s") % mission.get_goal_text().to_upper()))
	intro.shots.append(_shot(p - forward * 3.0 + Vector3.UP * 2.5, p + Vector3.UP * 1.6,
		head + forward * 10.0, head + forward * 10.0, 1.8, "В БОЙ!"))
	_add_intro_voices(intro)
	set_process(false)  # отсчёт start_delay — после сцены
	await CutscenePlayer.play(get_tree(), intro).finished
	if is_inside_tree():
		set_process(true)


## Замедленное появление босса: камера у его лица, имя в субтитрах (раз на тип босса)
func _play_boss_intro(boss: Zombie) -> void:
	if not Settings.cutscenes or CutscenePlayer.active or not is_instance_valid(boss) or not boss.is_inside_tree():
		return
	var cutscene_id: String = "boss_%s" % mission.boss.resource_path.get_file().get_basename()
	if GameState.has_seen_cutscene(cutscene_id):
		return
	var forward: Vector3 = -boss.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD
	var face: Vector3 = Vector3.UP * 2.5
	var intro := CutsceneData.new()
	intro.id = cutscene_id
	intro.once = true
	intro.time_scale = 0.25
	var shot := _shot(forward * 7.0 + Vector3.UP * 1.2, forward * 4.0 + Vector3.UP * 2.6 + forward.cross(Vector3.UP) * 1.5,
		face, face, 2.4, mission.boss.display_name.to_upper())
	shot.relative_to = CutsceneShot.Space.ANCHOR
	var lines: VoiceLines = _voice_lines()
	if lines != null:
		_set_voice(shot, VoiceLines.pick_pair(lines.boss_ru, lines.boss_en,
			{"boss": _spoken(mission.boss.display_name)}))
	intro.shots.append(shot)
	CutscenePlayer.play(get_tree(), intro, boss)


## Смешные реплики рассказчика для интро миссии (по плану: обзор, цель, в бой)
func _add_intro_voices(intro: CutsceneData) -> void:
	var lines: VoiceLines = _voice_lines()
	if lines == null or intro.shots.size() < 3:
		return
	var values: Dictionary = {"location": _spoken(mission.get_location_name()), "mission": _spoken(mission.title)}
	_set_voice(intro.shots[0], VoiceLines.pick_pair(lines.location_ru, lines.location_en, values))
	_set_voice(intro.shots[1], VoiceLines.pick_pair(lines.goal_ru, lines.goal_en, values))
	_set_voice(intro.shots[2], VoiceLines.pick_pair(lines.fight_ru, lines.fight_en, values))


func _voice_lines() -> VoiceLines:
	return load(VOICE_LINES_PATH) as VoiceLines if ResourceLoader.exists(VOICE_LINES_PATH) else null


func _set_voice(shot: CutsceneShot, pair: PackedStringArray) -> void:
	if pair.size() >= 2:
		shot.voice_ru = pair[0]
		shot.voice_en = pair[1]


## Название для голоса: не капсом (синтезатор читает КАПС по буквам)
static func _spoken(text: String) -> String:
	var lower: String = text.strip_edges().to_lower()
	return lower.substr(0, 1).to_upper() + lower.substr(1) if not lower.is_empty() else lower


func _shot(from: Vector3, to: Vector3, look_from: Vector3, look_to: Vector3, duration: float, subtitle: String) -> CutsceneShot:
	var shot := CutsceneShot.new()
	shot.from_position = from
	shot.to_position = to
	shot.look_from = look_from
	shot.look_to = look_to
	shot.duration = duration
	shot.subtitle = subtitle
	return shot


func _process(delta: float) -> void:
	if _revive_pending:
		# Пока идёт реклама, время на решение не тратится
		if not Ads.is_showing_fullscreen():
			_revive_left -= delta
			if _revive_left <= 0.0:
				decline_revive()
		return
	match state:
		State.STARTING:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_begin()
		State.BETWEEN_WAVES:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_start_wave(_wave + 1)
		State.RUNNING:
			elapsed += delta
			_process_spawning(delta)
			_process_boss(delta)
			_process_defend(delta)
			_ping_horde(delta)
			_check_goal()
	# Текст цели — 5 раз в секунду, не каждый кадр (форматирование строк)
	_objective_timer -= delta
	if _objective_timer <= 0.0:
		_objective_timer = OBJECTIVE_INTERVAL
		_update_objective()


func _begin() -> void:
	if _is_wave_mode():
		_start_wave(1)
	else:
		state = State.RUNNING
		announcement.emit("ВПЕРЁД!")


func _start_wave(number: int) -> void:
	_wave = number
	_wave_left_to_spawn = maxi(mission.first_wave_size + (number - 1) * mission.wave_size_growth, 1)
	_spawn_timer = 0.0
	state = State.RUNNING
	if mission.type == MissionData.Type.ENDLESS:
		# Бесконечные волны: босс каждые boss_every_waves волн
		if mission.boss != null and number % mission.boss_every_waves == 0:
			announcement.emit(UIKit.t("ВОЛНА %d: %s!") % [number, UIKit.t(mission.boss.display_name)])
			_boss_spawned = false
			_spawn_boss()
		else:
			announcement.emit(UIKit.t("ВОЛНА %d") % number)
	elif number >= mission.wave_count and mission.boss != null and not _boss_spawned:
		announcement.emit(UIKit.t("ПОСЛЕДНЯЯ ВОЛНА: %s!") % UIKit.t(mission.boss.display_name))
		_spawn_boss()
	else:
		announcement.emit(UIKit.t("ВОЛНА %d") % number)


# ---------- Спавн ----------

func _process_spawning(delta: float) -> void:
	if not spawning_enabled:
		return
	_spawn_timer -= delta
	var max_alive: int = maxi(roundi((mission.max_alive + DayNightCycle.night_amount * NIGHT_EXTRA_ALIVE)
		* Settings.get_crowd_factor()), 2)
	if _spawn_timer > 0.0 or _alive >= max_alive:
		return

	match mission.type:
		MissionData.Type.WAVES, MissionData.Type.ENDLESS:
			if _wave_left_to_spawn <= 0:
				return
		MissionData.Type.KILL_COUNT:
			# Не создаём больше, чем осталось убить
			if kills + _alive >= mission.kill_target:
				return

	var data: ZombieData = _pick_zombie_type()
	if data == null:
		_spawn_timer = 1.0
		return
	var zombie: Zombie = spawner.spawn(data, _health_multiplier, _damage_multiplier)
	if zombie == null:
		_spawn_timer = 1.0
		return

	zombie.died.connect(_on_zombie_died)
	zombie.despawned.connect(_on_zombie_despawned)
	_alive += 1
	if _is_wave_mode():
		_wave_left_to_spawn -= 1
	_spawn_timer = _current_spawn_interval()


# ---------- Босс ----------

func _process_boss(delta: float) -> void:
	if mission.boss == null or _is_wave_mode():
		return
	if _boss_spawned and mission.type != MissionData.Type.FREE_ROAM:
		return
	_boss_timer += delta
	if _boss_timer >= mission.boss_delay:
		_boss_timer = 0.0  # в открытом мире босс приходит снова через boss_delay
		announcement.emit("%s!" % UIKit.t(mission.boss.display_name))
		_spawn_boss()


func _spawn_boss() -> void:
	var boss: Zombie = spawner.spawn(mission.boss, _health_multiplier, _damage_multiplier)
	if boss == null:
		# Нет подходящей точки — повторим чуть позже
		if _is_wave_mode():
			_retry_boss_later.call_deferred()
		else:
			_boss_timer = mission.boss_delay - BOSS_RETRY_TIME
		return
	_boss_spawned = true
	boss.died.connect(_on_zombie_died)
	boss.despawned.connect(_on_zombie_despawned)
	_alive += 1
	boss_spawned.emit(boss)
	_play_boss_intro.call_deferred(boss)


func _retry_boss_later() -> void:
	await create_tween().tween_interval(BOSS_RETRY_TIME).finished  # твин умирает вместе с узлом
	if is_inside_tree() and state == State.RUNNING and not _boss_spawned:
		_spawn_boss()


# ---------- Оборона точки и сбор ящиков ----------

func _setup_defend_point() -> void:
	_defend_point = get_tree().get_first_node_in_group(&"defend_point") as DefendPoint
	if _defend_point == null:
		# В уровне нет точки — ставим её там, где стоит игрок
		push_warning("MissionManager: в уровне нет DefendPoint, точка создана у игрока")
		_defend_point = DefendPoint.new()
		get_tree().current_scene.add_child(_defend_point)
		if _player != null:
			_defend_point.global_position = _player.global_position
	_defend_point.activate(mission.defend_radius)


func _process_defend(delta: float) -> void:
	if mission.type != MissionData.Type.DEFEND or _defend_point == null or _player == null:
		return
	var offset: Vector3 = _player.global_position - _defend_point.global_position
	var on_point: bool = Vector2(offset.x, offset.z).length() <= mission.defend_radius
	if on_point != _on_point:
		_on_point = on_point
		_defend_point.set_occupied(on_point)
		if not on_point:
			announcement.emit("ВЕРНИСЬ НА ТОЧКУ!")
	if on_point:
		_defend_progress += delta


func _spawn_mission_items() -> void:
	var points: Array[Vector3] = []
	for node: Node in get_tree().get_nodes_in_group(&"item_spawn"):
		if node is Node3D:
			points.append((node as Node3D).global_position)
	if points.is_empty():
		push_error("MissionManager: в уровне нет ItemSpawnPoint для миссии COLLECT")
		return
	# Перемешиваем и берём первые collect_target точек
	for i in range(points.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Vector3 = points[i]
		points[i] = points[j]
		points[j] = tmp
	_items_total = mini(mission.collect_target, points.size())
	if _items_total < mission.collect_target:
		push_warning("MissionManager: точек для ящиков %d, а нужно %d" % [points.size(), mission.collect_target])
	for i in _items_total:
		var item := Pickup.new()
		item.kind = Pickup.Kind.MISSION_ITEM
		get_tree().current_scene.add_child(item)
		item.global_position = points[i]


## Вызывается ящиком с припасами при подборе
func on_item_collected() -> void:
	if state == State.WON or state == State.LOST:
		return
	_items_collected += 1
	GameState.report_event(&"item_collect")
	if _items_collected < _items_total:
		announcement.emit(UIKit.t("ЯЩИК %d / %d") % [_items_collected, _items_total])
	_check_goal()


# ---------- Дропы ----------

## Множитель события дня: &"coins", &"spawn", &"drops"
func _event_value(kind: StringName) -> float:
	# Событие недели: монеты (действует и без события дня)
	var weekly_coins: float = 1.0
	if kind == &"coins" and _weekly != null and not mission.tutorial:
		weekly_coins = maxf(_weekly.coin_multiplier, 0.0)
	if _event == null:
		return weekly_coins
	match kind:
		&"coins":
			return maxf(_event.coin_multiplier, 0.0) * weekly_coins
		&"spawn":
			return maxf(_event.spawn_multiplier, 0.1)
		&"drops":
			return maxf(_event.drop_multiplier, 0.0)
	return 1.0


func _try_drop(at: Vector3) -> void:
	for i in range(_drops.size() - 1, -1, -1):
		if not is_instance_valid(_drops[i]):
			_drops.remove_at(i)
	if _drops.size() >= MAX_DROPS_ALIVE:
		return
	var drop_boost: float = _event_value(&"drops")
	if _rng.randf() < mission.scrap_drop_chance * drop_boost:
		var scrap := Pickup.new()
		scrap.kind = Pickup.Kind.SCRAP
		scrap.amount = 1.0
		scrap.lifetime = DROP_LIFETIME
		get_tree().current_scene.add_child(scrap)
		scrap.global_position = at + Vector3(0.6, 0.0, 0.0)
		_drops.append(scrap)
	var roll: float = _rng.randf()
	var kind: Pickup.Kind
	if roll < mission.health_drop_chance * drop_boost:
		kind = Pickup.Kind.HEALTH
	elif roll < (mission.health_drop_chance + mission.ammo_drop_chance) * drop_boost:
		kind = Pickup.Kind.AMMO
	else:
		return
	var drop := Pickup.new()
	drop.kind = kind
	drop.amount = mission.health_drop_amount if kind == Pickup.Kind.HEALTH else 0.35
	drop.lifetime = DROP_LIFETIME
	get_tree().current_scene.add_child(drop)
	drop.global_position = at
	_drops.append(drop)


func _on_player_fired(_weapon: WeaponData) -> void:
	if state == State.RUNNING:
		_shots += 1


func _on_player_hit(_is_headshot: bool, _killed: bool) -> void:
	if state == State.RUNNING:
		_hits += 1


func _current_spawn_interval() -> float:
	if _is_wave_mode():
		return mission.spawn_interval
	var t: float = clampf(elapsed / DIFFICULTY_RAMP_TIME, 0.0, 1.0)
	# Ночью (город) зомби приходят чаще
	return lerpf(mission.spawn_interval, mission.min_spawn_interval, t) \
		/ (1.0 + DayNightCycle.night_amount * NIGHT_SPAWN_BOOST) / _event_value(&"spawn")


func _difficulty_level() -> int:
	if _is_wave_mode():
		return maxi(_wave - 1, 0)
	return floori(elapsed / DIFFICULTY_STEP_TIME)


func _pick_zombie_type() -> ZombieData:
	if _weekly != null and _weekly.zombie != null and not mission.tutorial \
			and _rng.randf() < _weekly.zombie_chance:
		return _weekly.zombie
	var level: float = float(_difficulty_level())
	var tank_chance: float = 0.0
	if mission.tank != null:
		tank_chance = clampf(mission.tank_chance + level * mission.tank_chance_per_level,
			0.0, MAX_TANK_CHANCE)
	var runner_chance: float = 0.0
	if mission.runner != null:
		runner_chance = clampf(mission.runner_chance + level * mission.runner_chance_per_level,
			0.0, MAX_RUNNER_CHANCE)

	if not mission.specials.is_empty():
		var special_chance: float = clampf(mission.special_chance + level * mission.special_chance_per_level,
			0.0, MAX_SPECIAL_CHANCE)
		if _rng.randf() < special_chance:
			var special: ZombieData = mission.specials[_rng.randi() % mission.specials.size()]
			if special != null:
				return special

	var roll: float = _rng.randf()
	if roll < tank_chance:
		return mission.tank
	if roll < tank_chance + runner_chance:
		return mission.runner
	if mission.walker != null:
		return mission.walker
	if mission.runner != null:
		return mission.runner
	if mission.tank == null:
		push_error("MissionManager: в миссии не задан ни один тип зомби")
	return mission.tank


func _ping_horde(delta: float) -> void:
	if not mission.horde_mode or _player == null:
		return
	_horde_timer -= delta
	if _horde_timer > 0.0:
		return
	_horde_timer = HORDE_PING_INTERVAL
	for node: Node in get_tree().get_nodes_in_group(&"zombies"):
		var zombie := node as Zombie
		if zombie != null:
			zombie.notify_target(_player.global_position)


# ---------- Цель и итог ----------

func _check_goal() -> void:
	if state != State.RUNNING:
		return
	match mission.type:
		MissionData.Type.WAVES:
			var boss_pending: bool = mission.boss != null and not _boss_spawned \
				and _wave >= mission.wave_count
			if _wave_left_to_spawn <= 0 and _alive <= 0 and not boss_pending:
				if _wave >= mission.wave_count:
					_finish(true)
				else:
					state = State.BETWEEN_WAVES
					_phase_timer = mission.time_between_waves
					announcement.emit(UIKit.t("ВОЛНА %d ПРОЙДЕНА") % _wave)
		MissionData.Type.KILL_COUNT:
			if kills >= mission.kill_target:
				_finish(true)
		MissionData.Type.SURVIVE:
			if elapsed >= mission.survive_time:
				_finish(true)
		MissionData.Type.DEFEND:
			if _defend_progress >= mission.defend_time:
				_finish(true)
		MissionData.Type.COLLECT:
			if _items_total > 0 and _items_collected >= _items_total:
				_finish(true)
		MissionData.Type.ENDLESS:
			# Волны без конца: каждая пройденная — монеты, затем следующая
			if _wave_left_to_spawn <= 0 and _alive <= 0:
				_waves_cleared = _wave
				state = State.BETWEEN_WAVES
				_phase_timer = mission.time_between_waves
				announcement.emit(UIKit.t("ВОЛНА %d ПРОЙДЕНА  +%d") % [_wave, mission.coins_per_wave])
		# FREE_ROAM: цели нет — игра до смерти или выхода в убежище


## Выход из миссии через меню паузы: монеты за убитых сохраняются, победы нет
func leave_mission() -> void:
	if state == State.WON or state == State.LOST:
		return
	state = State.LOST
	GameState.end_raid()
	var earned: int = roundi((score + _waves_cleared * mission.coins_per_wave) * _event_value(&"coins"))
	_record_endless()
	GameState.add_coins(earned)
	GameState.save_game()


func _is_wave_mode() -> bool:
	return mission.type == MissionData.Type.WAVES or mission.type == MissionData.Type.ENDLESS


## Рекорд бесконечного режима — номер пройденной волны (хранится как лучший счёт)
func _record_endless() -> void:
	if mission.type == MissionData.Type.ENDLESS and _waves_cleared > 0:
		GameState.record_score(mission, _waves_cleared)
		GameState.report_record(&"endless_wave", _waves_cleared)


## Выжившие города сообщают о себе (для цели «СПАСЕНО N / M»)
func register_survivor() -> void:
	_survivors_total += 1


func on_survivor_rescued(coins: int) -> void:
	_survivors_rescued += 1
	announcement.emit(UIKit.t("ВЫЖИВШИЙ СПАСЁН  +%d") % coins)


func _on_zombie_despawned(_zombie: Zombie) -> void:
	_alive = maxi(_alive - 1, 0)


func _on_zombie_died(zombie: Zombie) -> void:
	_alive = maxi(_alive - 1, 0)
	if state == State.WON or state == State.LOST:
		return
	kills += 1
	GameState.report_event(&"kill")
	if zombie.killed_by_headshot:
		GameState.report_event(&"headshot_kill")
	if _player != null and _player.weapon_manager != null:
		var weapon: WeaponData = _player.weapon_manager.get_current_weapon()
		if weapon != null and weapon.is_melee:
			GameState.report_event(&"melee_kill")
	if zombie.data != null:
		if zombie.data.behavior == ZombieData.Behavior.SCREAMER:
			GameState.report_event(&"screamer_kill")
		elif zombie.data.front_armor < 1.0 and not zombie.data.is_boss:
			GameState.report_event(&"brute_kill")
		score += zombie.data.score
		if zombie.data.is_boss:
			GameState.report_event(&"boss_kill")
		elif zombie.data == mission.tank:
			GameState.report_event(&"tank_kill")
	_try_drop(zombie.global_position)
	_check_goal()


func _on_player_died() -> void:
	if state == State.WON or state == State.LOST or _revive_pending:
		return
	if not _revive_used and Ads.is_rewarded_ready():
		_revive_pending = true
		_revive_left = REVIVE_DECISION_TIME
		revive_offered.emit(REVIVE_DECISION_TIME)
		return
	_finish(false)


## Секунды на решение «воскреснуть?» (для HUD)
func get_revive_left() -> float:
	return _revive_left if _revive_pending else 0.0


## Досмотрел рекламу: встаёт на том же месте, зомби рядом отбрасывает и убивает
func revive() -> void:
	if not _revive_pending or _player == null:
		return
	_revive_pending = false
	_revive_used = true
	var at: Vector3 = _player.global_position
	for node: Node in get_tree().get_nodes_in_group(&"zombies"):
		var zombie := node as Zombie
		if zombie == null or zombie.state == Zombie.State.DEAD or (zombie.data != null and zombie.data.is_boss):
			continue
		var offset: Vector3 = zombie.global_position - at
		if offset.length() <= REVIVE_CLEAR_RADIUS:
			offset.y = 0.0
			zombie.defuse()  # взрывник рядом не должен ранить только что воскресшего
			zombie.apply_blast(zombie.health.current + 1.0 if zombie.health != null else 9999.0,
				offset.normalized() * 10.0)
	_player.respawn(at)
	announcement.emit("ВТОРОЙ ШАНС!")


## Отказался или не досмотрел — поражение
func decline_revive() -> void:
	if not _revive_pending:
		return
	_revive_pending = false
	_finish(false)


func _finish(won: bool) -> void:
	state = State.WON if won else State.LOST
	_update_objective()
	if won:
		announcement.emit("МИССИЯ ВЫПОЛНЕНА")
		_kill_all_zombies()
		_disable_player()

	var accuracy: float = float(_hits) / float(_shots) if _shots > 0 else 0.0
	var health_share: float = 0.0
	if _player != null and _player.health != null and _player.health.max_health > 0.0:
		health_share = _player.health.current / _player.health.max_health
	var stars: int = 0
	if won:
		stars = 1
		if health_share >= mission.star_health:
			stars += 1
		if accuracy >= mission.star_accuracy:
			stars += 1
		GameState.report_event(&"mission_win")
		if stars >= 3:
			GameState.report_event(&"stars3")
		if GameState.is_raid_mission(mission):
			GameState.report_event(&"raid_win")

	# Монеты: очки за убитых всегда + награда за победу (растёт с уровнем миссии)
	# + за пройденные волны бесконечного режима
	var earned: int = roundi((score + (roundi(mission.reward_coins * _reward_multiplier) if won else 0)
		+ _waves_cleared * mission.coins_per_wave) * _event_value(&"coins"))
	_record_endless()
	if won:
		GameState.end_raid()
		GameState.complete_mission(mission, score, stars)
		if mission.tutorial:
			GameState.mark_cutscene_seen(TutorialDirector.DONE_FLAG)
	GameState.add_coins(earned)
	GameState.save_game()  # прогресс заданий, даже если монет 0

	var stats: Dictionary = {
		"title": mission.title,
		"kills": kills,
		"score": score,
		"time": elapsed,
		"wave": _wave,
		"coins": earned,
		"total_coins": GameState.coins,
		"stars": stars,
		"accuracy": accuracy,
		"health_share": health_share,
		"level": _level,
		"waves": _waves_cleared,
		"endless": mission.type == MissionData.Type.ENDLESS,
	}
	await create_tween().tween_interval(RESULT_DELAY).finished  # твин умирает вместе с узлом
	if not is_inside_tree():
		return
	mission_finished.emit(won, stats)


func _kill_all_zombies() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"zombies"):
		var zombie := node as Zombie
		if zombie != null and zombie.health != null and not zombie.health.is_dead:
			zombie.health.take_damage(zombie.health.current + 1.0)


func _disable_player() -> void:
	if _player == null:
		return
	_player.input_enabled = false
	if _player.touch_controls != null:
		_player.touch_controls.hide()


func _update_objective() -> void:
	var text: String = ""
	match state:
		State.WON:
			text = "МИССИЯ ВЫПОЛНЕНА"
		State.LOST:
			text = "МИССИЯ ПРОВАЛЕНА"
		State.STARTING:
			text = UIKit.t("%s • СТАРТ ЧЕРЕЗ %d") % [UIKit.t(mission.title), ceili(_phase_timer)]
		State.BETWEEN_WAVES:
			text = UIKit.t("СЛЕДУЮЩАЯ ВОЛНА ЧЕРЕЗ %d") % ceili(_phase_timer)
		State.RUNNING:
			match mission.type:
				MissionData.Type.WAVES:
					text = UIKit.t("ВОЛНА %d/%d • ЗОМБИ: %d") % [
						_wave, mission.wave_count, _wave_left_to_spawn + _alive]
				MissionData.Type.KILL_COUNT:
					text = UIKit.t("УБИТО %d / %d") % [kills, mission.kill_target]
				MissionData.Type.SURVIVE:
					text = UIKit.t("ПРОДЕРЖИСЬ %s • УБИТО %d") % [
						format_time(mission.survive_time - elapsed), kills]
				MissionData.Type.DEFEND:
					var percent: int = floori(100.0 * _defend_progress / maxf(mission.defend_time, 0.1))
					text = UIKit.t("УДЕРЖИВАЙ ТОЧКУ %d%%%s") % [percent, "" if _on_point else UIKit.t(" • ВЕРНИСЬ НА ТОЧКУ!")]
				MissionData.Type.COLLECT:
					text = UIKit.t("ЯЩИКИ С ПРИПАСАМИ %d / %d • УБИТО %d") % [_items_collected, _items_total, kills]
				MissionData.Type.ENDLESS:
					text = UIKit.t("ВОЛНА %d • ЗОМБИ: %d • РЕКОРД %d") % [
						_wave, _wave_left_to_spawn + _alive, GameState.get_best_score(mission.id)]
				MissionData.Type.FREE_ROAM:
					text = UIKit.t("УБИТО %d • ОЧКИ %d • %s") % [kills, score, format_time(elapsed)]
					if _survivors_total > 0:
						text += UIKit.t(" • СПАСЕНО %d/%d") % [_survivors_rescued, _survivors_total]
	if text != _objective_text:
		_objective_text = text
		objective_changed.emit(text)
