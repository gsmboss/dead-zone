extends Node
## Автозагрузка "Ads": реклама AdMob через плагин Poing Studios (addons/admob).
## - Согласие GDPR (UMP) при запуске, потом инициализация SDK.
## - Баннер — только в убежище (show_banner/hide_banner из HubHUD), сверху по центру.
## - Межстраничная — после миссии, не чаще каждой INTERSTITIAL_EVERY миссии и раз в INTERSTITIAL_COOLDOWN с.
## - С вознаграждением — воскрешение и x2 монеты (show_rewarded).
## В отладочной сборке — тестовые блоки Google (свою рекламу нажимать нельзя: блокировка аккаунта).
## На ПК без редактора плагина нет — всё молча пропускается, игра работает без рекламы.

const BANNER_ID: String = "ca-app-pub-5010684167263731/2738655967"
const INTERSTITIAL_ID: String = "ca-app-pub-5010684167263731/5927926089"
const REWARDED_ID: String = "ca-app-pub-5010684167263731/3700383840"
const TEST_BANNER_ID: String = "ca-app-pub-3940256099942544/6300978111"
const TEST_INTERSTITIAL_ID: String = "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED_ID: String = "ca-app-pub-3940256099942544/5224354917"

## Межстраничная — после каждой такой по счёту миссии и не чаще чем раз в столько секунд
const INTERSTITIAL_EVERY: int = 2
const INTERSTITIAL_COOLDOWN: float = 120.0
## Повторная загрузка после ошибки
const RETRY_DELAY: float = 30.0
## Если согласие не ответило за это время — запускаем рекламу без него (лимитированные объявления)
const CONSENT_TIMEOUT: float = 8.0
## Место под баннер сверху в убежище (в пикселях интерфейса)
const BANNER_RESERVE: float = 92.0

## SDK готов (пришёл ответ MobileAds.initialize) — только после этого можно грузить рекламу
var _initialized: bool = false
## initialize() уже вызван, ждём ответа SDK
var _init_started: bool = false
var _banner: AdView
var _banner_wanted: bool = false
var _interstitial: InterstitialAd
var _rewarded: RewardedAd
var _loading_interstitial: bool = false
var _loading_rewarded: bool = false
var _showing: bool = false
var _missions_since_ad: int = 0
var _last_interstitial_time: float = -1000.0
var _after_interstitial: Callable = Callable()
var _reward_callback: Callable = Callable()
var _cancel_callback: Callable = Callable()
var _reward_earned: bool = false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	if not is_supported():
		return
	_request_consent()
	get_tree().create_timer(CONSENT_TIMEOUT, true, false, true).timeout.connect(_init_ads)


## Реклама есть на телефоне (и заглушки в редакторе)
func is_supported() -> bool:
	return OS.get_name() == "Android" or OS.get_name() == "iOS" or OS.has_feature("editor")


## Идёт полноэкранная реклама (игру не ставить на паузу, таймеры не тикать)
func is_showing_fullscreen() -> bool:
	return _showing


func is_rewarded_ready() -> bool:
	return _initialized and _rewarded != null and not _showing


# ---------- Баннер ----------

func show_banner() -> void:
	_banner_wanted = true
	if not _initialized:
		return
	if _banner == null:
		_banner = AdView.new(_unit(BANNER_ID, TEST_BANNER_ID), AdSize.BANNER, AdPosition.TOP)
		_banner.ad_listener.on_ad_failed_to_load = func(error: LoadAdError) -> void:
			push_warning("Ads: баннер не загрузился: %s" % error.message)
		_banner.load_ad(AdRequest.new())
	else:
		_banner.show()


func hide_banner() -> void:
	_banner_wanted = false
	if _banner != null:
		_banner.hide()


# ---------- Межстраничная ----------

## После миссии: показать рекламу (если пора), затем выполнить then (переход сцены).
## Если рекламы нет — then выполняется сразу
func after_mission(then: Callable) -> void:
	_missions_since_ad += 1
	var now: float = Time.get_ticks_msec() / 1000.0
	var due: bool = _missions_since_ad >= INTERSTITIAL_EVERY and now - _last_interstitial_time >= INTERSTITIAL_COOLDOWN
	if not due or _interstitial == null or _showing:
		then.call()
		return
	_after_interstitial = then
	_showing = true
	_interstitial.show()


