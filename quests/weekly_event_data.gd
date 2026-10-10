class_name WeeklyEventData
extends Resource
## Событие недели: всю неделю чаще встречается тип зомби zombie, монеты × coin_multiplier,
## и недельное испытание — набрать challenge_target событий challenge_event (GameState.report_event).

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
## Тип зомби недели (пусто — без особого зомби) и доля среди появляющихся
@export var zombie: ZombieData
@export_range(0.0, 0.5, 0.01) var zombie_chance: float = 0.15
@export var coin_multiplier: float = 1.0
@export_group("Challenge")
@export var challenge_text: String = ""
@export var challenge_event: StringName = &"kill"
@export var challenge_target: int = 100
@export var challenge_reward: int = 1500
