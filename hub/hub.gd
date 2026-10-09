extends Node3D
## Убежище: игрок ходит между терминалами, оружие в хабе отключено.
## Окна миссий и оружейной открывает HubHUD. При первом запуске — вступительная кат-сцена.

const INTRO_PATH: String = "res://cutscene/hub_intro.tres"


func _ready() -> void:
	# Ждём, пока игрок закончит свой _ready (он сам находит WeaponManager)
	_disable_player_weapons.call_deferred()
	var yard := HubYard.new()
	yard.name = "Yard"
	add_child(yard)
	var camp := HubCamp.new()
	camp.name = "Camp"
	add_child(camp)
	var lounge := HubLounge.new()
	lounge.name = "Lounge"
	add_child(lounge)
	_play_intro.call_deferred()


## Напарник ходит за игроком и в убежище; сменили в окне НАПАРНИК — появляется новый
func _refresh_companion() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"companions"):
		node.queue_free()
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		Companion.spawn_for(player, GameState.get_selected_companion(), true)


func _disable_player_weapons() -> void:
	_refresh_companion()
	if not GameState.companion_changed.is_connected(_refresh_companion):
		GameState.companion_changed.connect(_refresh_companion)
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
	if not Settings.cutscenes:
		_offer_tutorial()
		return
	# Первый вход: сначала фильм-пролог «каким был город и что с ним стало»
	var prologue: StoryFilm = GameState.campaign.prologue_film
	if prologue != null and not GameState.has_seen_cutscene("film_" + prologue.id):
		GameState.mark_cutscene_seen("film_" + prologue.id)
		await StoryCinema.play(get_tree(), prologue).finished
	if not GameState.has_seen_cutscene("hub_intro"):
		var intro := load(INTRO_PATH) as CutsceneData if ResourceLoader.exists(INTRO_PATH) else null
		if intro == null:
			push_warning("%s: не найдена кат-сцена %s" % [name, INTRO_PATH])
		else:
			await CutscenePlayer.play(get_tree(), intro).finished
	_offer_tutorial()


## После вступления — предложить обучение (один раз)
func _offer_tutorial() -> void:
	if not is_inside_tree():
		return
	var hud := get_tree().get_first_node_in_group(&"hub_hud")
	if hud != null and hud.has_method(&"offer_tutorial"):
		hud.call(&"offer_tutorial")
