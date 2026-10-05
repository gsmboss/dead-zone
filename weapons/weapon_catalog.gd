class_name WeaponCatalog
extends Resource
## Список всех стволов игры в порядке показа в оружейной.

@export var weapons: Array[WeaponData] = []


func find(weapon_id: String) -> WeaponData:
	for weapon: WeaponData in weapons:
		if weapon != null and weapon.id == weapon_id:
			return weapon
	return null
