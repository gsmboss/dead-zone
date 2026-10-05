extends Node3D
## Убежище: игрок ходит между терминалами, оружие в хабе отключено.
## Окна миссий и оружейной открывает HubHUD. При первом запуске — вступительная кат-сцена.

const INTRO_PATH: String = "res://cutscene/hub_intro.tres"


func _ready() -> void:
	# Ждём, пока игрок закончит свой _ready (он сам находит WeaponManager)
	_disable_player_weapons.call_deferred()
	_play_intro.call_deferred()


func _disable_player_weapons() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		push_warning("%s: игрок (группа \"player\") не найден" % name)
		return
	if player.weapon_manager == null:
		push_warning("%s: у игрока нет WeaponManager" % name)
		return
	# Выключает стрельбу, вью-модель и оружие в руке тела (вид от 3-го лица)
	player.set_weapons_enabled(false)


func _play_intro() -> void:
	if not Settings.cutscenes or GameState.has_seen_cutscene("hub_intro"):
		return
	var intro := load(INTRO_PATH) as CutsceneData if ResourceLoader.exists(INTRO_PATH) else null
	if intro == null:
		push_warning("%s: не найдена кат-сцена %s" % [name, INTRO_PATH])
		return
	CutscenePlayer.play(get_tree(), intro)
