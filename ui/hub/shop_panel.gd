class_name ShopPanel
extends HubWindow
## Оружейная: улучшения выжившего (здоровье, броня), покупка стволов,
## улучшение урона, магазина и перезарядки и обвесы (AttachmentData).

const STAT_NAMES: Dictionary = {
	"damage": "Урон",
	"magazine": "Магазин",
	"reload": "Перезарядка",
}
const PLAYER_STAT_NAMES: Dictionary = {
	"health": "Здоровье",
	"armor": "Броня",
}

## У какого ствола раскрыт список обвесов (переживает refresh и повторное открытие)
static var _open_attachments: String = ""


func _ready() -> void:
	window_title = "ОРУЖЕЙНАЯ"
	GameState.coins_changed.connect(_on_coins_changed)
	super._ready()


func _build_content() -> void:
	var coins := UIKit.label(UIKit.t("Монеты: %d") % GameState.coins, 30, content)
	coins.modulate = UIKit.ACCENT
	# Снаряжение (факел) — сразу под монетами, чтобы его было видно
	content.add_child(_make_gear_card())
	content.add_child(_make_survivor_card())
	content.add_child(_make_supplies_card())
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

	# Шапка: вращающаяся 3D-модель и название с характеристиками
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 18)
	box.add_child(header)
	var preview := WeaponPreview.new()
	header.add_child(preview)
	preview.setup(weapon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(texts)

	var title := UIKit.label(weapon.display_name, 32, texts)
	title.modulate = UIKit.GOOD if owned else Color.WHITE

	var damage_text: String = "%d" % roundi(shown.damage)
	if shown.pellets > 1:
		damage_text = "%d×%d" % [roundi(shown.damage), shown.pellets]
	var stats_text: String = UIKit.t("Урон %s  •  %.1f удара/с  •  ближний бой") % [damage_text, shown.fire_rate] \
		if shown.is_melee else UIKit.t("Урон %s  •  Магазин %d  •  Перезарядка %.1f с  •  %.1f выстр/с") % [
			damage_text, shown.magazine_size, shown.reload_time, shown.fire_rate]
	var stats := UIKit.label(stats_text, 22, texts)
	stats.modulate = UIKit.DIM

	if not owned:
		var buy := UIKit.button(UIKit.t("КУПИТЬ — %d") % weapon.price, 28)
		buy.disabled = GameState.coins < weapon.price
		buy.pressed.connect(func() -> void: _play_result(GameState.buy_weapon(weapon)))
		box.add_child(buy)
		return card

	for stat: String in weapon.get_upgrade_stats():
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 16)
		box.add_child(row)

		var level: int = GameState.get_upgrade_level(weapon.id, stat)
		var name_label := UIKit.label("%s: %d / %d" % [UIKit.t(STAT_NAMES[stat]), level, weapon.max_upgrade_level], 24, row)
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL

		var cost: int = GameState.get_upgrade_cost(weapon, stat)
		var upgrade := UIKit.button("МАКС" if cost < 0 else "+  %d" % cost, 24, 200.0)
		upgrade.disabled = cost < 0 or GameState.coins < cost
		upgrade.pressed.connect(func() -> void: _play_result(GameState.upgrade_weapon(weapon, stat)))
		row.add_child(upgrade)
	_add_attachments(weapon, box)
	return card


## Обвесы ствола: кнопка раскрывает список по слотам (купить / поставить / снять)
func _add_attachments(weapon: WeaponData, box: VBoxContainer) -> void:
	var fitting: Array[AttachmentData] = GameState.get_attachments_for(weapon)
	if fitting.is_empty():
		return
	var opened: bool = _open_attachments == weapon.id
	var on_count: int = GameState.get_attachments_on(weapon).size()
	var toggle := UIKit.button("%s (%d)  %s" % [UIKit.t("ОБВЕСЫ"), on_count, "▲" if opened else "▼"], 24)
	toggle.modulate = UIKit.ACCENT
	toggle.pressed.connect(func() -> void:
		Sfx.click()
		_open_attachments = "" if _open_attachments == weapon.id else weapon.id
		refresh())
	box.add_child(toggle)
	if not opened:
		return
	var last_slot: int = -1
	for attachment: AttachmentData in fitting:
		if attachment.slot != last_slot:
			last_slot = attachment.slot
			var slot_label := UIKit.label(AttachmentData.SLOT_NAMES.get(attachment.slot, ""), 20, box)
			slot_label.modulate = UIKit.DIM
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 16)
		box.add_child(row)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(texts)
		var owned: bool = GameState.owns_attachment(weapon.id, attachment.id)
		var on: bool = GameState.is_attachment_on(weapon.id, attachment.id)
		var title := UIKit.label(attachment.title, 24, texts)
		title.modulate = UIKit.GOOD if on else Color.WHITE
		UIKit.label(attachment.description, 18, texts).modulate = UIKit.DIM
		var button: Button
		if not owned:
			var price: int = attachment.get_price(weapon)
			button = UIKit.button("+  %d" % price, 22, 200.0)
			button.disabled = GameState.coins < price
			button.pressed.connect(func() -> void: _play_result(GameState.buy_attachment(weapon, attachment)))
		else:
			button = UIKit.button("СНЯТЬ" if on else "ПОСТАВИТЬ", 22, 200.0)
			button.pressed.connect(func() -> void:
				Sfx.click()
				GameState.toggle_attachment(weapon, attachment)
				refresh())
		row.add_child(button)


