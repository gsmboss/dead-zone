class_name SocialPanel
extends HubWindow
## Окно «СОЦСЕТИ»: YouTube, Instagram, Telegram студии. «ПОДПИСАТЬСЯ» открывает ссылку
## (GameState.open_social), после возвращения в игру — «ЗАБРАТЬ +N» (награда один раз за каждую).
## Данные — ui/social/social_links.tres (SocialLinkList).

const ICON_SIZE: float = 84.0
## Пока ждём, что кнопку «ЗАБРАТЬ» можно включить, — проверять раз в столько секунд
const WAIT_CHECK: float = 1.0

var _wait_left: float = 0.0
## Сколько наград можно забрать — окно перестраивается, когда число меняется
var _claimable: int = -1


func _ready() -> void:
	window_title = "СОЦСЕТИ"
	GameState.progress_changed.connect(refresh)
	super._ready()


func _process(delta: float) -> void:
	# Перешёл по ссылке — через claim_delay кнопка «ЗАБРАТЬ» станет доступной
	_wait_left -= delta
	if _wait_left > 0.0:
		return
	_wait_left = WAIT_CHECK
	if _count_claimable() != _claimable:
		refresh()


func _count_claimable() -> int:
	var count: int = 0
	for link: SocialLink in GameState.social_links.links:
		if link != null and GameState.can_claim_social(link.id):
			count += 1
	return count


func _notification(what: int) -> void:
	# Вернулись из браузера / приложения соцсети
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		refresh()


func _build_content() -> void:
	_claimable = _count_claimable()
	var left: int = GameState.get_social_reward_left()
	var intro := UIKit.label("ПОДПИШИСЬ НА SALAMANDERLAB — НОВОСТИ ИГРЫ, ТРЕЙЛЕРЫ И КОДЫ ПЕРВЫМ!", 26, content)
	intro.modulate = UIKit.ACCENT
	if left > 0:
		UIKit.label(UIKit.t("За каждую подписку — награда. Осталось получить: %s") % UIKit.coins_text(left), 22,
			content).modulate = UIKit.GOOD
	else:
		UIKit.label("ВСЕ НАГРАДЫ ПОЛУЧЕНЫ. СПАСИБО, ЧТО ТЫ С НАМИ!", 22, content).modulate = UIKit.GOOD
	for link: SocialLink in GameState.social_links.links:
		if link != null:
			content.add_child(_make_card(link))


func _make_card(link: SocialLink) -> Control:
	var card := UIKit.card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	card.add_child(row)
	if link.icon != null:
		var icon := TextureRect.new()
		icon.texture = link.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	var title := UIKit.label(link.title, 30, texts)
	title.modulate = link.color.lightened(0.25)
	UIKit.label(link.description, 22, texts).modulate = UIKit.DIM
	var claimed: bool = GameState.is_social_claimed(link.id)
	var reward := UIKit.label("НАГРАДА ПОЛУЧЕНА ✓" if claimed else UIKit.t("+%s ЗА ПОДПИСКУ") % UIKit.coins_text(link.reward),
		22, texts)
	reward.modulate = UIKit.GOOD if claimed else UIKit.ACCENT

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 8)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buttons)
	var link_id: String = link.id
	if not claimed and GameState.is_social_visited(link_id):
		var claim := UIKit.button(UIKit.t("ЗАБРАТЬ +%d") % link.reward, 24, 280.0)
		claim.disabled = not GameState.can_claim_social(link_id)
		claim.modulate = UIKit.GOOD
		claim.pressed.connect(func() -> void: _claim(link_id))
		buttons.add_child(claim)
	var open := UIKit.button("ОТКРЫТЬ" if claimed or GameState.is_social_visited(link_id) else "ПОДПИСАТЬСЯ", 24, 280.0)
	open.pressed.connect(func() -> void:
		Sfx.click()
		GameState.open_social(link_id))
	buttons.add_child(open)
	return card


func _claim(link_id: String) -> void:
	var coins: int = GameState.claim_social(link_id)
	if coins > 0:
		Sfx.play_2d(Sfx.sounds.purchase, -4.0, 1.0, 0.0)
	else:
		Sfx.error()
