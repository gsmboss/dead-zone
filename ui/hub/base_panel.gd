class_name BasePanel
extends HubWindow
## База: вкладки УБЕЖИЩЕ (уровень и расширение, жильцы, настроение, провизия и обед, касса лагеря,
## радио), ПОСТРОЙКИ, ОБУСТРОЙСТВО (DecorData), МАСТЕРСКАЯ (сборка из лома), ГАРАЖ (улучшения машин).
## Данные и логика — GameState.shelter (ShelterState), параметры — base/shelter_config.tres.

const CAR_UPGRADE_NAMES: Dictionary = {
	"ram": "ТАРАН (урон сбивания +25%)",
	"engine": "ДВИГАТЕЛЬ (скорость +8%)",
}
const TABS: PackedStringArray = ["УБЕЖИЩЕ", "ПОСТРОЙКИ", "ОБУСТРОЙСТВО", "МАСТЕРСКАЯ", "ГАРАЖ"]
const BAR_SIZE: Vector2 = Vector2(320.0, 22.0)
const SWATCH_SIZE: Vector2 = Vector2(18.0, 72.0)

## Последняя открытая вкладка
static var _tab: int = 0

var _cash_label: Label
var _cash_button: Button
var _cash_left: float = 0.0


func _ready() -> void:
	window_title = "БАЗА"
	GameState.shelter.tick()
	GameState.coins_changed.connect(_on_changed)
	GameState.progress_changed.connect(refresh)
	GameState.inventory_changed.connect(refresh)
	GameState.shelter_changed.connect(refresh)
	super._ready()


func _process(delta: float) -> void:
	# Касса копится на глазах
	_cash_left -= delta
	if _cash_left > 0.0 or _cash_label == null or not is_instance_valid(_cash_label):
		return
	_cash_left = 1.0
	_update_cash()


func _build_content() -> void:
	_cash_label = null
	_cash_button = null
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 24)
	content.add_child(top)
	var coins := UIKit.label(UIKit.t("Монеты: %d   •   Лом: %d") % [GameState.coins,
		GameState.get_item_count(GameState.SCRAP_ID)], 28, top)
	coins.modulate = UIKit.ACCENT
	content.add_child(UIKit.tab_bar(TABS, _tab, func(index: int) -> void:
		_tab = index
		refresh()))
	match _tab:
		0:
			_build_shelter()
		1:
			_build_buildings()
		2:
			_build_decor()
		3:
			_build_workshop()
		_:
			_build_garage()


# ---------- УБЕЖИЩЕ ----------

