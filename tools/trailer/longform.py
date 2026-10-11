#!/usr/bin/env python3
# Длинные видео для YouTube (1920×1080): python3 tools/trailer/longform.py <видео> ru|en [папка с клипами]
# Запускать из корня проекта. Клипы c_*.avi — горизонтальные (override.cfg 1920×1080, см. README.md).
# Видео — LONG_EDITS: заставка студии, название, части с плашкой-заголовком (глава) и подписями внизу,
# переходы через затемнение, музыка под всем роликом (звук игры тише), концовка с призывом подписаться.
import os, subprocess, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H, FPS = 1920, 1080, 30
NAME = sys.argv[1] if len(sys.argv) > 1 else 'prologue'
LANG = sys.argv[2] if len(sys.argv) > 2 else 'ru'
D = os.path.abspath(sys.argv[3]) if len(sys.argv) > 3 else os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')
ROOT = os.getcwd()
LI = 0 if LANG == 'ru' else 1
FADE = 0.5
FONT_PATH = os.path.join(D, 'RussoOne-Regular.ttf')
FALLBACK_FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
EN = '_en' if LANG == 'en' else ''

# Часть: (клип, начало, длина, заголовок или None, [(время от начала части, подпись)], громкость звука клипа)
LONG_EDITS = {
    # День 4: пролог целиком — фильм и первые минуты боя
    'prologue': {
        'music': 'ambient_city', 'music_gain': 0.6,
        'title': ('ПРОЛОГ', 'PROLOGUE'),
        'subtitle': ('ДЕНЬ, КОГДА ГОРОД ПАЛ', 'THE DAY THE CITY FELL'),
        'parts': [
            ('c_film%s.avi' % EN, 0.0, 79.0, None, [], 0.9),
            ('c_street.avi', 6.0, 12.0, ('ТРИ МЕСЯЦА СПУСТЯ', 'THREE MONTHS LATER'),
             [(1.0, ('НАЙДИ ТЁМУ. ВЫЖИВИ.', 'FIND TYOMA. SURVIVE.'))], 0.6),
            ('c_harbor.avi', 6.0, 10.0, None, [], 0.6),
        ],
    },
    # День 8: обзор игры по разделам
    'overview': {
        'music': 'combat', 'music_gain': 0.45,
        'title': ('ОБЗОР ИГРЫ', 'GAMEPLAY OVERVIEW'),
        'subtitle': ('ЗОМБИ-ШУТЕР ДЛЯ ANDROID', 'ZOMBIE SHOOTER FOR ANDROID'),
        'parts': [
            ('c_film%s.avi' % EN, 53.0, 8.0, ('СЮЖЕТ', 'STORY'),
             [(0.5, ('30 ГЛАВ, 3 ЧАСТИ, КИНО С ОЗВУЧКОЙ', '30 CHAPTERS, 3 PARTS, VOICED CUTSCENES'))], 0.0),
            ('c_film%s.avi' % EN, 18.0, 6.0, None, [(0.5, ('ИЩИ ПРОПАВШЕГО БРАТА', 'SEARCH FOR YOUR MISSING BROTHER'))], 0.0),
            ('c_street.avi', 5.0, 12.0, ('ОРУЖИЕ', 'WEAPONS'),
             [(0.5, ('11 СТВОЛОВ И ХОЛОДНОЕ ОРУЖИЕ', '11 GUNS AND MELEE WEAPONS')),
              (6.0, ('ОБВЕСЫ: ГЛУШИТЕЛЬ, КОЛЛИМАТОР, ЛАЗЕР', 'ATTACHMENTS: SILENCER, RED DOT, LASER'))], 0.5),
            ('c_l_melee.avi', 6.0, 8.0, None, [(0.5, ('ТОПОР, БИТА, КОПЬЁ, ПИЛА', 'AXE, BAT, SPEAR, SAW'))], 0.5),
            ('c_l_types.avi', 4.0, 12.0, ('ЗОМБИ', 'ZOMBIES'),
             [(0.5, ('КРИКУНЫ, БУГАИ В БРОНЕ, ЗОМБИ В КАСКАХ', 'SCREAMERS, ARMORED BRUTES, HELMET ZOMBIES')),
              (6.0, ('ПЛЕВУНЫ, ВЗРЫВНЫЕ, СОБАКИ', 'SPITTERS, EXPLODERS, DOGS'))], 0.5),
            ('c_l_boss.avi', 1.5, 14.0, ('БОССЫ', 'BOSSES'),
             [(0.5, ('УТОПЛЕННИК, ПАСТУХ, БАРОН И ДРУГИЕ', 'THE DROWNED, THE SHEPHERD, THE BARON AND MORE'))], 0.5),
            ('c_baron.avi', 8.0, 8.0, None, [(0.5, ('БАНДИТЫ СТРЕЛЯЮТ В ОТВЕТ', 'BANDITS SHOOT BACK'))], 0.5),
            ('c_l_drive.avi', 3.0, 14.0, ('МАШИНЫ', 'CARS'),
             [(0.5, ('ТАРАНЬ ЗОМБИ, ДРИФТУЙ, УЧАСТВУЙ В ЗАЕЗДАХ', 'RAM ZOMBIES, DRIFT, RACE')),
              (7.0, ('ТЮНИНГ, ПОКРАСКА, НЕОН, БРОНЯ', 'TUNING, PAINT, NEON, ARMOR'))], 0.5),
            ('c_harbor.avi', 6.0, 7.0, ('ЛОКАЦИИ', 'LOCATIONS'), [(0.5, ('МОРСКОЙ ПОРТ', 'SEAPORT'))], 0.4),
            ('c_mountain.avi', 6.0, 6.0, None, [(0.3, ('ГОРНЫЙ ПЕРЕВАЛ', 'MOUNTAIN PASS'))], 0.4),
            ('c_grave.avi', 6.0, 6.0, None, [(0.3, ('КЛАДБИЩЕ', 'GRAVEYARD'))], 0.4),
            ('c_l_forest.avi', 5.0, 6.0, None, [(0.3, ('ЛЕС', 'FOREST'))], 0.4),
            ('c_hub.avi', 0.5, 9.0, ('УБЕЖИЩЕ', 'SHELTER'),
             [(0.5, ('СПАСЁННЫЕ ЛЮДИ ЖИВУТ С ТОБОЙ', 'RESCUED PEOPLE LIVE WITH YOU')),
              (5.0, ('СТРОЙ, КОРМИ, РАСШИРЯЙ ДО КРЕПОСТИ', 'BUILD, FEED, EXPAND TO A FORTRESS'))], 0.4),
            ('c_l_camp.avi', 1.0, 8.0, None, [(0.5, ('РАЗГОВОРЫ У КОСТРА', 'CAMPFIRE TALKS'))], 0.6),
            ('c_l_raid.avi', 3.0, 12.0, ('ОБОРОНА', 'DEFENSE'),
             [(0.5, ('НАБЕГИ ОРДЫ НА УБЕЖИЩЕ', 'HORDE RAIDS ON YOUR SHELTER')),
              (6.0, ('ТУРЕЛИ, КАПКАНЫ, МИНЫ', 'TURRETS, TRAPS, MINES'))], 0.5),
            ('c_street.avi', 12.0, 6.0, ('И ЕЩЁ', 'AND MORE'),
             [(0.3, ('ИГРА ПО WI-FI ДО 4 ИГРОКОВ, ДОСТИЖЕНИЯ, СОБЫТИЯ НЕДЕЛИ',
                     'UP TO 4 PLAYERS OVER WI-FI, ACHIEVEMENTS, WEEKLY EVENTS'))], 0.4),
        ],
    },
}
END_TEXT = {'ru': ('СКОРО В GOOGLE PLAY', 'ПОДПИШИСЬ, ЧТОБЫ НЕ ПРОПУСТИТЬ РЕЛИЗ'),
            'en': ('COMING SOON TO GOOGLE PLAY', 'SUBSCRIBE SO YOU DON\'T MISS THE RELEASE')}


