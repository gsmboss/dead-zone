extends Node
## Проверка логики убежища (ShelterState) и сборки убежища на всех уровнях.
## Запуск: godot --headless --path . res://tools/validate/shelter_test.tscn
## Сохранение игрока не теряется: копия до теста, после — обратно.
var _fails: int = 0
var _backup: String = ""
func _ready() -> void:
	_run.call_deferred()
func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
	else:
		print("ok: ", what)
func _run() -> void:
	Settings.cutscenes = false
	if FileAccess.file_exists(GameState.SAVE_PATH):
		_backup = FileAccess.get_file_as_string(GameState.SAVE_PATH)
	GameState.reset_progress()
	var sh: ShelterState = GameState.shelter
	_check(sh.level == 1 and sh.food == sh.config.start_food, "старт: уровень 1, провизия %d" % sh.food)
	_check(sh.get_population() >= 2, "жильцов %d" % sh.get_population())
	_check(not sh.is_fed_today() and sh.can_feed(), "можно накормить (обед %d)" % sh.get_meal_cost())
	var morale_before: float = sh.get_morale()
	_check(sh.feed(), "накормили")
	_check(sh.is_fed_today() and not sh.feed(), "второй обед за день нельзя")
	_check(sh.get_morale() >= morale_before, "настроение %.0f → %.0f (потолок %.0f)" % [morale_before, sh.get_morale(), sh.get_max_morale()])
	_check(not sh.buy_food(0), "без монет еду не купить")
	GameState.add_coins(100000)
	var food: int = sh.food
	_check(sh.buy_food(1) and sh.food == food + sh.config.food_pack_crates[1], "купили провизию")
	_check(not GameState.buy_building("garden"), "огород до уровня ДВОР нельзя")
	_check(not sh.upgrade(), "без лома не расширить")
	GameState.add_item(GameState.SCRAP_ID, 99)
	_check(sh.upgrade() and sh.level == 2, "уровень 2")
	_check(GameState.buy_building("garden") and GameState.buy_building("watchtower"), "огород и вышка")
	_check(not sh.can_recruit(), "без радио звать нельзя: " + sh.get_recruit_block())
	_check(sh.upgrade() and sh.level == 3, "уровень 3")
	_check(GameState.buy_building("radio") and GameState.buy_building("generator"), "радио и генератор")
	var pop: int = sh.get_population()
	_check(sh.recruit() and sh.get_population() == pop + 1, "позвали выжившего")
	for item: DecorData in sh.decor_list.decor:
		if item.required_level <= sh.level:
			_check(sh.buy_decor(item.id), "обустройство " + item.id)
	_check(not sh.buy_decor("cinema"), "кинотеатр до уровня БАЗА нельзя")
	_check(sh.upgrade() and sh.upgrade() and sh.level == 5 and not sh.upgrade(), "уровень 5, дальше нельзя")
	_check(GameState.buy_building("canteen"), "столовая")
	for item: DecorData in sh.decor_list.decor:
		if not sh.owns_decor(item.id):
			_check(sh.buy_decor(item.id), "обустройство " + item.id)
	_check(sh.get_max_morale() == 100.0, "потолок настроения 100 (уют %d)" % sh.get_comfort())
	# Касса: сдвинуть время назад на 3 часа
	sh.income_time -= 3 * 3600
	var pending: float = sh.get_pending_income()
	_check(pending > 0.0, "касса копится: %.1f (%.1f/ч)" % [pending, sh.get_income_rate()])
	var coins: int = GameState.coins
	var got: int = sh.collect_income()
	_check(got > 0 and GameState.coins == coins + got, "забрали кассу %d" % got)
	# Голод: прошло 2 дня без обеда
	sh.morale = 90.0
	sh.day -= 2
	sh.last_meal_day = -1
	var garden_food: int = sh.food
	sh.tick()
	_check(sh.morale <= 90.0 - 2.0 * sh.config.morale_hungry_day + 0.1, "2 дня без обеда: настроение %.0f" % sh.morale)
	_check(sh.food == mini(garden_food + 2 * sh.config.garden_food_per_day, sh.config.max_food), "огород за 2 дня: %d" % sh.food)
	# Сохранение и загрузка
	var saved: Dictionary = sh.to_dict()
	var copy := ShelterState.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(saved)))
	_check(copy.level == sh.level and copy.food == sh.food and copy.decor_owned.size() == sh.decor_owned.size() \
		and copy.recruited == sh.recruited, "сохранение/загрузка")
	_check(GameState.get_reward_multiplier("waves") >= 1.0, "множитель награды")
	# Убежище на каждом уровне
	for level in range(1, 6):
		sh.level = level
		var hub: Node = (load("res://hub/hub.tscn") as PackedScene).instantiate()
		get_tree().root.add_child(hub)
		await get_tree().create_timer(1.0).timeout
		var floor_box := hub.get_node("Room/Floor") as CSGBox3D
		_check(is_equal_approx(floor_box.size.x, sh.get_half_size() * 2.0), "уровень %d: пол %.1f" % [level, floor_box.size.x])
		var base := hub.get_node("ShelterBase") as HubBase
		_check(base != null, "уровень %d: HubBase" % level)
		if level == 3:
			# Расширение на лету
			sh.level = 4
			GameState.shelter_changed.emit()
			await get_tree().create_timer(0.5).timeout
			_check(is_equal_approx(floor_box.size.x, sh.get_half_size() * 2.0), "расширение на лету: пол %.1f" % floor_box.size.x)
			_check(hub.get_node_or_null("Yard") != null and hub.get_node_or_null("Camp") != null, "двор и лагерь пересобраны")
			sh.level = 3
		hub.queue_free()
		await get_tree().process_frame
	_restore_save()
	print("ИТОГ ТЕСТА УБЕЖИЩА: ", "проблем нет" if _fails == 0 else "%d ошибок" % _fails)
	get_tree().quit()


func _restore_save() -> void:
	if _backup.is_empty():
		GameState.reset_progress()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
		return
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("shelter_test: не удалось вернуть сохранение")
		return
	file.store_string(_backup)
	file.close()
	GameState.load_game()
