class_name ItemData
extends Resource
## Предмет инвентаря (аптечка, набор патронов). Каждый — отдельный .tres.

enum Effect { HEAL, AMMO }

## Уникальный id для сохранений, латиницей
@export var id: String = ""
@export var title: String = "АПТЕЧКА"
@export_multiline var description: String = ""
@export var effect: Effect = Effect.HEAL
## HEAL: очки здоровья; AMMO: доля от максимального запаса каждого ствола
@export var amount: float = 40.0
@export_range(1, 99) var max_stack: int = 5
## Цена в оружейной (0 — не продаётся)
@export var price: int = 50
@export var icon_color: Color = Color(0.85, 0.15, 0.12)


## Применить к игроку. false — предмет сейчас бесполезен (полное здоровье / патроны)
func apply(player: Player) -> bool:
	if player == null:
		return false
	match effect:
		Effect.HEAL:
			if player.health == null or player.health.is_dead \
					or player.health.current >= player.health.max_health:
				return false
			player.health.heal(amount)
			return true
		Effect.AMMO:
			return player.weapon_manager != null and player.weapon_manager.add_reserve_ammo(amount)
	return false
