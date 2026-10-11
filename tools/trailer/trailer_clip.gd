extends Node
## Клип для трейлера (запуск с --write-movie). Аргументы: режим ...
##   mission <id> <длительность> <1p|3p> <оружие> — бой: игрок наводится на ближайшего зомби и стреляет
##   hub <длительность> — облёт убежища на максимуме
##   film <id> <длительность> — сюжетный фильм
##   drive <длительность> — город: за рулём своей машины, зомби выходят на дорогу, иногда занос
##   hub <длительность> [уровень 1..5] [orbit|camp|gate] — убежище нужного уровня (по умолчанию — максимум)
## Опции боя (после оружия): boss@<с> — босс миссии с замедленным появлением, spawn=<тип+тип> — эти зомби
## по очереди (enemies/<тип>.tres), deploy — турель, капкан и мина перед игроком, hold — не стрелять первые 2 с
var _args: PackedStringArray
var _t: float = 0.0
var _duration: float = 10.0
var _player: Player
var _cam: Camera3D
var _weapon: String = "rifle"
var _mode: String = ""
var _equipped: bool = false
var _cinema: Node
var _pull_left: float = 4.0
## Вертикальный ролик (окно выше, чем шире, — Shorts): камера уже, зомби ближе
var _vertical: bool = false
const VERTICAL_FOV: float = 60.0
var _boss_at: float = -1.0
var _spawn_types: Array[ZombieData] = []
var _spawn_left: float = 1.0
var _spawn_index: int = 0
var _deploy: bool = false
var _hold: float = 0.0
var _hub_cam: String = "orbit"
var _drive_started: bool = false
var _drive_yaw: float = 0.0
var _drift_left: float = 0.0
var _drift_wait: float = 4.0

func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	var window_size: Vector2i = DisplayServer.window_get_size()
	_vertical = window_size.y > window_size.x
	_mode = _args[0]
	Settings.cutscenes = false
	var lang: String = "en" if _args[_args.size() - 1] == "en" else "ru"
	Settings.language = Settings.Language.ENGLISH if lang == "en" else Settings.Language.RUSSIAN
	Settings.apply()
	TranslationServer.set_locale(lang)
	VoiceOver._checked = true
	VoiceOver._language = lang
	match _mode:
		"mission":
			_start_mission.call_deferred()
		"hub":
			_start_hub.call_deferred()
		"film":
			_start_film.call_deferred()
		"drive":
			_start_drive.call_deferred()

func _start_mission() -> void:
	_duration = float(_args[2])
	Settings.camera_mode = 1 if _args[3] == "3p" else 0
	_weapon = _args[4]
	if not GameState.owns(_weapon):
		GameState._owned.append(_weapon)
	for i in range(5, _args.size()):
		var option: String = _args[i]
		if option.begins_with("boss@"):
			_boss_at = float(option.substr(5))
		elif option.begins_with("spawn="):
			for type_id: String in option.substr(6).split("+"):
				var data := load("res://enemies/%s.tres" % type_id) as ZombieData
				if data != null:
					_spawn_types.append(data)
		elif option == "deploy":
			_deploy = true
		elif option == "hold":
			_hold = 2.0
	_load_mission(_args[1])


func _load_mission(mission_id: String) -> void:
	var mission := load("res://missions/data/%s.tres" % mission_id) as MissionData
	GameState.selected_mission = mission
	var level: Node = (load(mission.level_scene) as PackedScene).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level

func _start_drive() -> void:
	_duration = float(_args[1])
	Settings.camera_mode = 0
	_load_mission("mission_city")


