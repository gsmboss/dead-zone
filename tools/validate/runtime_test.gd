extends Node
## Проверка «в движении» (без редактора):
##   godot --headless --path . res://tools/validate/runtime_test.tscn
## 1) проигрывает все сюжетные фильмы story/films/*.tres ускоренно (StoryCinema);
## 2) по очереди запускает каждый уровень миссий и убежище на несколько секунд
##    (MissionManager, интро, спавн зомби, навмеш), затем выгружает.
## Ошибки движка смотреть в выводе (SCRIPT ERROR / ERROR). В конце — «ПРОГОН ЗАКОНЧЕН».

const FILM_DIR: String = "res://story/films/"
const FILM_SPEED: float = 12.0
const FILM_TIMEOUT: float = 30.0
const LEVEL_SECONDS: float = 6.0
const LEVEL_SPEED: float = 3.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Settings.cutscenes = true
	await _play_films()
	await _play_levels()
	print("ПРОГОН ЗАКОНЧЕН")
	Engine.time_scale = 1.0
	get_tree().quit()


func _play_films() -> void:
	var dir := DirAccess.open(FILM_DIR)
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file: String in files:
		if file.get_extension() != "tres":
			continue
		var film := load(FILM_DIR + file) as StoryFilm
		if film == null:
			printerr("ФИЛЬМ НЕ ГРУЗИТСЯ: " + file)
			continue
		print("Фильм: %s (%d планов)" % [file, film.shots.size()])
		Engine.time_scale = FILM_SPEED
		var cinema: StoryCinema = StoryCinema.play(get_tree(), film)
		var done: Array[bool] = [false]
		cinema.finished.connect(func() -> void: done[0] = true)
		var waited: float = 0.0
		while not done[0] and waited < FILM_TIMEOUT:
			await get_tree().process_frame
			waited += get_process_delta_time() / maxf(Engine.time_scale, 0.01)
		if not done[0]:
			printerr("ФИЛЬМ НЕ ЗАКОНЧИЛСЯ ЗА %d с: %s" % [FILM_TIMEOUT, file])
			cinema.skip()
			await get_tree().create_timer(1.0, true, false, true).timeout
		Engine.time_scale = 1.0


## Уровень как текущая сцена: MissionManager берёт GameState.selected_mission в _ready
func _play_levels() -> void:
	var seen: Dictionary = {}
	var runs: Array = []  # [сцена, миссия]
	var dir := DirAccess.open("res://missions/data")
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file: String in files:
		if file.get_extension() != "tres":
			continue
		var mission := load("res://missions/data/" + file) as MissionData
		if mission == null or seen.has(mission.level_scene + str(mission.type)):
			continue
		seen[mission.level_scene + str(mission.type)] = true
		runs.append([mission.level_scene, mission])
	runs.append(["res://hub/hub.tscn", null])
	for run: Array in runs:
		var path: String = run[0]
		var mission: MissionData = run[1]
		print("Уровень: %s%s" % [path, (" (" + mission.id + ")") if mission != null else ""])
		GameState.selected_mission = mission
		var scene := load(path) as PackedScene
		if scene == null:
			printerr("УРОВЕНЬ НЕ ГРУЗИТСЯ: " + path)
			continue
		var level: Node = scene.instantiate()
		get_tree().root.add_child(level)
		get_tree().current_scene = level
		Engine.time_scale = LEVEL_SPEED
		await get_tree().create_timer(LEVEL_SECONDS, true, false, true).timeout
		Engine.time_scale = 1.0
		get_tree().paused = false
		get_tree().current_scene = self
		level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
