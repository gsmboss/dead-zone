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
