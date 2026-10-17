#!/usr/bin/env python3
# Титры и заставки трейлера (1920×1080 PNG): python3 tools/trailer/make_cards.py [папка] — запускать из корня проекта
import os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
W, H = 1920, 1080
BG = (6, 23, 43)
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')
os.makedirs(OUT, exist_ok=True)
CAPTIONS = {
    'ru': {'guns': 'ОРУЖИЕ, ОБВЕСЫ, ХЕДШОТЫ', 'bandits': 'ЗОМБИ И БАНДИТЫ', 'world': 'ПОРТ, ГОРЫ, КЛАДБИЩЕ, ГОРОД',
           'story': '30 ГЛАВ СЮЖЕТА', 'boss': 'БОССЫ', 'shelter': 'СВОЁ УБЕЖИЩЕ'},
    'en': {'guns': 'WEAPONS, ATTACHMENTS, HEADSHOTS', 'bandits': 'ZOMBIES AND BANDITS', 'world': 'PORT, MOUNTAINS, GRAVEYARD, CITY',
           'story': '30 STORY CHAPTERS', 'boss': 'BOSSES', 'shelter': 'BUILD YOUR SHELTER'},
}
END_TEXT = {'ru': 'СКОРО В GOOGLE PLAY', 'en': 'COMING SOON TO GOOGLE PLAY'}


def path(name):
    return os.path.join(OUT, name)


def logo():
    im = Image.new('RGB', (W, H), BG)
    lg = Image.open('ui/splash/salamanderlab.png').convert('RGBA')
    s = min(900 / lg.width, 600 / lg.height)
    lg = lg.resize((int(lg.width * s), int(lg.height * s)), Image.LANCZOS)
    im.paste(lg, ((W - lg.width) // 2, (H - lg.height) // 2), lg)
    im.save(path('card_logo.png'))


def end(lang):
    im = Image.open('ui/splash/splash.jpg').convert('RGB').resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(6))
    im = Image.blend(im, Image.new('RGB', (W, H)), 0.55)
    title = Image.open('ui/splash/title.png').convert('RGBA')
    title = title.resize((1300, int(title.height * 1300 / title.width)), Image.LANCZOS)
    im.paste(title, ((W - title.width) // 2, 170), title)
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT, 78)
    text = END_TEXT[lang]
    d.text(((W - d.textlength(text, font=f)) / 2, 760), text, font=f, fill=(255, 200, 70), stroke_width=5, stroke_fill=(0, 0, 0))
    f2 = ImageFont.truetype(FONT, 40)
    d.text(((W - d.textlength('SALAMANDERLAB', font=f2)) / 2, 880), 'SALAMANDERLAB', font=f2, fill=(220, 220, 220),
           stroke_width=3, stroke_fill=(0, 0, 0))
    im.save(path('card_end_%s.png' % lang))


def caption(name, text):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    band = Image.new('RGBA', (W, 190), (0, 0, 0, 150))
    im.paste(band, (0, H - 260), band)
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT, 84)
    w = d.textlength(text, font=f)
    d.text(((W - w) / 2, H - 225), text, font=f, fill=(255, 255, 255), stroke_width=6, stroke_fill=(0, 0, 0))
    d.rectangle(((W - w) / 2, H - 95, (W + w) / 2, H - 87), fill=(220, 60, 40))
    im.save(path('cap_%s.png' % name))


logo()
for lang, caps in CAPTIONS.items():
    end(lang)
    for key, text in caps.items():
        caption('%s_%s' % (key, lang), text)
print('готово:', OUT)
