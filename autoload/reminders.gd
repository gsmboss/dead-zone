extends Node
## Напоминания «пора играть» — локальные уведомления Android через плагин Notification Scheduler 6.0
## (Godot Mobile Plugins, addons/NotificationSchedulerPlugin; ставится из AssetLib, нужна сборка Gradle).
## Без плагина (редактор, ПК, плагин не установлен) ничего не делает — вызовы только динамические.
## Свернули игру — ставим напоминания по состоянию игры (касса лагеря полна, обед и ежедневная награда,
## набег, «соскучились» через 3 и 7 дней), вернулись — снимаем. Ночью (QUIET_FROM–QUIET_TO) не будим.
## Значки: res://assets/NotificationSchedulerPlugin/android/drawable-*/ic_deadzone_small.png (белый силуэт
## для строки состояния) и ic_deadzone_large.png (цветная иконка игры) — плагин копирует их в ресурсы Android.
## Выключить — Settings.notifications (настройки, вкладка СЮЖЕТ).

const PLUGIN_SCRIPT: String = "res://addons/NotificationSchedulerPlugin/NotificationScheduler.gd"
const DATA_SCRIPT: String = "res://addons/NotificationSchedulerPlugin/model/NotificationData.gd"
const CHANNEL_SCRIPT: String = "res://addons/NotificationSchedulerPlugin/model/NotificationChannel.gd"
const SINGLETON: String = "NotificationSchedulerPlugin"
const CHANNEL_ID: String = "deadzone_reminders"
const SMALL_ICON: String = "ic_deadzone_small"
const LARGE_ICON: String = "ic_deadzone_large"
## Канал: важность DEFAULT (звук без всплывания поверх экрана)
const IMPORTANCE_DEFAULT: int = 3
## Флаг «разрешение уже спрашивали» (GameState.mark_cutscene_seen)
const ASKED_FLAG: String = "notifications_asked"

enum Kind { CASH, DAILY, RAID, COMEBACK, COMEBACK_LONG }
const IDS: Dictionary = {Kind.CASH: 7101, Kind.DAILY: 7102, Kind.RAID: 7103, Kind.COMEBACK: 7104,
	Kind.COMEBACK_LONG: 7105}

## Тихие часы (местное время): напоминание, попавшее на ночь, переносится на утро
const QUIET_FROM: int = 22
const QUIET_TO: int = 10
## Ежедневное напоминание и «соскучились» — в это время дня
const DAILY_HOUR: int = 12
const EVENING_HOUR: int = 18
const COMEBACK_DAYS: int = 3
const COMEBACK_LONG_DAYS: int = 7
## Не ставить напоминания ближе этого и чаще одного в MIN_GAP
const MIN_DELAY: int = 3600
const MIN_GAP: int = 5400
const SECONDS_PER_DAY: int = 86400

## [заголовок, текст] — ключи перевода (locale/en.json); выбирается случайный
const MESSAGES: Dictionary = {
	Kind.CASH: [
		["КАССА ЛАГЕРЯ ПОЛНА", "Жильцы заработали монеты. Забери, пока дядя Гоша не купил ещё одну кофемашину!"],
		["МОНЕТЫ ЖДУТ В УБЕЖИЩЕ", "Касса лагеря набита до отказа. Загляни и забери!"],
	],
	Kind.DAILY: [
		["ЕЖЕДНЕВНАЯ НАГРАДА ГОТОВА", "Серия дней не ждёт: забери монеты и накорми лагерь."],
		["ЖИЛЬЦЫ ПРОГОЛОДАЛИСЬ", "Дядя Гоша гремит пустой кастрюлей. Пора на обед — и за наградой дня!"],
		["НОВЫЕ ЗАДАНИЯ ДНЯ", "Свежие задания и награда уже в убежище. Зомби сами себя не победят."],
	],
	Kind.RAID: [
		["ОРДА У ВОРОТ!", "Зомби штурмуют убежище. Отбей набег — награда ×2!"],
	],
	Kind.COMEBACK: [
		["ЗОМБИ СКУЧАЮТ", "Они уже стучат в ворота убежища. Возвращайся, выживший!"],
		["ГОРОД ЖДЁТ ГЕРОЯ", "Тёма спрашивает, где ты пропадаешь. Мертвецы сами себя не упокоят!"],
	],
	Kind.COMEBACK_LONG: [
		["УБЕЖИЩЕ БЕЗ ТЕБЯ НЕ ТО", "Неделя без вылазок: провизия кончается, а орда всё ближе. Вернись!"],
	],
}

var _scheduler: Node
var _ready_to_schedule: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if OS.get_name() != "Android":
		return
	if not ResourceLoader.exists(PLUGIN_SCRIPT) or not Engine.has_singleton(SINGLETON):
		push_warning("Reminders: плагин Notification Scheduler не установлен — напоминаний не будет")
		return
	var script := load(PLUGIN_SCRIPT) as Script
	var node: Object = script.new() if script != null else null
	_scheduler = node as Node
	if _scheduler == null:
		push_warning("Reminders: не удалось создать NotificationScheduler")
		return
	_scheduler.name = "NotificationScheduler"
	add_child(_scheduler)
	_scheduler.connect(&"initialization_completed", _on_initialized)
	_scheduler.call(&"initialize")
	Settings.changed.connect(_on_settings_changed)


func is_available() -> bool:
	return _scheduler != null


