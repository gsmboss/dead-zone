class_name SocialLinkList
extends Resource
## Соцсети студии и правила напоминания «подпишись» (ui/social/social_links.tres)

@export var links: Array[SocialLink] = []
## Политика конфиденциальности (страница на Google Сайтах; та же ссылка — в Play Console)
@export var privacy_url: String = ""
## Напоминать в убежище после стольких побед
@export var prompt_min_wins: int = 2
## Не чаще раза в столько дней и не больше prompt_max раз (пока есть неполученные награды)
@export var prompt_interval_days: int = 3
@export var prompt_max: int = 3
## Награду можно забрать через столько секунд после перехода по ссылке
@export var claim_delay: float = 5.0


func find(link_id: String) -> SocialLink:
	for link: SocialLink in links:
		if link != null and link.id == link_id:
			return link
	return null


func get_total_reward() -> int:
	var total: int = 0
	for link: SocialLink in links:
		if link != null:
			total += link.reward
	return total
