class_name SkinPanel
extends HubWindow
## Окно «ПЕРСОНАЖ»: 3D-превью выбранного скина, список скинов с ценой, покупка и выбор.
## Скин виден от 3-го лица и другим игрокам в мультиплеере.

var _preview: SkinPreview
var _shown_id: String = ""


func _ready() -> void:
	window_title = "ПЕРСОНАЖ"
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
	UIKit.label("ВИД ОТ 3-ГО ЛИЦА — В НАСТРОЙКАХ ИЛИ КНОПКОЙ «ВИД»", 20, list).modulate = UIKit.DIM
	var selected: PlayerSkin = GameState.get_selected_skin()
	for skin: PlayerSkin in GameState.skins:
		list.add_child(_make_row(skin, selected != null and selected.id == skin.id))


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
