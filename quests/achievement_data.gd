class_name AchievementData
extends Resource
## Достижение: счётчик статистики event (GameState.report_event) дошёл до target → награда монетами.
## record = true — берётся лучшее значение (волна бесконечного режима, серия дней), а не сумма.

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var event: StringName = &"kill"
@export var target: int = 1
@export var record: bool = false
@export var reward: int = 100
@export var icon_color: Color = Color(1.0, 0.8, 0.3)
