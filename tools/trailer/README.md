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

Папка out/ в git не попадает.