func _build_shelter() -> void:
	var shelter: ShelterState = GameState.shelter
	var config: ShelterConfig = shelter.config
	# Люди, настроение, провизия
	var stats := _card()
	var stats_box: VBoxContainer = stats.get_child(0)
	var level_title := UIKit.label(UIKit.t("УРОВЕНЬ %d: %s") % [shelter.level, UIKit.t(config.get_title(shelter.level))],
		30, stats_box)
	level_title.modulate = UIKit.ACCENT
	var population: int = shelter.get_population()
	var people := UIKit.label(UIKit.t("ЖИЛЬЦЫ: %d / %d МЕСТ") % [population, shelter.get_capacity()], 26, stats_box)
	if shelter.is_crowded():
		people.text += "   " + UIKit.t("ТЕСНО! НАСТРОЕНИЕ НИЖЕ — РАСШИРЬ УБЕЖИЩЕ")
		people.modulate = Color(1.0, 0.55, 0.45)
	var mood_row := HBoxContainer.new()
	mood_row.add_theme_constant_override(&"separation", 16)
	stats_box.add_child(mood_row)
	UIKit.label(UIKit.t("НАСТРОЕНИЕ: %s") % UIKit.t(shelter.get_mood_text()), 26, mood_row).modulate = \
		shelter.get_mood_color()
	mood_row.add_child(_bar(shelter.get_morale(), 100.0, shelter.get_mood_color(), shelter.get_max_morale()))
	UIKit.label("%d / %d" % [roundi(shelter.get_morale()), roundi(shelter.get_max_morale())], 22, mood_row) \
		.modulate = UIKit.DIM
	UIKit.label(UIKit.t("Потолок настроения растёт от уюта: обустройство и постройки (сейчас уют %d)") \
		% shelter.get_comfort(), 20, stats_box).modulate = UIKit.DIM
	var bonus_active: bool = shelter.get_reward_bonus() > 1.0
	var bonus := UIKit.label(UIKit.t("НАСТРОЕНИЕ %d+: +%d%% МОНЕТ ЗА МИССИИ") % [roundi(config.morale_reward_threshold),
		roundi(config.morale_reward_bonus * 100.0)] + ("  ✓" if bonus_active else ""), 22, stats_box)
	bonus.modulate = UIKit.GOOD if bonus_active else UIKit.DIM

	# Обед и провизия
	var food_card := _card()
	var food_box: VBoxContainer = food_card.get_child(0)
	var food_title := UIKit.label(UIKit.t("ПРОВИЗИЯ: %d ЯЩИКОВ") % shelter.food, 28, food_box)
	food_title.modulate = UIKit.ACCENT
	var per_crate: int = config.canteen_people_per_crate if GameState.has_building("canteen") else config.people_per_crate
	UIKit.label(UIKit.t("Обед раз в день: %d ящ. (ящик кормит %d человек). День без обеда — настроение −%d") % [
		shelter.get_meal_cost(), per_crate, roundi(config.morale_hungry_day)], 22, food_box).modulate = UIKit.DIM
	if GameState.has_building("garden"):
		UIKit.label(UIKit.t("Огород: +%d ящ. каждый день") % config.garden_food_per_day, 22, food_box).modulate = UIKit.GOOD
	UIKit.label(UIKit.t("За победу в миссии: +%d ящ. и ещё по ящику за звезду") % config.food_per_win, 22,
		food_box).modulate = UIKit.DIM
	var food_row := HFlowContainer.new()
	food_row.add_theme_constant_override(&"h_separation", 12)
	food_row.add_theme_constant_override(&"v_separation", 12)
	food_box.add_child(food_row)
	var feed := UIKit.button("ОБЕД БЫЛ ✓" if shelter.is_fed_today() else UIKit.t("НАКОРМИТЬ (%d)") % shelter.get_meal_cost(),
		26, 300.0)
	feed.disabled = not shelter.can_feed()
	if shelter.can_feed():
		feed.modulate = UIKit.GOOD
	feed.pressed.connect(func() -> void: _play(shelter.feed()))
	food_row.add_child(feed)
	for pack in mini(config.food_pack_crates.size(), config.food_pack_prices.size()):
		var buy := UIKit.button(UIKit.t("+%d ЯЩ. — %d") % [config.food_pack_crates[pack], config.food_pack_prices[pack]],
			24, 220.0)
		buy.disabled = GameState.coins < config.food_pack_prices[pack] or shelter.food >= config.max_food
		var index: int = pack
		buy.pressed.connect(func() -> void: _play(shelter.buy_food(index)))
		food_row.add_child(buy)

	# Касса
	var cash_card := _card()
	var cash_box: VBoxContainer = cash_card.get_child(0)
	var cash_row := HBoxContainer.new()
	cash_row.add_theme_constant_override(&"separation", 16)
	cash_box.add_child(cash_row)
	_cash_label = UIKit.label("", 26, cash_row)
	_cash_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_cash_button = UIKit.button("", 24, 260.0)
	_cash_button.pressed.connect(func() -> void: _play(shelter.collect_income() > 0))
	cash_row.add_child(_cash_button)
	UIKit.label(UIKit.t("Жильцы работают: монеты копятся до %d ч. Больше людей и выше настроение — больше доход") \
		% roundi(config.get_income_hours(shelter.level)), 20, cash_box).modulate = UIKit.DIM
	_update_cash()

	# Радио
	var radio_card := _card()
	var radio_box: VBoxContainer = radio_card.get_child(0)
	var radio_row := HBoxContainer.new()
	radio_row.add_theme_constant_override(&"separation", 16)
	radio_box.add_child(radio_row)
	var radio_texts := VBoxContainer.new()
	radio_texts.size_flags_horizontal = SIZE_EXPAND_FILL
	radio_row.add_child(radio_texts)
	UIKit.label("РАДИО: НОВЫЕ ЖИЛЬЦЫ", 26, radio_texts).modulate = UIKit.ACCENT
	UIKit.label(UIKit.t("Позвать выжившего: %d монет и %d ящ. провизии. Сегодня ещё: %d") % [config.recruit_price,
		config.recruit_food, shelter.get_recruits_left()], 22, radio_texts).modulate = UIKit.DIM
	var block: String = shelter.get_recruit_block()
	if not block.is_empty():
		UIKit.label(block, 22, radio_texts).modulate = Color(1.0, 0.6, 0.45)
	var recruit := UIKit.button("ПОЗВАТЬ", 26, 220.0)
	recruit.disabled = not block.is_empty()
	recruit.pressed.connect(func() -> void: _play(shelter.recruit()))
	radio_row.add_child(recruit)

	# Расширение
	var grow_card := _card()
	var grow_box: VBoxContainer = grow_card.get_child(0)
	UIKit.label(config.get_description(shelter.level), 22, grow_box).modulate = UIKit.DIM
	if shelter.is_max_level():
		UIKit.label("УБЕЖИЩЕ РАСШИРЕНО ДО КОНЦА — ЭТО КРЕПОСТЬ!", 26, grow_box).modulate = UIKit.GOOD
		return
	var next: int = shelter.level + 1
	var grow_row := HBoxContainer.new()
	grow_row.add_theme_constant_override(&"separation", 16)
	grow_box.add_child(grow_row)
	var grow_texts := VBoxContainer.new()
	grow_texts.size_flags_horizontal = SIZE_EXPAND_FILL
	grow_row.add_child(grow_texts)
	UIKit.label(UIKit.t("РАСШИРИТЬ ДО «%s»") % UIKit.t(config.get_title(next)), 28, grow_texts).modulate = UIKit.ACCENT
	UIKit.label(config.get_description(next), 22, grow_texts).modulate = UIKit.DIM
	var gains := UIKit.t("Мест для жильцов: %d → %d. Касса копится %d ч.") % [shelter.get_capacity(),
		config.get_capacity(next), roundi(config.get_income_hours(next))]
	if config.get_half_size(next) > shelter.get_half_size():
		gains += " " + UIKit.t("Двор больше: %d × %d м.") % [roundi(config.get_half_size(next) * 2.0),
			roundi(config.get_half_size(next) * 2.0)]
	UIKit.label(gains, 22, grow_texts).modulate = UIKit.GOOD
	var scrap: int = shelter.get_next_scrap()
	var cost_text: String = UIKit.t("%d МОНЕТ") % shelter.get_next_price()
	if scrap > 0:
		cost_text += UIKit.t(" + %d ЛОМА") % scrap
	var grow := UIKit.button(cost_text, 24, 300.0)
	grow.disabled = not shelter.can_upgrade()
	grow.pressed.connect(func() -> void: _play(shelter.upgrade()))
	grow_row.add_child(grow)


