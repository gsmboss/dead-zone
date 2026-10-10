extends Node
## Проверка проекта без редактора (сцена с автозагрузками, как в игре):
##   godot --headless --path . res://tools/validate/validate.tscn
## 1) загружает все .gd, .tscn, .tres (битые пути, ошибки скриптов);
## 2) сюжет: главы, миссии, сцены уровней, фильмы (камеры, настроения, тексты ru/en), картинки глав;
## 3) миссии и типы зомби: модели, сцены уровней. Итог — число проблем; код выхода 1, если они есть.

const SKIP_DIRS: PackedStringArray = [".godot", "addons", "android", "store", ".git"]

var _problems: PackedStringArray = []
var _checked: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("=== Проверка ресурсов ===")
	_walk("res://")
	print("Загружено файлов: %d" % _checked)
	print("=== Проверка сюжета ===")
	_check_campaign()
	print("=== Проверка миссий ===")
	_check_missions()
	print("")
	if _problems.is_empty():
		print("ИТОГ: проблем нет")
	else:
		print("ИТОГ: проблем %d" % _problems.size())
		for problem: String in _problems:
			print("  - " + problem)
	get_tree().quit(1 if not _problems.is_empty() else 0)


func _problem(text: String) -> void:
	_problems.append(text)
	printerr("ПРОБЛЕМА: " + text)


func _walk(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		if sub in SKIP_DIRS or sub.begins_with("."):
			continue
		_walk(path.path_join(sub))
	for file: String in dir.get_files():
		var full: String = path.path_join(file)
		var ext: String = file.get_extension()
		if ext in ["gd", "tscn", "tres"]:
			_checked += 1
			var resource: Resource = ResourceLoader.load(full, "", ResourceLoader.CACHE_MODE_REUSE)
			if resource == null:
				_problem("не загружается: %s" % full)
			elif resource is GDScript and not (resource as GDScript).can_instantiate() \
					and not (resource as GDScript).is_abstract():
				_problem("скрипт с ошибкой: %s" % full)


# ---------- Сюжет ----------

func _check_campaign() -> void:
	var campaign := load("res://story/campaign.tres") as CampaignData
	if campaign == null:
		_problem("нет story/campaign.tres")
		return
	_check_pages("пролог", campaign.prologue_pages)
	_check_pages("эпилог", campaign.epilogue_pages)
	_check_film("пролог", campaign.prologue_film)
	_check_film("эпилог", campaign.epilogue_film)
	_check_art("prologue")
	_check_art("epilogue")
	var ids: Dictionary = {}
	for i in campaign.chapters.size():
		var chapter: ChapterData = campaign.chapters[i]
		if chapter == null:
			_problem("глава %d пустая" % (i + 1))
			continue
		var name_text: String = "глава %d «%s»" % [i + 1, chapter.title]
		if ids.has(chapter.id):
			_problem("%s: повтор id %s" % [name_text, chapter.id])
		ids[chapter.id] = true
		if chapter.mission == null:
			_problem("%s: нет миссии" % name_text)
		else:
			_check_mission(chapter.mission, name_text)
		_check_pages(name_text + " (до)", chapter.intro_pages)
		_check_pages(name_text + " (после)", chapter.outro_pages)
		_check_film(name_text + " фильм до", chapter.intro_film)
		_check_film(name_text + " фильм после", chapter.outro_film)
		_check_art(chapter.id)
		if chapter.map_position.x < 0.0 or chapter.map_position.x > 1.0 \
				or chapter.map_position.y < 0.0 or chapter.map_position.y > 1.0:
			_problem("%s: место на карте вне 0..1" % name_text)
		if chapter.unlock_car != null and chapter.unlock_car_name.is_empty():
			_problem("%s: машина без названия" % name_text)
	print("Глав: %d" % campaign.chapters.size())


func _check_pages(where: String, pages: PackedStringArray) -> void:
	if pages.is_empty():
		_problem("%s: нет страниц текста" % where)
	for page: String in pages:
		if page.strip_edges().is_empty():
			_problem("%s: пустая страница" % where)


func _check_film(where: String, film: StoryFilm) -> void:
	if film == null:
		return  # фильм необязателен
	if film.shots.is_empty():
		_problem("%s: фильм без планов" % where)
	var total: float = 0.0
	for i in film.shots.size():
		var shot: StoryShot = film.shots[i]
		if shot == null:
			_problem("%s: план %d пустой" % [where, i + 1])
			continue
		total += shot.duration
		if not StoryStage.CAMERAS.has(shot.camera):
			_problem("%s: план %d — нет камеры «%s»" % [where, i + 1, shot.camera])
		if shot.voice_ru.is_empty() != shot.voice_en.is_empty():
			_problem("%s: план %d — реплика только на одном языке" % [where, i + 1])
		if shot.duration < 1.0 or shot.duration > 20.0:
			_problem("%s: план %d — странная длительность %.1f" % [where, i + 1, shot.duration])
		if not shot.speaker.is_empty() and shot.voice_ru.is_empty():
			_problem("%s: план %d — говорящий без реплики" % [where, i + 1])
	if total > 120.0:
		_problem("%s: фильм длиннее 2 минут (%.0f с)" % [where, total])


func _check_art(art_id: String) -> void:
	if not ResourceLoader.exists("res://story/art/%s.jpg" % art_id):
		_problem("нет картинки story/art/%s.jpg" % art_id)


# ---------- Миссии ----------

func _check_missions() -> void:
	var dir := DirAccess.open("res://missions/data")
	var count: int = 0
	for file: String in dir.get_files():
		if file.get_extension() != "tres":
			continue
		var mission := load("res://missions/data/" + file) as MissionData
		if mission == null:
			_problem("миссия не загружается: %s" % file)
			continue
		count += 1
		_check_mission(mission, "миссия %s" % file)
	print("Миссий: %d" % count)


func _check_mission(mission: MissionData, where: String) -> void:
	if mission.id.is_empty():
		_problem("%s: пустой id" % where)
	if not ResourceLoader.exists(mission.level_scene):
		_problem("%s: нет сцены уровня %s" % [where, mission.level_scene])
	if MissionSelect.location_art(mission) == null:
		_problem("%s: нет карточки локации" % where)
	var types: Array[ZombieData] = [mission.walker, mission.runner, mission.tank, mission.boss]
	types.append_array(mission.specials)
	var any: bool = false
	for zombie: ZombieData in types:
		if zombie == null:
			continue
		any = true
		if zombie.model_scene != null:
			var model: Node = zombie.model_scene.instantiate()
			if model == null:
				_problem("%s: модель зомби %s не создаётся" % [where, zombie.display_name])
			else:
				model.free()
	if not any:
		_problem("%s: нет ни одного типа зомби" % where)
