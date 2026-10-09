class_name AttachmentData
extends Resource
## Обвес оружия (глушитель, коллиматор, магазин, лазер...). Каждый — отдельный .tres в weapons/attachments/.
## Покупается для конкретного ствола в оружейной; на ствол — один обвес на слот.

enum Slot { MUZZLE, SIGHT, MAGAZINE, UNDERBARREL }
## Как выглядит на модели в руках (примитивы в WeaponManager)
enum Look { NONE, SILENCER, COMPENSATOR, RED_DOT, LASER, GRIP }

const SLOT_NAMES: Dictionary = {
	Slot.MUZZLE: "ДУЛО",
	Slot.SIGHT: "ПРИЦЕЛ",
	Slot.MAGAZINE: "МАГАЗИН",
	Slot.UNDERBARREL: "ПОД СТВОЛ",
}

## Уникальный id для сохранений, латиницей
@export var id: String = ""
@export var title: String = "ГЛУШИТЕЛЬ"
@export_multiline var description: String = ""
@export var slot: Slot = Slot.MUZZLE
@export var look: Look = Look.NONE
## Базовая цена; для дорогих стволов растёт (get_price)
@export var price: int = 250
## Только для этих стволов (id); пусто — для всего огнестрела
@export var only_for: PackedStringArray = []
## Не ставится на эти стволы (id)
@export var not_for: PackedStringArray = []

@export_group("Effect")
## Множители характеристик (1 — без изменений)
@export var damage: float = 1.0
@export var spread: float = 1.0
@export var ads_spread: float = 1.0
## Зум в прицеле: FOV × это (меньше — сильнее)
@export var ads_fov: float = 1.0
@export var magazine: float = 1.0
@export var reload_time: float = 1.0
@export var recoil: float = 1.0
@export var bloom: float = 1.0
## Насколько далеко зомби слышат выстрел (глушитель < 1)
@export var hearing: float = 1.0
## Громкость выстрела, дБ (глушитель — тише)
@export var volume_db: float = 0.0
@export var fire_pitch: float = 1.0
## Без вспышки на стволе (глушитель)
@export var hide_flash: bool = false


## Подходит ли к стволу: огнестрел, не огнемёт; коллиматор — не на снайперскую с оптикой
func fits(weapon: WeaponData) -> bool:
	if weapon == null or weapon.is_melee or weapon.is_flamethrower or weapon.id.is_empty():
		return false
	if slot == Slot.SIGHT and weapon.has_scope:
		return false
	if weapon.id in not_for:
		return false
	return only_for.is_empty() or weapon.id in only_for


## Цена для ствола: дороже ствол — дороже обвес (пистолет — базовая цена)
func get_price(weapon: WeaponData) -> int:
	if weapon == null:
		return price
	return roundi(price * (1.0 + clampf(weapon.price / 4000.0, 0.0, 1.0)) / 10.0) * 10


## Применить к копии оружия (make_upgraded уже сделал копию)
func apply(weapon: WeaponData) -> void:
	weapon.damage *= damage
	weapon.spread_degrees *= spread
	weapon.ads_spread_multiplier = clampf(weapon.ads_spread_multiplier * ads_spread, 0.0, 1.0)
	weapon.ads_fov_multiplier = clampf(weapon.ads_fov_multiplier * ads_fov, 0.1, 1.0)
	weapon.magazine_size = maxi(1, roundi(weapon.magazine_size * magazine))
	weapon.reload_time = maxf(0.2, weapon.reload_time * reload_time)
	weapon.recoil_pitch *= recoil
	weapon.recoil_yaw *= recoil
	weapon.gun_kick *= recoil
	weapon.bloom_per_shot *= bloom
	weapon.hearing_multiplier *= hearing
	weapon.fire_volume_db += volume_db
	weapon.fire_pitch *= fire_pitch
	weapon.hide_flash = weapon.hide_flash or hide_flash
	if look != Look.NONE:
		weapon.attachment_looks.append(look)