## Карточка «ВЫЖИВШИЙ»: здоровье и броня игрока
func _make_survivor_card() -> Control:
	var card := UIKit.card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	card.add_child(box)

	UIKit.label("ВЫЖИВШИЙ", 32, box).modulate = UIKit.GOOD
	UIKit.label(UIKit.t("Здоровье %d  •  Броня %d%%") % [
		roundi(GameState.get_player_max_health()), roundi(GameState.get_player_armor() * 100.0)],
		22, box).modulate = UIKit.DIM

	for stat: String in GameState.PLAYER_UPGRADES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 16)
		box.add_child(row)
		var level: int = GameState.get_player_upgrade_level(stat)
		var name_label := UIKit.label("%s: %d / %d" % [
			UIKit.t(PLAYER_STAT_NAMES[stat]), level, GameState.player_stats.max_level], 24, row)
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL
		var cost: int = GameState.get_player_upgrade_cost(stat)
		var upgrade := UIKit.button("МАКС" if cost < 0 else "+  %d" % cost, 24, 200.0)
		upgrade.disabled = cost < 0 or GameState.coins < cost
		upgrade.pressed.connect(func() -> void: _play_result(GameState.upgrade_player(stat)))
		row.add_child(upgrade)
	return card


## Припасы в сумку: аптечки и патроны
func _make_supplies_card() -> Control:
	var card := UIKit.card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	card.add_child(box)
	UIKit.label("ПРИПАСЫ В СУМКУ", 32, box).modulate = UIKit.GOOD
	for item: ItemData in GameState.items:
		if item.price <= 0:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 16)
		box.add_child(row)
		row.add_child(ItemIcon.create(item, 56.0))
		var count: int = GameState.get_item_count(item.id)
		var name_label := UIKit.label("%s: %d / %d" % [UIKit.t(item.title), count, item.max_stack], 24, row)
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL
		var full: bool = count >= item.max_stack
		var buy := UIKit.button("ПОЛНО" if full else "+  %d" % item.price, 24, 200.0)
		buy.disabled = full or GameState.coins < item.price
		buy.pressed.connect(func() -> void:
			_play_result(GameState.buy_item(item.id))
			refresh())
		row.add_child(buy)
	return card


## Снаряжение: покупается один раз (факел)
func _make_gear_card() -> Control:
	var card := UIKit.card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	card.add_child(box)
	UIKit.label("СНАРЯЖЕНИЕ", 32, box).modulate = UIKit.GOOD
	for item: GearData in GameState.gear:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 16)
		box.add_child(row)
		if item.id == "torch":
			row.add_child(TorchPreview.new())
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(texts)
		UIKit.label(item.title, 30, texts).modulate = UIKit.ACCENT
		UIKit.label(item.description, 20, texts).modulate = UIKit.DIM
		var owned: bool = GameState.owns_gear(item.id)
		if owned and item.id == "torch":
			UIKit.label(UIKit.t("КУПЛЕН • %s") % (UIKit.t("ЗАЖИГАЕТСЯ САМ НОЧЬЮ") if Settings.torch_auto else UIKit.t("ЗАЖИГАТЬ КНОПКОЙ ФАКЕЛ")),
				20, texts).modulate = UIKit.GOOD
		var buy := UIKit.button("ЕСТЬ" if owned else UIKit.t("КУПИТЬ %d") % item.price, 24, 220.0)
		buy.disabled = owned or GameState.coins < item.price
		buy.pressed.connect(func() -> void:
			_play_result(GameState.buy_gear(item.id))
			refresh())
		row.add_child(buy)
	return card


func _play_result(success: bool) -> void:
	if success:
		Sfx.play_2d(Sfx.sounds.purchase, -4.0, 1.0, 0.0)
	else:
		Sfx.error()


func _on_coins_changed(_coins: int) -> void:
	refresh()
