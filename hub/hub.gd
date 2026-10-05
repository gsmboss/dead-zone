extends Node3D
## Убежище: игрок ходит между терминалами, оружие в хабе отключено.
## Окна миссий и оружейной открывает HubHUD.


func _ready() -> void:
	# Ждём, пока игрок закончит свой _ready (он сам находит WeaponManager)
	_disable_player_weapons.call_deferred()


func _disable_player_weapons() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		push_warning("%s: игрок (группа \"player\") не найден" % name)
		return
	if player.weapon_manager == null:
		push_warning("%s: у игрока нет WeaponManager" % name)
		return
	player.weapon_manager.process_mode = Node.PROCESS_MODE_DISABLED
	player.weapon_manager.visible = false
