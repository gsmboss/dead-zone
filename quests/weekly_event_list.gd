class_name WeeklyEventList
extends Resource
## События недели по кругу (quests/weekly_events.tres): неделя N → events[N % size].

@export var events: Array[WeeklyEventData] = []
