extends Node
## Клип для трейлера (запуск с --write-movie). Аргументы: режим ...
##   mission <id> <длительность> <1p|3p> <оружие> — бой: игрок наводится на ближайшего зомби и стреляет
##   hub <длительность> — облёт убежища на максимуме
##   film <id> <длительность> — сюжетный фильм
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

func _ready() -> void:
	_args = OS.get_cmdline_user_args()
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

func _start_mission() -> void:
	_duration = float(_args[2])
	Settings.camera_mode = 1 if _args[3] == "3p" else 0
	_weapon = _args[4]
	if not GameState.owns(_weapon):
		GameState._owned.append(_weapon)
	var mission := load("res://missions/data/%s.tres" % _args[1]) as MissionData
	GameState.selected_mission = mission
	var level: Node = (load(mission.level_scene) as PackedScene).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level

func _start_hub() -> void:
	_duration = float(_args[1])
	GameState.debug_max_shelter()
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
		"hub":
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
		_equipped = true
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
			if zz.global_position.distance_to(_player.global_position) > 15.0:
				var side: float = (float(k % 5) - 2.0) * 0.35
				var spot: Vector3 = _player.global_position + forward.rotated(Vector3.UP, side) * randf_range(10.0, 13.0)
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
	if facing and best < 9.0:
		Input.action_press(&"fire")
	else:
		Input.action_release(&"fire")
	if _player.weapon_manager != null and _player.weapon_manager.get_current_weapon() != null:
		var wm := _player.weapon_manager
		if wm._magazine[wm._index] <= 0:
			wm.reload()
