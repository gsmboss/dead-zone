class_name ShopPanel
extends HubWindow
## Оружейная: покупка стволов и улучшение урона, магазина и перезарядки.

const STAT_NAMES: Dictionary = {
	"damage": "Урон",
	"magazine": "Магазин",
	"reload": "Перезарядка",
}


func _ready() -> void:
	window_title = "ОРУЖЕЙНАЯ"
	GameState.coins_changed.connect(_on_coins_changed)
	super._ready()


func _build_content() -> void:
	var coins := UIKit.label("Монеты: %d" % GameState.coins, 30, content)
	coins.modulate = UIKit.ACCENT
	for weapon: WeaponData in GameState.catalog.weapons:
		if weapon != null and not weapon.id.is_empty():
			content.add_child(_make_weapon_card(weapon))


func _make_weapon_card(weapon: WeaponData) -> Control:
	var card := UIKit.card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	card.add_child(box)

	var owned: bool = GameState.owns(weapon.id)
	var shown: WeaponData = GameState.get_upgraded(weapon) if owned else weapon

	var title := UIKit.label(weapon.display_name, 32, box)
	title.modulate = UIKit.GOOD if owned else Color.WHITE

	var damage_text: String = "%d" % roundi(shown.damage)
	if shown.pellets > 1:
		damage_text = "%d×%d" % [roundi(shown.damage), shown.pellets]
	var stats := UIKit.label("Урон %s  •  Магазин %d  •  Перезарядка %.1f с  •  %.1f выстр/с" % [
		damage_text, shown.magazine_size, shown.reload_time, shown.fire_rate], 22, box)
	stats.modulate = UIKit.DIM

	if not owned:
		var buy := UIKit.button("КУПИТЬ — %d" % weapon.price, 28)
		buy.disabled = GameState.coins < weapon.price
		buy.pressed.connect(func() -> void: GameState.buy_weapon(weapon))
		box.add_child(buy)
		return card

	for stat: String in GameState.UPGRADE_STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 16)
		box.add_child(row)

		var level: int = GameState.get_upgrade_level(weapon.id, stat)
		var name_label := UIKit.label("%s: %d / %d" % [STAT_NAMES[stat], level, weapon.max_upgrade_level], 24, row)
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL

		var cost: int = GameState.get_upgrade_cost(weapon, stat)
		var upgrade := UIKit.button("МАКС" if cost < 0 else "+  %d" % cost, 24, 200.0)
		upgrade.disabled = cost < 0 or GameState.coins < cost
		upgrade.pressed.connect(func() -> void: GameState.upgrade_weapon(weapon, stat))
		row.add_child(upgrade)
	return card


func _on_coins_changed(_coins: int) -> void:
	refresh()
