class_name QuestData
extends Resource
## Ежедневное задание: накопить target событий event за день.

## События: kill, headshot_kill, tank_kill, boss_kill, mission_win, item_collect, rescue
@export var id: String = ""
@export var title: String = "УБЕЙ 50 ЗОМБИ"
@export var event: StringName = &"kill"
@export_range(1, 1000) var target: int = 50
@export var reward_coins: int = 100