func _update_cash() -> void:
	if _cash_label == null or not is_instance_valid(_cash_label):
		return
	var shelter: ShelterState = GameState.shelter
	var pending: int = floori(shelter.get_pending_income())
	_cash_label.text = UIKit.t("КАССА ЛАГЕРЯ: %d / %d   (%d В ЧАС)") % [pending, floori(shelter.get_income_cap()),
		roundi(shelter.get_income_rate())]
	_cash_button.text = UIKit.t("ЗАБРАТЬ +%d") % pending
	_cash_button.disabled = pending <= 0


# ---------- ПОСТРОЙКИ ----------

func _build_buildings() -> void:
	var event: DailyEventData = GameState.get_daily_event()
	if event != null:
		var card := _card()
		var box: VBoxContainer = card.get_child(0)
		UIKit.label(UIKit.t("СОБЫТИЕ ДНЯ: %s") % UIKit.t(event.title), 26, box).modulate = UIKit.GOOD
		UIKit.label(event.description, 22, box).modulate = UIKit.DIM
	for building: BuildingData in GameState.buildings:
		content.add_child(_make_building_card(building))


func _make_building_card(building: BuildingData) -> Control:
	var owned: bool = GameState.has_building(building.id)
	var locked: bool = GameState.shelter.level < building.required_level
	var extra := PackedStringArray()
	if building.comfort > 0:
		extra.append(UIKit.t("УЮТ +%d") % building.comfort)
	var button_text: String = "ПОСТРОЕНО"
	if not owned:
		button_text = UIKit.t("НУЖЕН «%s»") % UIKit.t(GameState.shelter.config.get_title(building.required_level)) \
			if locked else UIKit.t("ПОСТРОИТЬ — %d") % building.price
	var button := UIKit.button(button_text, 24, 300.0)
	button.disabled = owned or locked or GameState.coins < building.price
	button.pressed.connect(func() -> void: _play(GameState.buy_building(building.id)))
	return _item_card(building.title, building.description, "   ".join(extra), building.icon_color, owned, button)


