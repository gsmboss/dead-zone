class_name MissionManager
extends Node
## Управляет миссией: спавн зомби, цель (волны / убийства / выживание),
## победа и поражение, начисление монет. HUD подписывается на сигналы.

signal objective_changed(text: String)
signal announcement(text: String)
signal mission_finished(won: bool, stats: Dictionary)

enum State { STARTING, RUNNING, BETWEEN_WAVES, WON, LOST }

## Шаг роста сложности в режимах без волн
const DIFFICULTY_STEP_TIME: float = 30.0
## За столько секунд пауза спавна доходит до минимальной
const DIFFICULTY_RAMP_TIME: float = 120.0
const HORDE_PING_INTERVAL: float = 4.0
const RESULT_DELAY: float = 1.5
const MAX_TANK_CHANCE: float = 0.4
const MAX_RUNNER_CHANCE: float = 0.6

## Миссия по умолчанию (если уровень запущен напрямую, без убежища)
@export var mission: MissionData
## Пусто → дочерняя нода с zombie_spawner.gd
@export var spawner: ZombieSpawner

var state: State = State.STARTING
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


func _ready() -> void:
	add_to_group(&"mission_manager")
	# Миссия, выбранная в убежище, важнее миссии из инспектора
	if GameState.selected_mission != null:
		mission = GameState.selected_mission
	if mission == null:
		push_error("MissionManager: не назначена mission")
		set_process(false)
		return
	if spawner == null:
		for child: Node in get_children():
			if child is ZombieSpawner:
				spawner = child
				break
	if spawner == null:
		push_error("MissionManager: нет дочерней ноды ZombieSpawner")
		set_process(false)
		return
	_rng.randomize()
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
	state = State.STARTING
	_phase_timer = mission.start_delay
	announcement.emit(mission.title)
	_update_objective()


func _process(delta: float) -> void:
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
			_ping_horde(delta)
			_check_goal()
	_update_objective()


func _begin() -> void:
	if mission.type == MissionData.Type.WAVES:
		_start_wave(1)
	else:
		state = State.RUNNING
		announcement.emit("ВПЕРЁД!")


func _start_wave(number: int) -> void:
	_wave = number
	_wave_left_to_spawn = maxi(mission.first_wave_size + (number - 1) * mission.wave_size_growth, 1)
	_spawn_timer = 0.0
	state = State.RUNNING
	announcement.emit("ВОЛНА %d" % number)


# ---------- Спавн ----------

func _process_spawning(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0 or _alive >= mission.max_alive:
		return

	match mission.type:
		MissionData.Type.WAVES:
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
	var zombie: Zombie = spawner.spawn(data)
	if zombie == null:
		_spawn_timer = 1.0
		return

	zombie.died.connect(_on_zombie_died)
	_alive += 1
	if mission.type == MissionData.Type.WAVES:
		_wave_left_to_spawn -= 1
	_spawn_timer = _current_spawn_interval()


func _current_spawn_interval() -> float:
	if mission.type == MissionData.Type.WAVES:
		return mission.spawn_interval
	var t: float = clampf(elapsed / DIFFICULTY_RAMP_TIME, 0.0, 1.0)
	return lerpf(mission.spawn_interval, mission.min_spawn_interval, t)


func _difficulty_level() -> int:
	if mission.type == MissionData.Type.WAVES:
		return maxi(_wave - 1, 0)
	return floori(elapsed / DIFFICULTY_STEP_TIME)


func _pick_zombie_type() -> ZombieData:
	var level: float = float(_difficulty_level())
	var tank_chance: float = 0.0
	if mission.tank != null:
		tank_chance = clampf(mission.tank_chance + level * mission.tank_chance_per_level,
			0.0, MAX_TANK_CHANCE)
	var runner_chance: float = 0.0
	if mission.runner != null:
		runner_chance = clampf(mission.runner_chance + level * mission.runner_chance_per_level,
			0.0, MAX_RUNNER_CHANCE)

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
			if _wave_left_to_spawn <= 0 and _alive <= 0:
				if _wave >= mission.wave_count:
					_finish(true)
				else:
					state = State.BETWEEN_WAVES
					_phase_timer = mission.time_between_waves
					announcement.emit("ВОЛНА %d ПРОЙДЕНА" % _wave)
		MissionData.Type.KILL_COUNT:
			if kills >= mission.kill_target:
				_finish(true)
		MissionData.Type.SURVIVE:
			if elapsed >= mission.survive_time:
				_finish(true)


func _on_zombie_died(zombie: Zombie) -> void:
	_alive = maxi(_alive - 1, 0)
	if state == State.WON or state == State.LOST:
		return
	kills += 1
	if zombie.data != null:
		score += zombie.data.score
	_check_goal()


func _on_player_died() -> void:
	if state == State.WON or state == State.LOST:
		return
	_finish(false)


func _finish(won: bool) -> void:
	state = State.WON if won else State.LOST
	_update_objective()
	if won:
		announcement.emit("МИССИЯ ВЫПОЛНЕНА")
		_kill_all_zombies()
		_disable_player()

	# Монеты: очки за убитых всегда + награда за победу
	var earned: int = score + (mission.reward_coins if won else 0)
	GameState.add_coins(earned)
	if won:
		GameState.complete_mission(mission, score)

	var stats: Dictionary = {
		"title": mission.title,
		"kills": kills,
		"score": score,
		"time": elapsed,
		"wave": _wave,
		"coins": earned,
		"total_coins": GameState.coins,
	}
	await get_tree().create_timer(RESULT_DELAY).timeout
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
			text = "%s • СТАРТ ЧЕРЕЗ %d" % [mission.title, ceili(_phase_timer)]
		State.BETWEEN_WAVES:
			text = "СЛЕДУЮЩАЯ ВОЛНА ЧЕРЕЗ %d" % ceili(_phase_timer)
		State.RUNNING:
			match mission.type:
				MissionData.Type.WAVES:
					text = "ВОЛНА %d/%d • ЗОМБИ: %d" % [
						_wave, mission.wave_count, _wave_left_to_spawn + _alive]
				MissionData.Type.KILL_COUNT:
					text = "УБИТО %d / %d" % [kills, mission.kill_target]
				MissionData.Type.SURVIVE:
					text = "ПРОДЕРЖИСЬ %s • УБИТО %d" % [
						format_time(mission.survive_time - elapsed), kills]
	if text != _objective_text:
		_objective_text = text
		objective_changed.emit(text)
