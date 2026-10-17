class_name VoiceLines
extends Resource
## Смешные реплики рассказчика для кат-сцен, которые строятся кодом (интро миссии, появление босса).
## Каждый раз берётся случайная. В русских можно {location}, {mission}, {boss} (английские — без
## подстановок: названия в игре русские).

@export_group("Интро миссии: обзор локации")
@export var location_ru: PackedStringArray = []
@export var location_en: PackedStringArray = []
@export_group("Интро миссии: цель")
@export var goal_ru: PackedStringArray = []
@export var goal_en: PackedStringArray = []
@export_group("Интро миссии: в бой")
@export var fight_ru: PackedStringArray = []
@export var fight_en: PackedStringArray = []
@export_group("Появление босса")
@export var boss_ru: PackedStringArray = []
@export var boss_en: PackedStringArray = []


## Случайная пара реплик [ru, en] из двух списков
static func pick_pair(ru_lines: PackedStringArray, en_lines: PackedStringArray, values: Dictionary = {}) -> PackedStringArray:
	var ru_text: String = ru_lines[randi() % ru_lines.size()] if not ru_lines.is_empty() else ""
	var en_text: String = en_lines[randi() % en_lines.size()] if not en_lines.is_empty() else ""
	return PackedStringArray([ru_text.format(values), en_text.format(values)])
