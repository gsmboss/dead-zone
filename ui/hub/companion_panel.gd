class_name CompanionPanel
extends HubWindow
## Окно «НАПАРНИК»: 3D-превью, список напарников (пёс, выжившие из сюжета), покупка, «ВЗЯТЬ С СОБОЙ»,
## «ОТПУСТИТЬ». Напарник идёт с игроком в миссии и ходит рядом в убежище.

var _preview: SkinPreview
var _shown_id: String = ""


func _ready() -> void:
	window_title = "НАПАРНИК"
	GameState.coins_changed.connect(_on_changed.unbind(1))
	GameState.companion_changed.connect(_on_changed)
	var selected: CompanionData = GameState.get_selected_companion()
	_shown_id = selected.id if selected != null else (GameState.companions[0].id if not GameState.companions.is_empty() else "")
	super._ready()


func _on_changed() -> void:
	refresh()


func _build_content() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	content.add_child(row)

	var left := VBoxContainer.new()
	row.add_child(left)
	_preview = SkinPreview.new()
	left.add_child(_preview)
	var shown: CompanionData = GameState.get_companion(_shown_id)
	if shown != null:
		_preview.show_companion.call_deferred(shown)
		var name_label := UIKit.label(shown.title, 30, left)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.modulate = UIKit.ACCENT
	UIKit.label(UIKit.t("МОНЕТЫ: %d") % GameState.coins, 24, left).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 10)
	row.add_child(list)
	var hint := UIKit.label("НАПАРНИК ИДЁТ С ТОБОЙ В МИССИИ (НЕ ПО СЕТИ): САМ НАХОДИТ ЗОМБИ И АТАКУЕТ", 20, list)
	hint.modulate = UIKit.DIM
	var selected: CompanionData = GameState.get_selected_companion()
	for companion: CompanionData in GameState.companions:
		list.add_child(_make_card(companion, selected != null and selected.id == companion.id))
	if selected != null:
		var dismiss := UIKit.button("ИДТИ ОДНОМУ (ОТПУСТИТЬ НАПАРНИКА)", 22)
		dismiss.pressed.connect(func() -> void: GameState.select_companion(""))
		list.add_child(dismiss)


func _make_card(companion: CompanionData, selected: bool) -> Control:
	var card := UIKit.card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 12)
	box.add_child(head)
	var look := UIKit.button(companion.title, 26)
	look.size_flags_horizontal = SIZE_EXPAND_FILL
	look.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if companion.id == _shown_id:
		look.modulate = UIKit.ACCENT
	look.pressed.connect(func() -> void:
		_shown_id = companion.id
		refresh())
	head.add_child(look)
	head.add_child(_make_action(companion, selected))

	var description := UIKit.label(companion.description, 20, box)
	description.modulate = UIKit.DIM
	var stats: String = UIKit.t("УКУС %d  •  ПРИНОСИТ ПРИПАСЫ") % roundi(companion.damage) if companion.is_dog() \
		else UIKit.t("УРОН %d  •  %.1f ВЫСТР/С  •  ДО %d М") % [roundi(companion.damage),
			1.0 / maxf(companion.attack_interval, 0.05), roundi(companion.attack_range)]
	UIKit.label(stats, 20, box).modulate = UIKit.GOOD if selected else Color.WHITE
	return card


## Кнопка справа: открыть сюжетом / купить / взять с собой / в команде
func _make_action(companion: CompanionData, selected: bool) -> Button:
	if selected:
		var current := UIKit.button("В КОМАНДЕ ✓", 22, 240.0)
		current.disabled = true
		return current
	if not GameState.is_companion_unlocked(companion.id):
		var chapter: ChapterData = GameState.campaign.find(companion.unlock_chapter)
		var locked := UIKit.button(UIKit.t("СЮЖЕТ: «%s»") % (UIKit.t(chapter.title) if chapter != null else "?"),
			20, 240.0)
		locked.disabled = true
		return locked
	if GameState.owns_companion(companion.id):
		var take := UIKit.button("ВЗЯТЬ С СОБОЙ", 22, 240.0)
		take.modulate = UIKit.GOOD
		take.pressed.connect(GameState.select_companion.bind(companion.id))
		return take
	var buy := UIKit.button(UIKit.t("КУПИТЬ %d") % companion.price, 22, 240.0)
	buy.disabled = GameState.coins < companion.price
	buy.pressed.connect(func() -> void:
		if GameState.buy_companion(companion.id):
			Sfx.play_2d(Sfx.sounds.purchase, -4.0, 1.0, 0.0)
		else:
			Sfx.error())
	return buy
