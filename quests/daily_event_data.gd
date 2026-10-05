class_name DailyEventData
extends Resource
## Событие дня: меняет монеты, частоту зомби и дропы во всех миссиях этого дня.

@export var id: String = ""
@export var title: String = "ДВОЙНЫЕ МОНЕТЫ"
@export var description: String = ""
## Множители: монеты за миссию, частота появления зомби, шанс дропа
@export var coin_multiplier: float = 1.0
@export var spawn_multiplier: float = 1.0
@export var drop_multiplier: float = 1.0
