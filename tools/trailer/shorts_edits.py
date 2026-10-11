# Монтажи Shorts для tools/trailer/shorts.py: клипы (v_*.avi — вертикальные, снимает trailer_clip.tscn), надписи, музыка.
# Сегмент: (клип, начало в клипе, длина в долях такта, вход cut/punch/flash/rgb/whip, кривая скорости [(доля, x)] или None,
#           надписи [(доля, ключ texts или текст, цвет Y/R/W, стиль slam/pop, звук hit/boom/moan/shot/None)], {опции})
# Опции: voice — звук клипа (озвучка кино) громко, музыка тише; gain — громкость звука клипа; zoom — крупность кадра.
# {en} в имени клипа — «_en» в английской версии; начало можно задать {'ru': .., 'en': ..}.

MUSIC_BEATS = {'combat': (152.0, 0.255), 'ambient_city': (123.0, 0.275)}
MUSIC_GAIN = {'combat': 1.0, 'ambient_city': 1.8}

COMMON_TEXTS = {
    'soon': ('СКОРО В GOOGLE PLAY', 'COMING SOON TO GOOGLE PLAY'),
    'out': ('УЖЕ В GOOGLE PLAY!', 'OUT NOW ON GOOGLE PLAY!'),
    'sub': ('ПОДПИШИСЬ', 'SUBSCRIBE'),
}

SLOWMO = [(0, 1.0), (0.3, 1.0), (0.36, 0.3), (0.8, 0.3), (0.9, 1.0)]
FILM_T = {'fall': {'ru': 53.0, 'en': 54.0}, 'night': {'ru': 55.8, 'en': 57.2}, 'family': {'ru': 22.0, 'en': 20.5}}

EDITS = {
    # День 1: монтажный трейлер
    'trailer': {
        'texts': {
            'fall': ('ГОРОД ПАЛ', 'THE CITY FELL'), 'night': ('ЗА ОДНУ НОЧЬ', 'IN ONE NIGHT'),
            'everywhere': ('ОНИ ПОВСЮДУ', "THEY'RE EVERYWHERE"), 'grab': ('ХВАТАЙ\nОРУЖИЕ', 'GRAB\nA GUN'),
            'chop': ('РУБИ', 'CHOP'), 'shoot': ('СТРЕЛЯЙ', 'SHOOT'), 'head': ('ХЕДШОТ!', 'HEADSHOT!'),
            'bandits': ('БАНДИТЫ', 'BANDITS'), 'boss': ('И БОССЫ', 'AND BOSSES'), 'monsters': ('МОНСТРЫ', 'MONSTERS'),
            'shelter': ('СТРОЙ\nУБЕЖИЩЕ', 'BUILD YOUR\nSHELTER'), 'story': ('30 ГЛАВ\nСЮЖЕТА', '30 STORY\nCHAPTERS'),
        },
        'segments': [
            ('v_film{en}.avi', FILM_T['fall'], 4, 'cut', None, [(0, 'fall', 'W', 'slam')]),
            ('v_film{en}.avi', FILM_T['night'], 4, 'rgb', None, [(0, 'night', 'R', 'slam')]),
            ('v_harbor.avi', 11.5, 4, 'flash', None, [(0, 'everywhere', 'Y', 'pop', 'moan')]),
            ('v_street.avi', 12.0, 4, 'whip', None, [(0, 'grab', 'W', 'slam')]),
            ('v_axe.avi', 9.5, 2, 'punch', None, [(0, 'chop', 'Y', 'slam')]),
            ('v_grave.avi', 11.2, 2, 'punch', None, [(0, 'shoot', 'R', 'slam')]),
            ('v_bridge.avi', 10.0, 2, 'punch', None, []),
            ('v_street.avi', 5.0, 6, 'rgb', SLOWMO, [(2, 'head', 'R', 'slam', 'boom')]),
            ('v_baron.avi', 10.0, 4, 'whip', None, [(0, 'bandits', 'W', 'slam'), (2, 'boss', 'R', 'slam')]),
            ('v_mountain.avi', 9.3, 4, 'flash', None, [(0, 'monsters', 'Y', 'slam', 'moan')]),
            ('v_hub.avi', 1.5, 6, 'whip', None, [(0, 'shelter', 'Y', 'pop')]),
            ('v_film{en}.avi', FILM_T['family'], 4, 'rgb', None, [(0, 'story', 'W', 'pop')]),
            ('END', 0, 12, 'flash', None, []),
        ],
    },
}
