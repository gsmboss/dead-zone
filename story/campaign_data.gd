class_name CampaignData
extends Resource
## Сюжетная кампания: пролог «как всё началось» и главы по порядку.

@export var title: String = "ХРОНИКИ МЁРТВОЙ ЗОНЫ"
@export_multiline var prologue_pages: PackedStringArray = []
## Финал после последней главы
@export_multiline var epilogue_pages: PackedStringArray = []
## Фильмы пролога («каким был город, что случилось») и финала
@export var prologue_film: StoryFilm
@export var epilogue_film: StoryFilm
@export var chapters: Array[ChapterData] = []


func find_by_mission(mission_id: String) -> ChapterData:
	for chapter: ChapterData in chapters:
		if chapter != null and chapter.mission != null and chapter.mission.id == mission_id:
			return chapter
	return null


func find(chapter_id: String) -> ChapterData:
	for chapter: ChapterData in chapters:
		if chapter != null and chapter.id == chapter_id:
			return chapter
	return null
