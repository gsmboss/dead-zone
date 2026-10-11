# Трейлер Dead Zone

Ролик собирается из клипов, снятых в самой игре (Godot Movie Maker), титров и музыки CC0 (audio/music/combat.ogg).

1. Снять клипы (1080p, 30 к/с): в корне проекта временно создать `override.cfg`
   ```
   [display]
   window/size/window_width_override=1920
   window/size/window_height_override=1080
   ```
   и для каждого клипа:
   ```
   godot --path . --write-movie tools/trailer/out/c_film.avi --fixed-fps 30 res://tools/trailer/trailer_clip.tscn -- film prologue 80
   godot --path . --write-movie tools/trailer/out/c_street.avi --fixed-fps 30 res://tools/trailer/trailer_clip.tscn -- mission mission_waves 16 1p rifle
   ```
   Режимы: `film <id> <сек> [en]`, `mission <id> <сек> <1p|3p> <оружие> [en]`, `hub <сек>` (убежище на максимуме — портит сохранение,
   снимать на копии проекта). В бою игрок сам наводится и стреляет, дальние зомби подтягиваются в кадр.
   Клипы: c_film(_en), c_street, c_baron, c_harbor, c_mountain, c_grave, c_hub.
2. Титры и заставки: `python3 tools/trailer/make_cards.py tools/trailer/out` (cap_*_ru/en.png, card_logo.png, card_end_ru/en.png).
3. Сборка: `python3 tools/trailer/build.py ru tools/trailer/out` → DeadZone_trailer_ru.mp4 (ffmpeg, переходы, музыка).

## Shorts (вертикальные 1080×1920) и длинные видео
1. Вертикальные клипы — в вертикальном окне (`override.cfg` 1080×1920, xvfb-run -s "-screen 0 1080x1920x24"): камера в бою уже,
   зомби ближе (trailer_clip.gd сам видит вертикаль). Режимы съёмки:
   - `mission <id> <сек> <1p|3p> <оружие> [boss@<с>] [spawn=тип+тип] [deploy] [hold] [en]` — бой; boss@ — босс миссии с
     замедленным появлением перед игроком, spawn= — эти зомби по очереди (enemies/<тип>.tres), deploy — турель, капкан и мина,
     hold — не стрелять первые 2 с (видно, кто идёт);
   - `drive <сек>` — город: за рулём на бульваре, зомби выходят на дорогу, заносы;
   - `hub <сек> [уровень 1..5] [orbit|camp|gate]` — убежище («до» — уровень 1 без построек), у костра, пролёт от ворот;
   - `film <id> <сек> [en]` — фильм из story/films.
   Имена клипов — как в tools/trailer/shorts_edits.py (v_*, hs_*, z_*, melee_*, raid*, loc_*, drive, camp2, hub_*, film_baron…).
2. `python3 tools/trailer/shorts.py <монтаж> ru|en <папка>` → DeadZone_<монтаж>_<язык>.mp4. Монтажи на 14 дней — EDITS в
   shorts_edits.py (trailer, headshots, boss, prologue, melee, car, shelter, zombies, camp, sniper, raid, bandits, locations, release):
   сегменты в долях такта музыки, переходы cut/punch/flash/rgb/whip, замедление SLOWMO, надписи ru/en. Моменты хедшотов
   удобно искать по жёлтой надписи ХЕДШОТ в кадре.
3. Длинные (1920×1080): горизонтальные клипы c_*.avi и c_l_*.avi, `python3 tools/trailer/longform.py prologue|overview ru|en <папка>` —
   заставка, название, разделы с плашкой и подписями, затемнения, музыка, громкость по loudnorm.
4. Шрифт Russo One (OFL) — в папке клипов (shorts.py скачивает сам). Озвучку фильмов в ролик даёт только audio/voice
   (tools/voice/build_voice.py, нужен доступ к huggingface.co); без неё фильмы идут с субтитрами игры.
Названия, описания и расписание публикаций — store/youtube_plan.md.

Папка out/ в git не попадает.