func _start_hub() -> void:
	_duration = float(_args[1])
	var level: int = int(_args[2]) if _args.size() > 2 and _args[2].is_valid_int() else 99
	if _args.size() > 3:
		_hub_cam = _args[3]
	GameState.debug_max_shelter()
	if level < GameState.shelter.config.get_level_count():
		# «До»: голый лагерь — без построек и обустройства
		GameState.shelter.level = maxi(level, 1)
		GameState.shelter.decor_owned.clear()
		GameState._buildings_owned.clear()
		GameState.shelter_changed.emit()
	var hub: Node = (load("res://hub/hub.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(hub)
	get_tree().current_scene = hub
	_cam = Camera3D.new()
	_cam.far = 400.0
	hub.add_child(_cam)
	_cam.make_current()
	var hud := hub.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false

func _start_film() -> void:
	_duration = float(_args[2])
	var film := load("res://story/films/%s.tres" % _args[1]) as StoryFilm
	_cinema = StoryCinema.play(get_tree(), film)

func _process(delta: float) -> void:
	_t += delta
	if _t >= _duration:
		get_tree().quit()
		return
	match _mode:
		"mission":
			_drive_player()
		"film":
			if _cinema != null and is_instance_valid(_cinema):
				for node: Node in _cinema.find_children("*", "Button", true, false):
					(node as Button).visible = false
		"drive":
			_drive(delta)
		"hub":
			match _hub_cam:
				"camp":  # у костра: медленный наезд на сидящих
					var fire: Vector3 = HubCamp.FIRE
					var b: float = 0.6 + _t * 0.05
					_cam.position = fire + Vector3(sin(b) * (6.5 - _t * 0.15), 2.2, cos(b) * (6.5 - _t * 0.15))
					_cam.look_at(fire + Vector3.UP * 0.9)
					var p := get_tree().get_first_node_in_group(&"player") as Node3D
					if p != null:  # разговоры у костра идут, только если игрок рядом
						p.global_position = fire + Vector3(3.0, 0.1, 3.5)
				"gate":  # пролёт над двором от ворот к центру
					_cam.position = Vector3(0.0, 9.0 - _t * 0.3, 30.0 - _t * 2.2)
					_cam.look_at(Vector3(0.0, 1.0, -6.0))
				_:
					var a: float = 0.35 + _t * 0.11
					_cam.position = Vector3(sin(a) * 24.0, 11.0 - _t * 0.25, cos(a) * 24.0)
					_cam.look_at(Vector3(0, 1.5, 0))

func _drive_player() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
		return
	if _player.touch_controls != null:
		_player.touch_controls.visible = false
	if _player.health != null:
		_player.health.current = _player.health.max_health
	if not _equipped and _player.weapon_manager != null and not _player.weapon_manager.weapons.is_empty():
		for i in _player.weapon_manager.weapons.size():
			if _player.weapon_manager.weapons[i].id == _weapon:
				_player.weapon_manager.equip(i)
		if _vertical:
			_player.weapon_manager._base_fov = VERTICAL_FOV
		_equipped = true
	_mission_extras()
	# Постановка: дальних зомби подтягиваем полукругом перед игроком — больше действия в кадре
	_pull_left -= get_process_delta_time()
	if _pull_left <= 0.0:
		_pull_left = 1.2
		var forward: Vector3 = -_player.global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var k: int = 0
		for node: Node in get_tree().get_nodes_in_group(&"zombies"):
			var zz := node as Zombie
			if zz == null or zz.health == null or zz.health.is_dead:
				continue
			var near: float = 7.0 if _vertical else 10.0
			if zz.global_position.distance_to(_player.global_position) > near + 5.0:
				var side: float = (float(k % 5) - 2.0) * (0.25 if _vertical else 0.35)
				var spot: Vector3 = _player.global_position + forward.rotated(Vector3.UP, side) * randf_range(near, near + 3.0)
				spot.y = zz.global_position.y
				zz.global_position = spot
				k += 1
	var target: Node3D = null
	var best: float = 1e9
	for node: Node in get_tree().get_nodes_in_group(&"zombies"):
		var z := node as Zombie
		if z == null or z.health == null or z.health.is_dead:
			continue
		var d: float = z.global_position.distance_to(_player.global_position)
		if d < best and d < 30.0:
			best = d
			target = z
	if target == null:
		Input.action_release(&"fire")
		return
	var aim: Vector3 = target.global_position + Vector3.UP * 1.5
	var from: Vector3 = _player.head.global_position
	var to: Vector3 = aim - from
	var yaw: float = atan2(-to.x, -to.z)
	_player.rotation.y = lerp_angle(_player.rotation.y, yaw, 0.15)
	var pitch: float = rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length()))
	_player._pitch = lerpf(_player._pitch, pitch, 0.15)
	_player._update_head_rotation()
	var facing: bool = absf(wrapf(_player.rotation.y - yaw, -PI, PI)) < 0.12
	if facing and best < 9.0 and _t > _hold:
		Input.action_press(&"fire")
	else:
		Input.action_release(&"fire")
	if _player.weapon_manager != null and _player.weapon_manager.get_current_weapon() != null:
		var wm := _player.weapon_manager
		if wm._magazine[wm._index] <= 0:
			wm.reload()


