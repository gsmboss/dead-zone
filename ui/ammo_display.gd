class_name AmmoDisplay
extends Label
## Название оружия и патроны. Пусто в weapon_manager → поиск по группе.

@export var weapon_manager: WeaponManager

var _weapon_name: String = ""
var _ammo_text: String = ""
var _reloading: bool = false
var _melee: bool = false


func _ready() -> void:
	text = ""
	# Отложенно: к этому моменту WeaponManager точно в дереве
	_connect_manager.call_deferred()


func _connect_manager() -> void:
	if weapon_manager == null:
		weapon_manager = get_tree().get_first_node_in_group(&"weapon_manager") as WeaponManager
	if weapon_manager == null:
		push_warning("AmmoDisplay: WeaponManager не найден")
		return
	weapon_manager.weapon_changed.connect(_on_weapon_changed)
	weapon_manager.ammo_changed.connect(_on_ammo_changed)
	weapon_manager.reload_started.connect(_on_reload_started)
	weapon_manager.reload_finished.connect(_on_reload_ended)
	weapon_manager.reload_cancelled.connect(_on_reload_ended)
	weapon_manager.emit_state()


func _on_weapon_changed(weapon: WeaponData) -> void:
	_weapon_name = weapon.display_name
	_melee = weapon.is_melee
	_reloading = false
	_refresh()


func _on_ammo_changed(magazine: int, reserve: int, infinite_reserve: bool) -> void:
	_ammo_text = "%d / %s" % [magazine, "∞" if infinite_reserve else str(reserve)]
	_refresh()


func _on_reload_started(_duration: float) -> void:
	_reloading = true
	_refresh()


func _on_reload_ended() -> void:
	_reloading = false
	_refresh()


func _refresh() -> void:
	if _melee:
		text = UIKit.t("%s\nБЛИЖНИЙ БОЙ") % UIKit.t(_weapon_name)
		return
	text = "%s\n%s" % [UIKit.t(_weapon_name), UIKit.t("ПЕРЕЗАРЯДКА...") if _reloading else _ammo_text]
