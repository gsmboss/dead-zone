class_name CampChatter
extends Resource
## Разговоры выживших у костра в убежище (hub/hub_camp.gd). Диалог — реплики по очереди двух людей
## (чётные — первый, нечётные — второй). Язык — как в телефоне (VoiceOver), русский и английский
## списки одинаковой длины: диалог i на русском = диалог i на английском.

@export var dialogues_ru: Array[PackedStringArray] = []
@export var dialogues_en: Array[PackedStringArray] = []
## Если у костра один человек — бормочет сам с собой
@export var solo_ru: PackedStringArray = []
@export var solo_en: PackedStringArray = []


func get_dialogue(index: int) -> PackedStringArray:
	var list: Array[PackedStringArray] = dialogues_ru if VoiceOver.is_russian() else dialogues_en
	if list.is_empty():
		list = dialogues_ru if not dialogues_ru.is_empty() else dialogues_en
	return list[index % list.size()] if not list.is_empty() else PackedStringArray()


func get_dialogue_count() -> int:
	return maxi(dialogues_ru.size(), dialogues_en.size())


func get_solo_line(index: int) -> String:
	var list: PackedStringArray = solo_ru if VoiceOver.is_russian() else solo_en
	return list[index % list.size()] if not list.is_empty() else ""


# ---------- Разговор с игроком (кнопка «ПОГОВОРИТЬ» у костра) ----------

## Шутка игрока и ответ выжившего: [реплика игрока, ответ]
@export var jokes_ru: Array[PackedStringArray] = []
@export var jokes_en: Array[PackedStringArray] = []
## Познавательные факты, которые выживший рассказывает игроку
@export var facts_ru: PackedStringArray = []
@export var facts_en: PackedStringArray = []
## Как игрок просит рассказать что-нибудь умное
@export var ask_ru: PackedStringArray = []
@export var ask_en: PackedStringArray = []


func get_joke(index: int) -> PackedStringArray:
	var list: Array[PackedStringArray] = jokes_ru if VoiceOver.is_russian() else jokes_en
	if list.is_empty():
		list = jokes_ru if not jokes_ru.is_empty() else jokes_en
	return list[index % list.size()] if not list.is_empty() else PackedStringArray()


func get_joke_count() -> int:
	return maxi(jokes_ru.size(), jokes_en.size())


func get_fact(index: int) -> String:
	var list: PackedStringArray = facts_ru if VoiceOver.is_russian() else facts_en
	if list.is_empty():
		list = facts_ru if not facts_ru.is_empty() else facts_en
	return list[index % list.size()] if not list.is_empty() else ""


func get_fact_count() -> int:
	return maxi(facts_ru.size(), facts_en.size())


func get_ask(index: int) -> String:
	var list: PackedStringArray = ask_ru if VoiceOver.is_russian() else ask_en
	return list[index % list.size()] if not list.is_empty() else "?"
