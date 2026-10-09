class_name CompanionData
extends Resource
## Напарник в миссиях: пёс (кусает) или выживший со стволом (стреляет). Покупается в убежище,
## часть открывается сюжетом (unlock_chapter). Внешность — PlayerSkin, оружие — WeaponData (модель и звук).

enum Kind { DOG, GUNNER }

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.GUNNER
@export var price: int = 0
## Глава сюжета, после которой напарник доступен (пусто — сразу)
@export var unlock_chapter: String = ""
@export var skin: PlayerSkin
## Оружие в руках (модель, звук выстрела); у пса — пусто
@export var weapon: WeaponData

@export_group("Combat")
@export var damage: float = 20.0
## Секунд между атаками (укус / выстрел)
@export var attack_interval: float = 0.8
## Дистанция атаки: укус — пара метров, стрельба — дальше
@export var attack_range: float = 1.6
## Замечает зомби на таком расстоянии от себя
@export var sight_range: float = 14.0
## Шанс попадания выстрелом
@export_range(0.0, 1.0, 0.05) var accuracy: float = 0.7

@export_group("Movement")
@export var walk_speed: float = 4.0
@export var run_speed: float = 6.5

@export_group("Perks")
## Пёс: раз в столько секунд приносит патроны или аптечку (0 — не приносит)
@export var fetch_interval: float = 0.0
## Крики в бою над головой
@export var callouts_ru: PackedStringArray = []
@export var callouts_en: PackedStringArray = []


func is_dog() -> bool:
	return kind == Kind.DOG