def font(size):
    return ImageFont.truetype(FONT_PATH if os.path.exists(FONT_PATH) else FALLBACK_FONT, size)


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr[-2000:])
        sys.exit(1)


def centered(d, y, text, f, fill, stroke=6):
    d.text(((W - d.textlength(text, font=f)) / 2, y), text, font=f, fill=fill, stroke_width=stroke, stroke_fill=(0, 0, 0))


def backdrop():
    im = Image.open(os.path.join(ROOT, 'ui/splash/splash.jpg')).convert('RGB').resize((W, H), Image.LANCZOS)
    return Image.blend(im.filter(ImageFilter.GaussianBlur(6)), Image.new('RGB', (W, H)), 0.55)


def title_card(path, title, subtitle):
    im = backdrop()
    logo = Image.open(os.path.join(ROOT, 'ui/splash/title.png')).convert('RGBA')
    logo = logo.resize((1100, int(logo.height * 1100 / logo.width)), Image.LANCZOS)
    im.paste(logo, ((W - logo.width) // 2, 150), logo)
    d = ImageDraw.Draw(im)
    centered(d, 640, title, font(110), (255, 206, 60), 8)
    centered(d, 790, subtitle, font(52), (255, 255, 255), 4)
    im.save(path)


def end_card(path):
    im = backdrop()
    logo = Image.open(os.path.join(ROOT, 'ui/splash/title.png')).convert('RGBA')
    logo = logo.resize((1000, int(logo.height * 1000 / logo.width)), Image.LANCZOS)
    im.paste(logo, ((W - logo.width) // 2, 130), logo)
    d = ImageDraw.Draw(im)
    top, bottom = END_TEXT[LANG]
    centered(d, 640, top, font(80), (255, 206, 60), 6)
    f = font(46)
    bw = int(d.textlength(bottom, font=f)) + 100
    d.rounded_rectangle(((W - bw) / 2, 780, (W + bw) / 2, 880), radius=50, fill=(220, 30, 30))
    d.text(((W - d.textlength(bottom, font=f)) / 2, 802), bottom, font=f, fill=(255, 255, 255))
    centered(d, 940, 'SALAMANDERLAB', font(40), (220, 220, 220), 3)
    im.save(path)


def logo_card(path):
    im = Image.new('RGB', (W, H), (6, 23, 43))
    lg = Image.open(os.path.join(ROOT, 'ui/splash/salamanderlab.png')).convert('RGBA')
    s = min(900 / lg.width, 600 / lg.height)
    lg = lg.resize((int(lg.width * s), int(lg.height * s)), Image.LANCZOS)
    im.paste(lg, ((W - lg.width) // 2, (H - lg.height) // 2), lg)
    im.save(path)


def chapter_overlay(path, text):
    """Заголовок раздела слева сверху: красная полоса и крупные буквы."""
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    f = font(96)
    tw = d.textlength(text, font=f)
    d.rectangle((0, 90, tw + 150, 230), fill=(0, 0, 0, 150))
    d.rectangle((0, 90, 24, 230), fill=(220, 40, 30, 255))
    d.text((70, 100), text, font=f, fill=(255, 206, 60), stroke_width=6, stroke_fill=(0, 0, 0))
    im.save(path)


def caption_overlay(path, text):
    """Подпись внизу по центру на полупрозрачной плашке."""
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    f = font(58)
    tw = d.textlength(text, font=f)
    if tw > W - 160:
        f = font(int(58 * (W - 160) / tw))
        tw = d.textlength(text, font=f)
    d.rounded_rectangle(((W - tw) / 2 - 40, H - 210, (W + tw) / 2 + 40, H - 110), radius=20, fill=(0, 0, 0, 160))
    d.text(((W - tw) / 2, H - 198), text, font=f, fill=(255, 255, 255), stroke_width=4, stroke_fill=(0, 0, 0))
    im.save(path)


def main():
    e = LONG_EDITS[NAME]
    tmp = os.path.join(D, 'long_%s_%s' % (NAME, LANG))
    os.makedirs(tmp, exist_ok=True)
    logo_card(os.path.join(tmp, 'logo.png'))
    title_card(os.path.join(tmp, 'title.png'), e['title'][LI], e['subtitle'][LI])
    end_card(os.path.join(tmp, 'end.png'))
    segments = [('logo.png', 2.5, 0.0), ('title.png', 4.0, 0.0)]
    for i, (clip, start, length, chapter, captions, gain) in enumerate(e['parts']):
        out = os.path.join(tmp, 'part_%02d.mp4' % i)
        cmd = ['ffmpeg', '-v', 'error', '-y', '-ss', str(start), '-t', str(length), '-i', os.path.join(D, clip)]
        fc = '[0:v]scale=%d:%d,fps=%d,setsar=1[v0]' % (W, H, FPS)
        last = 'v0'
        overlays = []
        if chapter:
            overlays.append((chapter[LI], 0.2, min(length, 4.0), 'chapter'))
        for k, (at, text) in enumerate(captions):
            nxt = captions[k + 1][0] if k + 1 < len(captions) else length
            overlays.append((text[LI], at, nxt - 0.2, 'caption'))
        for k, (text, t0, t1, kind) in enumerate(overlays):
            png = os.path.join(tmp, 'ov_%02d_%02d.png' % (i, k))
            (chapter_overlay if kind == 'chapter' else caption_overlay)(png, text)
            cmd += ['-loop', '1', '-t', str(length), '-i', png]
            fc += ';[%d:v]format=rgba,fade=t=in:st=%.2f:d=0.3:alpha=1,fade=t=out:st=%.2f:d=0.3:alpha=1[o%d]' % (
                k + 1, t0, max(t0 + 0.3, t1 - 0.3), k)
            fc += ';[%s][o%d]overlay=0:0[v%d]' % (last, k, k + 1)
            last = 'v%d' % (k + 1)
        fc += ';[%s]format=yuv420p[v];[0:a]volume=%.2f,aresample=48000,apad[a]' % (last, gain)
        cmd += ['-filter_complex', fc, '-map', '[v]', '-map', '[a]', '-t', str(length), '-c:v', 'libx264', '-preset',
                'medium', '-crf', '19', '-c:a', 'aac', '-ar', '48000', '-ac', '2', out]
        run(cmd)
        segments.append((out, length, gain))
        print('часть %d/%d' % (i + 1, len(e['parts'])), flush=True)
    segments.append(('end.png', 6.0, 0.0))
    # Картинки → видео с тишиной
    files = []
    for k, (src, length, _g) in enumerate(segments):
        if src.endswith('.png'):
            out = os.path.join(tmp, 'card_%02d.mp4' % k)
            run(['ffmpeg', '-v', 'error', '-y', '-loop', '1', '-t', str(length), '-i', os.path.join(tmp, src), '-f', 'lavfi',
                 '-t', str(length), '-i', 'anullsrc=r=48000:cl=stereo', '-vf', 'fps=%d,format=yuv420p' % FPS,
                 '-c:v', 'libx264', '-crf', '19', '-c:a', 'aac', '-shortest', out])
            files.append((out, length))
        else:
            files.append((src, length))
    # Склейка через затемнение (xfade/acrossfade)
    inputs, fc, prev_v, prev_a, offset = [], '', '[0:v]', '[0:a]', 0.0
    for f, _l in files:
        inputs += ['-i', f]
    for i in range(1, len(files)):
        offset += files[i - 1][1] - FADE
        fc += '%s[%d:v]xfade=transition=fadeblack:duration=%s:offset=%.3f[xv%d];' % (prev_v, i, FADE, offset, i)
        fc += '%s[%d:a]acrossfade=d=%s[xa%d];' % (prev_a, i, FADE, i)
        prev_v, prev_a = '[xv%d]' % i, '[xa%d]' % i
    total = sum(l for _f, l in files) - FADE * (len(files) - 1)
    music = os.path.join(ROOT, 'audio', 'music', e['music'] + '.ogg')
    inputs += ['-stream_loop', '-1', '-i', music]
    fc += '[%d:a]atrim=0:%.2f,volume=%.2f,afade=t=in:d=1.5,afade=t=out:st=%.2f:d=3[m];' % (
        len(files), total, e['music_gain'], total - 3)
    fc += '%s[m]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000[aout]' % prev_a
    final = os.path.join(D, 'DeadZone_%s_%s.mp4' % (NAME, LANG))
    run(['ffmpeg', '-v', 'error', '-y'] + inputs + ['-filter_complex', fc, '-map', prev_v, '-map', '[aout]',
         '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart',
         '-t', '%.2f' % total, final])
    print(final, '%.1f с' % total)


if __name__ == '__main__':
    main()