func _load_interstitial() -> void:
	if _loading_interstitial or _interstitial != null:
		return
	_loading_interstitial = true
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_loading_interstitial = false
		_interstitial = ad
		var content := FullScreenContentCallback.new()
		content.on_ad_dismissed_full_screen_content = _on_interstitial_closed
		content.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
			_on_interstitial_closed()
		ad.full_screen_content_callback = content
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_loading_interstitial = false
		push_warning("Ads: межстраничная не загрузилась: %s" % error.message)
		_retry(_load_interstitial)
	InterstitialAdLoader.new().load(_unit(INTERSTITIAL_ID, TEST_INTERSTITIAL_ID), AdRequest.new(), callback)


func _on_interstitial_closed() -> void:
	_showing = false
	_missions_since_ad = 0
	_last_interstitial_time = Time.get_ticks_msec() / 1000.0
	if _interstitial != null:
		_interstitial.destroy()
	_interstitial = null
	_load_interstitial()
	var then: Callable = _after_interstitial
	_after_interstitial = Callable()
	if then.is_valid():
		then.call_deferred()


# ---------- С вознаграждением ----------

## Показать рекламу за награду: on_reward — досмотрел, on_cancel — закрыл раньше или ошибка.
## Возвращает false, если реклама не готова (кнопку лучше не показывать — is_rewarded_ready)
func show_rewarded(on_reward: Callable, on_cancel: Callable = Callable()) -> bool:
	if not is_rewarded_ready():
		return false
	_reward_callback = on_reward
	_cancel_callback = on_cancel
	_reward_earned = false
	_showing = true
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		_reward_earned = true
	_rewarded.show(listener)
	return true


func _load_rewarded() -> void:
	if _loading_rewarded or _rewarded != null:
		return
	_loading_rewarded = true
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		_loading_rewarded = false
		_rewarded = ad
		var content := FullScreenContentCallback.new()
		content.on_ad_dismissed_full_screen_content = _on_rewarded_closed
		content.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
			_on_rewarded_closed()
		ad.full_screen_content_callback = content
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_loading_rewarded = false
		push_warning("Ads: реклама с наградой не загрузилась: %s" % error.message)
		_retry(_load_rewarded)
	RewardedAdLoader.new().load(_unit(REWARDED_ID, TEST_REWARDED_ID), AdRequest.new(), callback)


func _on_rewarded_closed() -> void:
	_showing = false
	if _rewarded != null:
		_rewarded.destroy()
	_rewarded = null
	_load_rewarded()
	# Награда — после закрытия рекламы, когда игра снова на экране
	var callback: Callable = _reward_callback if _reward_earned else _cancel_callback
	_reward_callback = Callable()
	_cancel_callback = Callable()
	if callback.is_valid():
		callback.call_deferred()


# ---------- Конфиденциальность ----------

## Нужна ли кнопка «настройки конфиденциальности» (GDPR)
func privacy_options_required() -> bool:
	return _initialized and UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() \
		== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


func show_privacy_options() -> void:
	UserMessagingPlatform.show_privacy_options_form()


# ---------- Запуск ----------

func _request_consent() -> void:
	var params := ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(params, _on_consent_updated,
		func(_error: FormError) -> void: _init_ads())


func _on_consent_updated() -> void:
	var info: ConsentInformation = UserMessagingPlatform.consent_information
	if info.get_is_consent_form_available() \
			and info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
		UserMessagingPlatform.load_consent_form(
			func(form: ConsentForm) -> void:
				form.show(func(_error: FormError) -> void: _init_ads()),
			func(_error: FormError) -> void: _init_ads())
	else:
		_init_ads()


func _init_ads() -> void:
	if _init_started:
		return
	_init_started = true
	# Загрузка объявлений до окончания инициализации роняет приложение на Android
	# (IllegalStateException: MobileAds.initialize must be called before using the SDK) —
	# грузим только в колбэке завершения
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		_on_sdk_ready.call_deferred()
	MobileAds.initialize(listener)


func _on_sdk_ready() -> void:
	if _initialized:
		return
	_initialized = true
	_load_interstitial()
	_load_rewarded()
	if _banner_wanted:
		show_banner()


func _retry(loader: Callable) -> void:
	get_tree().create_timer(RETRY_DELAY, true, false, true).timeout.connect(loader)


## Свои блоки — в релизе, тестовые Google — в отладочной сборке
func _unit(real_id: String, test_id: String) -> String:
	return test_id if OS.is_debug_build() else real_id