# ---------- ОБУСТРОЙСТВО ----------

func _build_decor() -> void:
	var shelter: ShelterState = GameState.shelter
	UIKit.label(UIKit.t("Уют поднимает потолок настроения жильцов. Сейчас уют %d, потолок %d") % [shelter.get_comfort(),
		roundi(shelter.get_max_morale())], 22, content).modulate = UIKit.DIM
	for zone in DecorData.ZONE_NAMES.size():
		UIKit.label(DecorData.ZONE_NAMES[zone], 28, content).modulate = UIKit.ACCENT
		for item: DecorData in shelter.decor_list.decor:
			if item != null and item.zone == zone:
				content.add_child(_make_decor_card(item))


func _make_decor_card(item: DecorData) -> Control:
	var shelter: ShelterState = GameState.shelter
	var owned: bool = shelter.owns_decor(item.id)
	var locked: bool = shelter.level < item.required_level
	var button_text: String = "КУПЛЕНО"
	if not owned:
		button_text = UIKit.t("НУЖЕН «%s»") % UIKit.t(shelter.config.get_title(item.required_level)) \
			if locked else UIKit.t("КУПИТЬ — %d") % item.price
	var button := UIKit.button(button_text, 24, 300.0)
	button.disabled = owned or locked or GameState.coins < item.price
	button.pressed.connect(func() -> void: _play(shelter.buy_decor(item.id)))
	return _item_card(item.title, item.description, UIKit.t("УЮТ +%d") % item.comfort, item.icon_color, owned, button)


# ---------- МАСТЕРСКАЯ и ГАРАЖ ----------

func _build_workshop() -> void:
	if not GameState.has_building("workshop"):
		_need_building("workshop")
		return
	UIKit.label("СБОРКА ИЗ ЛОМА", 28, content).modulate = UIKit.ACCENT
	for item: ItemData in GameState.items:
		if item.craft_cost > 0:
			content.add_child(_make_craft_row(item))


func _build_garage() -> void:
	if not GameState.has_building("garage"):
		_need_building("garage")
		return
	UIKit.label("УЛУЧШЕНИЯ МАШИН", 28, content).modulate = UIKit.ACCENT
	for stat: String in GameState.CAR_UPGRADES:
		content.add_child(_make_car_row(stat))


