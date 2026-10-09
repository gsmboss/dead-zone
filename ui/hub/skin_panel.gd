class_name SkinPanel
extends HubWindow
## Окно «ПЕРСОНАЖ»: 3D-превью выбранного скина, список скинов с ценой, покупка и выбор,
## аксессуары (обычные, смешные, редкие) — по одному на голову и на лицо.
## Скин и аксессуары видны от 3-го лица и другим игрокам в мультиплеере.

## Вкладки окна: персонажи и аксессуары по категориям (последняя открытая запоминается)
const TABS: PackedStringArray = ["ПЕРСОНАЖИ", "ОБЫЧНЫЕ", "СМЕШНЫЕ", "РЕДКИЕ"]

static var _tab: int = 0

var _preview: SkinPreview
var _shown_id: String = ""


func _ready() -> void:
	window_title = "ПЕРСОНАЖ"
	GameState.accessories_changed.connect(refresh)
	GameState.coins_changed.connect(_on_coins_changed)
	var selected: PlayerSkin = GameState.get_selected_skin()
	_shown_id = selected.id if selected != null else ""
	super._ready()


func _build_content() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	content.add_child(row)

	var left := VBoxContainer.new()
	row.add_child(left)
	_preview = SkinPreview.new()
	left.add_child(_preview)
	var shown: PlayerSkin = GameState.get_skin(_shown_id)
	_preview.show_skin.call_deferred(shown)
	if shown != null:
		var name_label := UIKit.label(shown.display_name, 32, left)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.modulate = UIKit.ACCENT
	UIKit.label("МОНЕТЫ: %d" % GameState.coins, 24, left).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 10)
	row.add_child(list)
	list.add_child(UIKit.tab_bar(TABS, _tab, func(index: int) -> void:
		_tab = index
		refresh()))
	if _tab == 0:
		UIKit.label("ВИД ОТ 3-ГО ЛИЦА — В НАСТРОЙКАХ ИЛИ КНОПКОЙ «ВИД»", 20, list).modulate = UIKit.DIM
		var selected: PlayerSkin = GameState.get_selected_skin()
		for skin: PlayerSkin in GameState.skins:
			list.add_child(_make_row(skin, selected != null and selected.id == skin.id))
	else:
		_build_accessories(list, _tab - 1)


func _make_row(skin: PlayerSkin, selected: bool) -> Control:
	var card := UIKit.card()
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 12)
	card.add_child(line)
	var look := UIKit.button(skin.display_name, 24)
	look.size_flags_horizontal = SIZE_EXPAND_FILL
	look.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if skin.id == _shown_id:
		look.modulate = UIKit.ACCENT
	look.pressed.connect(func() -> void:
		_shown_id = skin.id
		refresh())
	line.add_child(look)

	if selected:
		var label := UIKit.label("ВЫБРАН", 24, line)
		label.modulate = UIKit.GOOD
		label.custom_minimum_size = Vector2(220.0, 0.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif GameState.owns_skin(skin.id):
		var choose := UIKit.button("ВЫБРАТЬ", 24, 220.0)
		choose.pressed.connect(func() -> void:
			GameState.select_skin(skin.id)
			_shown_id = skin.id
			refresh())
		line.add_child(choose)
	else:
		var buy := UIKit.button("КУПИТЬ %d" % skin.price, 24, 220.0)
		buy.disabled = GameState.coins < skin.price
		buy.pressed.connect(func() -> void:
			if GameState.buy_skin(skin.id):
				Sfx.play_2d(Sfx.sounds.ui_confirm, -4.0, 1.0, 0.0)
				_shown_id = skin.id
				refresh())
		line.add_child(buy)
	return card


func _on_coins_changed(_coins: int) -> void:
	refresh()


# ---------- Аксессуары ----------

## Аксессуары одной категории (вкладка)
func _build_accessories(list: VBoxContainer, category: int) -> void:
	UIKit.label("ОДИН НА ГОЛОВУ И ОДИН НА ЛИЦО. НАЖМИ НАДЕТЫЙ — СНИМЕШЬ. ПОД ШЛЯПОЙ СВОЯ ШАПКА ПРЯЧЕТСЯ",
		20, list).modulate = UIKit.DIM
	for accessory: AccessoryData in GameState.accessories:
		if accessory.category == category:
			list.add_child(_make_accessory_row(accessory))


func _make_accessory_row(accessory: AccessoryData) -> Control:
	var card := UIKit.card()
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 12)
	card.add_child(line)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = SIZE_EXPAND_FILL
	line.add_child(texts)
	var worn: bool = GameState.is_accessory_worn(accessory.id)
	var title := UIKit.label(accessory.title, 24, texts)
	title.modulate = UIKit.GOOD if worn else AccessoryData.CATEGORY_COLORS[accessory.category]
	UIKit.label("НА ГОЛОВУ" if accessory.slot == AccessoryData.Slot.HEAD else "НА ЛИЦО", 18, texts).modulate = UIKit.DIM
	if GameState.owns_accessory(accessory.id):
		var toggle := UIKit.button("СНЯТЬ" if worn else "НАДЕТЬ", 24, 220.0)
		toggle.pressed.connect(func() -> void:
			GameState.toggle_accessory(accessory.id)
			Sfx.play_2d(Sfx.sounds.ui_confirm, -4.0, 1.1, 0.0))
		line.add_child(toggle)
	else:
		var buy := UIKit.button("КУПИТЬ %d" % accessory.price, 24, 220.0)
		buy.disabled = GameState.coins < accessory.price
		buy.pressed.connect(func() -> void:
			if GameState.buy_accessory(accessory.id):
				Sfx.play_2d(Sfx.sounds.purchase, -4.0, 1.0, 0.0)
			else:
				Sfx.error())
		line.add_child(buy)
	return card
