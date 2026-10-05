class_name BasePanel
extends HubWindow
## База: событие дня, постройки (мастерская, медпункт, склад, гараж),
## сборка предметов из лома в мастерской, улучшения машин в гараже.

const CAR_UPGRADE_NAMES: Dictionary = {
	"ram": "ТАРАН (урон сбивания +25%)",
	"engine": "ДВИГАТЕЛЬ (скорость +8%)",
}


func _ready() -> void:
	window_title = "БАЗА"
	GameState.coins_changed.connect(_on_changed)
	GameState.progress_changed.connect(refresh)
	GameState.inventory_changed.connect(refresh)
	super._ready()


func _build_content() -> void:
	var coins := UIKit.label("Монеты: %d   •   Лом: %d" % [GameState.coins, GameState.get_item_count(GameState.SCRAP_ID)], 30, content)
	coins.modulate = UIKit.ACCENT
	var event: DailyEventData = GameState.get_daily_event()
	if event != null:
		var card := UIKit.card()
		content.add_child(card)
		var box := VBoxContainer.new()
		card.add_child(box)
		UIKit.label("СОБЫТИЕ ДНЯ: %s" % event.title, 28, box).modulate = UIKit.GOOD
		UIKit.label(event.description, 22, box).modulate = UIKit.DIM

	UIKit.label("ПОСТРОЙКИ", 30, content).modulate = UIKit.ACCENT
	for building: BuildingData in GameState.buildings:
		content.add_child(_make_building_card(building))

	if GameState.has_building("workshop"):
		UIKit.label("МАСТЕРСКАЯ: СБОРКА ИЗ ЛОМА", 30, content).modulate = UIKit.ACCENT
		for item: ItemData in GameState.items:
			if item.craft_cost > 0:
				content.add_child(_make_craft_row(item))

	if GameState.has_building("garage"):
		UIKit.label("ГАРАЖ: УЛУЧШЕНИЯ МАШИН", 30, content).modulate = UIKit.ACCENT
		for stat: String in GameState.CAR_UPGRADES:
			content.add_child(_make_car_row(stat))


func _make_building_card(building: BuildingData) -> Control:
	var card := UIKit.card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	card.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(texts)
	var owned: bool = GameState.has_building(building.id)
	var title := UIKit.label(building.title, 28, texts)
	title.modulate = UIKit.GOOD if owned else Color.WHITE
	UIKit.label(building.description, 22, texts).modulate = UIKit.DIM
	var button := UIKit.button("ПОСТРОЕНО" if owned else "ПОСТРОИТЬ — %d" % building.price, 24, 300.0)
	button.disabled = owned or GameState.coins < building.price
	button.pressed.connect(func() -> void: _play(GameState.buy_building(building.id)))
	row.add_child(button)
	return card


func _make_craft_row(item: ItemData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	row.add_child(ItemIcon.create(item, 56.0))
	var count: int = GameState.get_item_count(item.id)
	var label := UIKit.label("%s  (в сумке %d / %d)" % [item.title, count, item.max_stack], 24, row)
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	var button := UIKit.button("СОБРАТЬ — %d ЛОМА" % item.craft_cost, 22, 300.0)
	button.disabled = GameState.get_item_count(GameState.SCRAP_ID) < item.craft_cost or count >= item.max_stack
	button.pressed.connect(func() -> void: _play(GameState.craft_item(item.id)))
	row.add_child(button)
	return row


func _make_car_row(stat: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	var level: int = GameState.get_car_upgrade_level(stat)
	var label := UIKit.label("%s: %d / %d" % [CAR_UPGRADE_NAMES.get(stat, stat), level, GameState.CAR_UPGRADE_MAX], 24, row)
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	var cost: int = GameState.get_car_upgrade_cost(stat)
	var button := UIKit.button("МАКС" if cost < 0 else "+  %d" % cost, 24, 200.0)
	button.disabled = cost < 0 or GameState.coins < cost
	button.pressed.connect(func() -> void: _play(GameState.upgrade_car(stat)))
	row.add_child(button)
	return row


func _play(success: bool) -> void:
	if success:
		Sfx.play_2d(Sfx.sounds.purchase, -4.0, 1.0, 0.0)
	else:
		Sfx.error()


func _on_changed(_value: int) -> void:
	refresh()
