class_name InventoryPanel
extends HubWindow
## Сумка: предметы игрока, кнопка «ИСПОЛЬЗОВАТЬ». Открывается из меню паузы и кнопкой в HUD.


func _ready() -> void:
	window_title = "СУМКА"
	process_mode = PROCESS_MODE_ALWAYS
	GameState.inventory_changed.connect(refresh)
	super._ready()


func _build_content() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	var has_any: bool = false
	for item: ItemData in GameState.items:
		var count: int = GameState.get_item_count(item.id)
		if count <= 0:
			continue
		has_any = true
		content.add_child(_make_item_card(item, count, player))
	if not has_any:
		UIKit.label("Сумка пуста. Ненужные сейчас аптечки и патроны с земли попадают сюда, "
			+ UIKit.t("а купить их можно в оружейной"), 24, content).modulate = UIKit.DIM


func _make_item_card(item: ItemData, count: int, player: Player) -> Control:
	var card := UIKit.card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	card.add_child(row)
	row.add_child(ItemIcon.create(item, 64.0))

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(texts)
	UIKit.label("%s  ×%d" % [UIKit.t(item.title), count], 28, texts)
	UIKit.label(item.description, 22, texts).modulate = UIKit.DIM

	if item.is_throwable() or item.effect == ItemData.Effect.MATERIAL:
		var hint := UIKit.label("КНОПКА ГРАНАТА" if item.is_throwable() else "ДЛЯ МАСТЕРСКОЙ", 22, row)
		hint.modulate = UIKit.ACCENT
		hint.custom_minimum_size = Vector2(260.0, 0.0)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return card

	var use := UIKit.button("ИСПОЛЬЗОВАТЬ", 24, 260.0)
	use.disabled = player == null
	use.pressed.connect(func() -> void:
		if GameState.use_item(item.id, player):
			Sfx.play_2d(Sfx.sounds.pickup, -2.0, 1.0, 0.0)
		else:
			Sfx.error())
	row.add_child(use)
	return card