func _on_initialized() -> void:
	var channel_script := load(CHANNEL_SCRIPT) as Script
	if channel_script == null:
		push_warning("Reminders: нет %s" % CHANNEL_SCRIPT)
		return
	var channel: Object = channel_script.new()
	channel.call(&"set_id", CHANNEL_ID)
	channel.call(&"set_name", UIKit.t("НАПОМИНАНИЯ"))
	channel.call(&"set_description", UIKit.t("Касса лагеря, награда дня, набеги"))
	channel.call(&"set_importance", IMPORTANCE_DEFAULT)
	var result: int = int(_scheduler.call(&"create_notification_channel", channel))
	if result != OK and result != ERR_ALREADY_EXISTS:
		push_warning("Reminders: канал не создан, код %d" % result)
	_ready_to_schedule = true
	_cancel_all()  # игра открыта — старые напоминания не нужны


## Один раз спросить разрешение на уведомления (Android 13+) — когда игрок уже втянулся (HubHUD)
func ask_permission_once() -> void:
	if not _ready_to_schedule or not Settings.notifications or GameState.has_seen_cutscene(ASKED_FLAG):
		return
	GameState.mark_cutscene_seen(ASKED_FLAG)
	if not bool(_scheduler.call(&"has_post_notifications_permission")):
		_scheduler.call(&"request_post_notifications_permission")


func _on_settings_changed() -> void:
	if not _ready_to_schedule:
		return
	if not Settings.notifications:
		_cancel_all()
	elif not bool(_scheduler.call(&"has_post_notifications_permission")):
		_scheduler.call(&"request_post_notifications_permission")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			_schedule_all()
		NOTIFICATION_APPLICATION_RESUMED:
			_cancel_all()


func _cancel_all() -> void:
	if not _ready_to_schedule:
		return
	for kind: int in IDS:
		_scheduler.call(&"cancel", int(IDS[kind]))


## Поставить напоминания по состоянию игры (вызывается, когда игру сворачивают)
func _schedule_all() -> void:
	if not _ready_to_schedule or not Settings.notifications:
		return
	_cancel_all()
	var now: int = int(Time.get_unix_time_from_system())
	var plan: Array[Array] = []  # [время unix, Kind]
	# Касса лагеря наполнится
	var shelter: ShelterState = GameState.shelter
	var rate: float = shelter.get_income_rate()
	if rate > 0.0:
		var missing: float = shelter.get_income_cap() - shelter.get_pending_income()
		plan.append([now + maxi(int(missing / rate * 3600.0), MIN_DELAY), Kind.CASH])
	# Завтра днём: награда дня и обед лагеря
	plan.append([_next_local_time(now, 1, DAILY_HOUR), Kind.DAILY])
	# Набег на убежище (если уже назначен)
	if GameState.get_raid_time() > now + MIN_DELAY:
		plan.append([GameState.get_raid_time(), Kind.RAID])
	plan.append([_next_local_time(now, COMEBACK_DAYS, EVENING_HOUR), Kind.COMEBACK])
	plan.append([_next_local_time(now, COMEBACK_LONG_DAYS, EVENING_HOUR), Kind.COMEBACK_LONG])
	# Ночью не будим; два напоминания подряд не шлём
	for entry: Array in plan:
		entry[0] = _out_of_quiet_hours(int(entry[0]))
	plan.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var last: int = 0
	for entry: Array in plan:
		var at: int = int(entry[0])
		if at - now < MIN_DELAY or (last > 0 and at - last < MIN_GAP):
			continue
		_schedule(int(entry[1]), at - now)
		last = at


func _schedule(kind: int, delay: int) -> void:
	var data_script := load(DATA_SCRIPT) as Script
	if data_script == null:
		push_warning("Reminders: нет %s" % DATA_SCRIPT)
		return
	var options: Array = MESSAGES[kind]
	var message: Array = options[_rng.randi() % options.size()]
	var data: Object = data_script.new()
	data.call(&"set_id", int(IDS[kind]))
	data.call(&"set_channel_id", CHANNEL_ID)
	data.call(&"set_title", UIKit.t(str(message[0])))
	data.call(&"set_content", UIKit.t(str(message[1])))
	data.call(&"set_small_icon_name", SMALL_ICON)
	data.call(&"set_large_icon_name", LARGE_ICON)
	data.call(&"set_delay", delay)
	var result: int = int(_scheduler.call(&"schedule", data))
	if result != OK:
		push_warning("Reminders: напоминание %d не поставлено, код %d" % [kind, result])


## Смещение местного времени от UTC, секунды
static func _local_bias() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


## Через days дней в hour:00 по местному времени
static func _next_local_time(now: int, days: int, hour: int) -> int:
	var bias: int = _local_bias()
	var local_midnight: int = floori(float(now + bias) / SECONDS_PER_DAY) * SECONDS_PER_DAY
	return local_midnight + days * SECONDS_PER_DAY + hour * 3600 - bias


## Время попало на ночь — перенести на QUIET_TO:00 утра
static func _out_of_quiet_hours(at: int) -> int:
	var bias: int = _local_bias()
	var hour: int = int(Time.get_datetime_dict_from_unix_time(at + bias)["hour"])
	if hour >= QUIET_FROM:
		return _next_local_time(at, 1, QUIET_TO)
	if hour < QUIET_TO:
		return _next_local_time(at, 0, QUIET_TO)
	return at
