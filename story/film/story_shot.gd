class_name StoryShot
extends Resource
## План сюжетного фильма (StoryFilm): настроение сцены-диорамы (живой город, мёртвый, бандиты…),
## точка камеры (заготовка StoryStage), надпись места/времени, голос рассказчика или героя, титр.

enum Mood { LIVING, OUTBREAK, DEAD, BANDITS, HOPE, BLACK, CAMP }

@export var mood: Mood = Mood.LIVING
## Заготовка камеры StoryStage.CAMERAS (aerial, sidewalk, crossroad, zombie_low…)
@export var camera: String = "aerial"
@export var duration: float = 5.0
## Надпись сверху слева: место и время («СЕВЕР-9. ГОД НАЗАД»)
@export var caption: String = ""
## Реплика (субтитр снизу + синтез речи). Язык — как в телефоне
@export_multiline var voice_ru: String = ""
@export_multiline var voice_en: String = ""
## Кто говорит («МАМА», «БАРОН»); пусто — рассказчик
@export var speaker: String = ""
## Тон голоса героя (0 — голос рассказчика)
@export_range(0.0, 2.0, 0.05) var pitch: float = 0.0
## Крупный титр по центру (название главы, «ТРИ ДНЯ СПУСТЯ»)
@export var title: String = ""
## Эффект в начале плана: "flash" — белая вспышка, "shake" — тряска камеры
@export var effect: String = ""