## Босс, нужные типы зомби и ловушки — по опциям клипа
func _mission_extras() -> void:
	var manager := get_tree().get_first_node_in_group(&"mission_manager") as MissionManager
	if manager == null:
		return
	if _boss_at >= 0.0 and _t >= _boss_at and manager.mission != null and manager.mission.boss != null:
		_boss_at = -1.0
		Settings.cutscenes = true
		GameState.reset_cutscenes()
		manager._spawn_boss()
		_pull_boss.call_deferred()
	if not _spawn_types.is_empty() and manager.spawner != null:
		_spawn_left -= get_process_delta_time()
		if _spawn_left <= 0.0:
			_spawn_left = 1.6
			var zombie: Zombie = manager.spawner.spawn(_spawn_types[_spawn_index % _spawn_types.size()])
			_spawn_index += 1
			if zombie != null:
				_place_in_front(zombie, 9.0, (float(_spawn_index % 3) - 1.0) * 0.3)
	if _deploy and _t > 1.0:
		_deploy = false
		var base_yaw: float = _player.rotation.y
		var items: Array[String] = ["turret", "bear_trap", "land_mine"]
		for i in items.size():
			_player.rotation.y = base_yaw + (float(i) - 1.0) * 0.6
			var item := load("res://items/%s.tres" % items[i]) as ItemData
			if item != null:
				Deployable.place(item, _player)
		_player.rotation.y = base_yaw
		_hold = maxf(_hold, _t + 2.0)


func _pull_boss() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"zombies"):
		var zombie := node as Zombie
		if zombie != null and zombie.data != null and zombie.data.is_boss:
			_place_in_front(zombie, 12.0, 0.0)


func _place_in_front(zombie: Node3D, distance: float, side: float) -> void:
	if _player == null:
		return
	var forward: Vector3 = -_player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var spot: Vector3 = _player.global_position + forward.rotated(Vector3.UP, side) * distance
	spot.y = zombie.global_position.y
	zombie.global_position = spot


## За рулём: газ, держим курс; зомби выходят на дорогу перед капотом; время от времени занос
func _drive(delta: float) -> void:
	var controller: Node = get_tree().current_scene.get_node_or_null("DriveController") \
		if get_tree().current_scene != null else null
	var car := get_tree().current_scene.find_child("MyCar", true, false) as DrivableCar \
		if get_tree().current_scene != null else null
	if controller == null or car == null:
		return
	var touch := get_tree().current_scene.find_child("TouchControls", true, false) as Control
	if touch != null:
		touch.visible = false
	if not _drive_started:
		if _t < 1.0:
			return
		_drive_started = true
		controller.call(&"_sit_in", car, true)
		_drive_yaw = car.global_rotation.y
		Input.action_press(&"move_forward")
		return
	# Держим курс (машина смотрит по -Z)
	var err: float = wrapf(car.global_rotation.y - _drive_yaw, -PI, PI)
	_drift_wait -= delta
	if _drift_wait <= 0.0 and _drift_left <= 0.0:
		_drift_left = 1.4
		_drift_wait = 5.0
	if _drift_left > 0.0:
		_drift_left -= delta
		var hard: bool = _drift_left > 0.7
		_set_steer(1.0 if hard else -1.0)
		if hard:
			Input.action_press(&"jump")
		else:
			Input.action_release(&"jump")
		if _drift_left <= 0.0:
			_drive_yaw = car.global_rotation.y  # новый курс — куда вынесло
			Input.action_release(&"jump")
	else:
		_set_steer(clampf(-err * 2.5, -1.0, 1.0))
	# Зомби выходят на дорогу перед машиной
	_pull_left -= delta
	if _pull_left <= 0.0:
		_pull_left = 0.8
		var forward: Vector3 = -car.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var k: int = 0
		for node: Node in get_tree().get_nodes_in_group(&"zombies"):
			var zombie := node as Zombie
			if zombie == null or zombie.health == null or zombie.health.is_dead or k >= 3:
				continue
			var to: Vector3 = zombie.global_position - car.global_position
			if to.length() > 30.0 or to.dot(forward) < 0.0:
				var spot: Vector3 = car.global_position + forward * randf_range(18.0, 26.0) \
					+ forward.cross(Vector3.UP) * randf_range(-2.0, 2.0)
				spot.y = car.global_position.y
				zombie.global_position = spot
				k += 1


func _set_steer(value: float) -> void:
	# Руль через действия: машина читает Input.get_vector в DriveController
	if value > 0.05:
		Input.action_press(&"move_left", value)
		Input.action_release(&"move_right")
	elif value < -0.05:
		Input.action_press(&"move_right", -value)
		Input.action_release(&"move_left")
	else:
		Input.action_release(&"move_left")
		Input.action_release(&"move_right")