func _need_building(building_id: String) -> void:
	var building: BuildingData = GameState.get_building(building_id)
	if building == null:
		return
	UIKit.label(UIKit.t("Сначала построй: %s") % UIKit.t(building.title), 26, content).modulate = UIKit.DIM
	content.add_child(_make_building_card(building))


func _make_craft_row(item: ItemData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	row.add_child(ItemIcon.create(item, 56.0))
	var count: int = GameState.get_item_count(item.id)
	var label := UIKit.label(UIKit.t("%s  (в сумке %d / %d)") % [UIKit.t(item.title), count, item.max_stack], 24, row)
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	var button := UIKit.button(UIKit.t("СОБРАТЬ — %d ЛОМА") % item.craft_cost, 22, 300.0)
	button.disabled = GameState.get_item_count(GameState.SCRAP_ID) < item.craft_cost or count >= item.max_stack
	button.pressed.connect(func() -> void: _play(GameState.craft_item(item.id)))
	row.add_child(button)
	return row


func _make_car_row(stat: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	var level: int = GameState.get_car_upgrade_level(stat)
	var label := UIKit.label("%s: %d / %d" % [UIKit.t(str(CAR_UPGRADE_NAMES.get(stat, stat))), level, GameState.CAR_UPGRADE_MAX], 24, row)
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	var cost: int = GameState.get_car_upgrade_cost(stat)
	var button := UIKit.button("МАКС" if cost < 0 else "+  %d" % cost, 24, 200.0)
	button.disabled = cost < 0 or GameState.coins < cost
	button.pressed.connect(func() -> void: _play(GameState.upgrade_car(stat)))
	row.add_child(button)
	return row


# ---------- Общее ----------

## Карточка с вертикальным списком внутри (первый ребёнок карточки)
func _card() -> PanelContainer:
	var card := UIKit.card()
	content.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	card.add_child(box)
	return card


## Карточка постройки или обустройства: цветная полоска, название, описание, приписка, кнопка
func _item_card(title_text: String, description: String, extra: String, color: Color, owned: bool,
		button: Button) -> Control:
	var card := UIKit.card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	card.add_child(row)
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = SWATCH_SIZE
	row.add_child(swatch)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(texts)
	var title := UIKit.label(title_text, 28, texts)
	title.modulate = UIKit.GOOD if owned else Color.WHITE
	UIKit.label(description, 22, texts).modulate = UIKit.DIM
	if not extra.is_empty():
		UIKit.label(extra, 20, texts).modulate = UIKit.ACCENT
	row.add_child(button)
	return card


## Полоска значения (настроение) с отметкой потолка
func _bar(value: float, max_value: float, color: Color, cap: float) -> Control:
	var back := Panel.new()
	back.custom_minimum_size = BAR_SIZE
	back.size_flags_vertical = SIZE_SHRINK_CENTER
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	back_style.set_corner_radius_all(6)
	back.add_theme_stylebox_override(&"panel", back_style)
	var fill := Panel.new()
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(6)
	fill.add_theme_stylebox_override(&"panel", fill_style)
	fill.position = Vector2.ZERO
	fill.size = Vector2(BAR_SIZE.x * clampf(value / max_value, 0.0, 1.0), BAR_SIZE.y)
	back.add_child(fill)
	var mark := ColorRect.new()
	mark.color = Color(1.0, 1.0, 1.0, 0.85)
	mark.position = Vector2(BAR_SIZE.x * clampf(cap / max_value, 0.0, 1.0) - 1.0, -3.0)
	mark.size = Vector2(3.0, BAR_SIZE.y + 6.0)
	back.add_child(mark)
	return back


func _play(success: bool) -> void:
	if success:
		Sfx.play_2d(Sfx.sounds.purchase, -4.0, 1.0, 0.0)
	else:
		Sfx.error()


func _on_changed(_value: int) -> void:
	refresh()
