class_name VoiceOver
extends RefCounted
## Озвучка синтезом речи устройства (DisplayServer TTS: на Android — голос Google, на ПК — системный).
## Язык — как в системе: русский, если телефон на русском, иначе английский; нет русского голоса —
## английские реплики и голос. Свои аудиофайлы не нужны. В project.godot: audio/general/text_to_speech=true.

const RU: String = "ru"
const EN: String = "en"

static var _checked: bool = false
static var _language: String = EN
static var _voice: String = ""


## Язык реплик ("ru"/"en") — под системный язык и наличие голоса
static func language() -> String:
	_detect()
	return _language


static func is_russian() -> bool:
	return language() == RU


## Есть ли голос на устройстве
static func is_available() -> bool:
	_detect()
	return not _voice.is_empty()


## Реплика на нужном языке
static func pick(ru_text: String, en_text: String) -> String:
	if is_russian():
		return ru_text if not ru_text.is_empty() else en_text
	return en_text if not en_text.is_empty() else ru_text


## Сказать фразу. pitch/rate — «характер» голоса (смешные голоса — высокий/низкий тон)
static func speak(text: String, pitch: float = 1.0, rate: float = 1.0, interrupt: bool = true) -> void:
	if text.strip_edges().is_empty() or not is_available():
		return
	var volume: int = clampi(roundi(Settings.master_volume * Settings.voice_volume * 100.0), 0, 100)
	if volume <= 0:
		return
	if interrupt:
		DisplayServer.tts_stop()
	DisplayServer.tts_speak(_clean(text), _voice, volume, clampf(pitch, 0.0, 2.0), clampf(rate, 0.1, 10.0))


static func stop() -> void:
	if is_available():
		DisplayServer.tts_stop()


## Примерная длительность фразы, с (чтобы план кат-сцены дождался конца речи)
static func estimate_duration(text: String, rate: float = 1.0) -> float:
	return 0.6 + text.length() * 0.068 / maxf(rate, 0.1)


static func _detect() -> void:
	if _checked:
		return
	_checked = true
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		_language = RU if OS.get_locale_language() == RU else EN
		return
	var wanted: String = RU if OS.get_locale_language() == RU else EN
	var voices: PackedStringArray = DisplayServer.tts_get_voices_for_language(wanted)
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
