class_name VoiceOver
extends RefCounted
## Озвучка реплик. Сначала — готовые файлы нейросети Piper (audio/voice/<язык>/<ключ>.ogg, ключ —
## file_key(текст); собирает tools/voice/build_voice.py, у каждого героя свой голос). Нет файла —
## синтез речи устройства (DisplayServer TTS: на Android — голос Google, на ПК — системный).
## Язык — как в игре (Settings); нет ни файлов, ни голоса на русском — английские реплики.
## В project.godot: audio/general/text_to_speech=true.

const RU: String = "ru"
const EN: String = "en"

## Готовые реплики: audio/voice/<язык>/<ключ>.ogg; признак набора — voice_pack.tres в папке языка
const VOICE_DIR: String = "res://audio/voice/%s/"
const PACK_FILE: String = "voice_pack.tres"

static var _checked: bool = false
static var _language: String = EN
static var _voice: String = ""
static var _has_pack: bool = false
static var _player: AudioStreamPlayer
## Длительность последней найденной реплики (для estimate_duration)
static var _last_text: String = ""
static var _last_stream: AudioStream


## Язык сменили в настройках — заново выбрать голос
static func reset() -> void:
	_checked = false
	_voice = ""
	_has_pack = false
	_last_text = ""
	_last_stream = null


## Язык реплик ("ru"/"en") — под язык игры (Settings) и наличие голоса
static func language() -> String:
	_detect()
	return _language


static func is_russian() -> bool:
	return language() == RU


## Есть ли чем озвучить: готовые файлы или голос на устройстве
static func is_available() -> bool:
	_detect()
	return _has_pack or not _voice.is_empty()


## Есть ли готовая озвучка (нейросеть) на текущем языке
static func has_voice_pack() -> bool:
	_detect()
	return _has_pack


## Ключ файла реплики: первые 16 знаков md5 текста (тот же в tools/voice/build_voice.py)
static func file_key(text: String) -> String:
	return text.md5_text().substr(0, 16)


## Готовая запись реплики или null
static func find_recording(text: String) -> AudioStream:
	if not _has_pack or text.is_empty():
		return null
	if text == _last_text:
		return _last_stream
	var path: String = (VOICE_DIR % _language) + file_key(text) + ".ogg"
	var stream: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	_last_text = text
	_last_stream = stream
	return stream


## Реплика на нужном языке
static func pick(ru_text: String, en_text: String) -> String:
	if is_russian():
		return ru_text if not ru_text.is_empty() else en_text
	return en_text if not en_text.is_empty() else ru_text


## Случайная реплика из списка на нужном языке (пусто, если списков нет)
static func pick_random_line(ru_lines: PackedStringArray, en_lines: PackedStringArray) -> String:
	var lines: PackedStringArray = ru_lines if is_russian() else en_lines
	if lines.is_empty():
		lines = en_lines if is_russian() else ru_lines
	return lines[randi() % lines.size()] if not lines.is_empty() else ""


## Сказать фразу. pitch/rate — «характер» голоса (смешные голоса — высокий/низкий тон)
static func speak(text: String, pitch: float = 1.0, rate: float = 1.0, interrupt: bool = true) -> void:
	if text.strip_edges().is_empty() or not is_available():
		return
	var recording: AudioStream = find_recording(text)
	if recording != null:
		_play_recording(recording, interrupt)
		return
	if _voice.is_empty():
		return  # записи нет, голоса на устройстве тоже
	var volume: int = clampi(roundi(Settings.master_volume * Settings.voice_volume * 100.0), 0, 100)
	if volume <= 0:
		return
	if interrupt:
		DisplayServer.tts_stop()
		_stop_recording()
	DisplayServer.tts_speak(_clean(text), _voice, volume, clampf(pitch, 0.0, 2.0), clampf(rate, 0.1, 10.0))


static func stop() -> void:
	_stop_recording()
	if not _voice.is_empty():
		DisplayServer.tts_stop()


## Длительность фразы, с (чтобы план кат-сцены дождался конца речи): у записи — точная
static func estimate_duration(text: String, rate: float = 1.0) -> float:
	var recording: AudioStream = find_recording(text)
	if recording != null:
		return recording.get_length() + 0.2
	return 0.6 + text.length() * 0.068 / maxf(rate, 0.1)


## Запись играет свой плеер в корне дерева (не на паузе, громкость — «Голос» в настройках;
## общая громкость — уже на шине Master)
static func _play_recording(stream: AudioStream, interrupt: bool) -> void:
	if Settings.voice_volume <= 0.001:
		return
	if _player == null or not is_instance_valid(_player):
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null or tree.root == null:
			return
		_player = AudioStreamPlayer.new()
		_player.name = "VoiceOverPlayer"
		_player.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(_player)
	if _player.playing and not interrupt:
		return
	if not _voice.is_empty():
		DisplayServer.tts_stop()
	_player.stream = stream
	_player.volume_db = linear_to_db(maxf(Settings.voice_volume, 0.0001))
	_player.play()


static func _stop_recording() -> void:
	if _player != null and is_instance_valid(_player):
		_player.stop()


static func _detect() -> void:
	if _checked:
		return
	_checked = true
	var wanted: String = RU if Settings.get_language_code() == RU else EN
	_has_pack = ResourceLoader.exists((VOICE_DIR % wanted) + PACK_FILE)
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		_language = wanted
		return
	var voices: PackedStringArray = DisplayServer.tts_get_voices_for_language(wanted)
	if _has_pack:
		# Свои записи на этом языке есть — голос устройства только для реплик без записи
		_language = wanted
		_voice = voices[0] if not voices.is_empty() else ""
		return
	if voices.is_empty() and wanted == RU:
		wanted = EN
		voices = DisplayServer.tts_get_voices_for_language(EN)
	_language = wanted
	_voice = voices[0] if not voices.is_empty() else ""


## Без значков, которые синтезатор читает вслух («звёздочка», «стрелка»)
static func _clean(text: String) -> String:
	var result: String = text
	for symbol: String in ["*", "▸", "▼", "•", "«", "»", "—", "\n"]:
		result = result.replace(symbol, " " if symbol == "\n" or symbol == "—" else "")
	return result
