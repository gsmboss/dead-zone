class_name QuestPool
extends Resource
## Пул ежедневных заданий; каждый день выбираются daily_count штук.

@export var quests: Array[QuestData] = []
@export_range(1, 5) var daily_count: int = 3
## Награда за вход: reward_base × день серии (серия до max_streak дней)
@export var daily_reward_base: int = 50
@export_range(1, 30) var max_streak: int = 7


func find(quest_id: String) -> QuestData:
	for quest: QuestData in quests:
		if quest != null and quest.id == quest_id:
			return quest
	return null
