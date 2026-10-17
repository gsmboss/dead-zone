class_name AchievementList
extends Resource
## Все достижения игры (quests/achievements.tres), порядок — порядок в окне ДОСТИЖЕНИЯ.

@export var achievements: Array[AchievementData] = []


func find(achievement_id: String) -> AchievementData:
	for achievement: AchievementData in achievements:
		if achievement != null and achievement.id == achievement_id:
			return achievement
	return null
