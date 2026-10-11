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
    # День 2: хедшоты подряд в замедлении
    'headshots': {
        'texts': {
            'hook': ('ХЕДШОТ ×5\nПОДРЯД', '5 HEADSHOTS\nIN A ROW'), 'x1': ('ХЕДШОТ\n×1', 'HEADSHOT\n×1'),
            'x2': ('ХЕДШОТ\n×2', 'HEADSHOT\n×2'), 'x3': ('ХЕДШОТ\n×3', 'HEADSHOT\n×3'), 'x4': ('ХЕДШОТ\n×4', 'HEADSHOT\n×4'),
            'x5': ('ХЕДШОТ\n×5!', 'HEADSHOT\n×5!'), 'you': ('А ТЫ\nСМОЖЕШЬ?', 'CAN YOU\nDO IT?'),
        },
        'segments': [
            ('hs_rifle.avi', 16.6, 4, 'cut', None, [(0, 'hook', 'Y', 'slam')]),
            ('hs_rifle.avi', 5.2, 6, 'rgb', SLOWMO, [(2, 'x1', 'W', 'slam', 'shot')]),
            ('v_grave.avi', 5.1, 6, 'whip', SLOWMO, [(2, 'x2', 'W', 'slam', 'shot')]),
            ('hs_awm.avi', 11.1, 6, 'rgb', SLOWMO, [(2, 'x3', 'Y', 'slam', 'shot')]),
            ('hs_pistol.avi', 6.5, 6, 'whip', SLOWMO, [(2, 'x4', 'Y', 'slam', 'shot')]),
            ('hs_rifle.avi', 12.6, 6, 'rgb', SLOWMO, [(2, 'x5', 'R', 'slam', 'boom')]),
            ('v_grave.avi', 10.8, 4, 'flash', None, [(0, 'you', 'W', 'pop')]),
            ('END', 0, 10, 'flash', None, []),
        ],
    },
    # День 3: босс Утопленник
    'boss': {
        'texts': {
            'hook': ('ЭТОТ БОСС\nВЫЛЕЗ ИЗ МОРЯ', 'THIS BOSS CAME\nOUT OF THE SEA'), 'name': ('УТОПЛЕННИК', 'THE DROWNED'),
            'head': ('ЦЕЛЬСЯ\nВ ГОЛОВУ', 'AIM FOR\nTHE HEAD'), 'more': ('5 БОССОВ\nВ ИГРЕ', '5 BOSSES\nIN THE GAME'),
            'win': ('СМОЖЕШЬ\nПОБЕДИТЬ?', 'CAN YOU\nBEAT THEM?'),
        },
        'segments': [
            ('boss_drowned.avi', 6.5, 4, 'cut', None, [(0, 'hook', 'W', 'slam', 'moan')]),
            ('boss_drowned.avi', 2.0, 8, 'rgb', None, [(1, 'name', 'R', 'slam', 'boom')], {'zoom': 1.3}),
            ('boss_drowned.avi', 8.0, 4, 'flash', None, [(0, 'head', 'Y', 'slam')]),
            ('boss_drowned.avi', 11.0, 4, 'punch', None, []),
            ('boss_drowned.avi', 14.0, 4, 'punch', None, []),
            ('v_mountain.avi', 9.3, 4, 'whip', None, [(0, 'more', 'Y', 'slam', 'moan')]),
            ('v_baron.avi', 10.0, 4, 'rgb', None, [(0, 'win', 'W', 'pop')]),
            ('END', 0, 10, 'flash', None, []),
        ],
    },
    # День 4: пролог — история в кадрах кино (спокойная музыка)
    'prologue': {
        'music': 'ambient_city',
        'texts': {
            'a': ('ЭТО БЫЛ\nОБЫЧНЫЙ ГОРОД', 'IT WAS AN\nORDINARY CITY'), 'b': ('МАМА, Я\nИ БРАТ ТЁМА', 'MOM, ME\nAND LITTLE TYOMA'),
            'c': ('ПОТОМ СЛУЧИЛСЯ\nПОЖАР', 'THEN CAME\nTHE FIRE'), 'd': ('ЗА ДВА ЧАСА\nГОРОД ПАЛ', 'IN TWO HOURS\nTHE CITY FELL'),
            'e': ('МАМА ОСТАЛАСЬ,\nЧТОБЫ МЫ УСПЕЛИ', 'MOM STAYED\nSO WE COULD RUN'), 'f': ('ТЁМА ПРОПАЛ', 'TYOMA WENT MISSING'),
            'g': ('НАЙДИ ЕГО', 'FIND HIM'),
        },
        'segments': [
            ('v_film{en}.avi', {'ru': 8.0, 'en': 8.0}, 8, 'cut', None, [(0, 'a', 'W', 'pop', None)]),
            ('v_film{en}.avi', FILM_T['family'], 8, 'flash', None, [(0, 'b', 'Y', 'pop', None)]),
            ('v_film{en}.avi', {'ru': 44.0, 'en': 45.0}, 8, 'rgb', None, [(0, 'c', 'R', 'pop', 'hit')]),
            ('v_film{en}.avi', FILM_T['fall'], 8, 'rgb', None, [(0, 'd', 'W', 'slam', 'moan')]),
            ('v_film{en}.avi', FILM_T['night'], 8, 'flash', None, [(0, 'e', 'Y', 'pop', None)]),
            ('v_film{en}.avi', {'ru': 62.0, 'en': 63.5}, 6, 'cut', None, [(0, 'f', 'W', 'pop', None)]),
            ('hs_rifle.avi', 12.0, 8, 'flash', None, [(0, 'g', 'R', 'slam', 'boom')]),
            ('END', 0, 10, 'flash', None, []),
        ],
    },
    # День 5: ближний бой
    'melee': {
        'texts': {
            'hook': ('ПАТРОНЫ\nКОНЧИЛИСЬ?', 'OUT OF\nAMMO?'), 'axe': ('ТОПОР', 'AXE'), 'bat': ('БИТА', 'BAT'),
            'spear': ('КОПЬЁ', 'SPEAR'), 'no': ('НЕ ПРОБЛЕМА', 'NO PROBLEM'), 'pick': ('ЧТО ВЫБЕРЕШЬ?', 'WHAT DO YOU PICK?'),
        },
        'segments': [
            ('hs_pistol.avi', 4.0, 4, 'cut', None, [(0, 'hook', 'W', 'slam', 'shot')]),
            ('melee_axe.avi', 6.0, 4, 'flash', None, [(0, 'no', 'Y', 'slam')]),
            ('melee_axe.avi', 9.0, 6, 'punch', None, [(0, 'axe', 'R', 'slam')]),
            ('melee_bat.avi', 7.0, 6, 'whip', None, [(0, 'bat', 'Y', 'slam')]),
            ('melee_spear.avi', 7.0, 6, 'whip', None, [(0, 'spear', 'W', 'slam')]),
            ('melee_axe.avi', 13.0, 4, 'rgb', None, [(0, 'pick', 'Y', 'pop')]),
            ('END', 0, 10, 'flash', None, []),
        ],
    },
    # День 6: машина
    'car': {
        'texts': {
            'hook': ('БАМПЕР —\nЛУЧШЕЕ ОРУЖИЕ', 'THE BUMPER IS\nTHE BEST WEAPON'), 'drift': ('ДРИФТ!', 'DRIFT!'),
            'ram': ('ТАРАН', 'RAM'), 'tune': ('ТЮНИНГ, НЕОН,\nБРОНЯ, ШИПЫ', 'TUNING, NEON,\nARMOR, SPIKES'),
            'race': ('ЗАЕЗДЫ\nПО ГОРОДУ', 'STREET\nRACES'),
        },
        'segments': [
            ('drive.avi', 6.0, 4, 'cut', None, [(0, 'hook', 'W', 'slam')]),
            ('drive.avi', 9.0, 6, 'flash', None, [(0, 'ram', 'R', 'slam', 'boom')]),
            ('drive.avi', 14.5, 6, 'rgb', None, [(0, 'drift', 'Y', 'slam')]),
            ('drive.avi', 18.0, 6, 'whip', None, [(0, 'tune', 'W', 'pop')]),
            ('drive.avi', 21.5, 6, 'punch', None, [(0, 'race', 'Y', 'pop')]),
            ('END', 0, 10, 'flash', None, []),
        ],
    },
    # День 7: убежище — было / стало
    'shelter': {
        'texts': {
            'hook': ('ЛАГЕРЬ →\nКРЕПОСТЬ', 'CAMP →\nFORTRESS'), 'before': ('БЫЛО', 'BEFORE'), 'after': ('СТАЛО', 'AFTER'),
            'feed': ('КОРМИ ЛЮДЕЙ', 'FEED YOUR PEOPLE'), 'build': ('СТРОЙ И\nРАСШИРЯЙ', 'BUILD AND\nEXPAND'),
        },
        'segments': [
            ('v_hub.avi', 1.0, 4, 'cut', None, [(0, 'hook', 'Y', 'slam')]),
            ('hub_lvl1.avi', 1.0, 8, 'flash', None, [(0, 'before', 'W', 'slam')]),
            ('hub_gate.avi', 1.0, 8, 'flash', None, [(0, 'after', 'Y', 'slam', 'boom')]),
            ('camp2.avi', 2.0, 6, 'whip', None, [(0, 'feed', 'W', 'pop')]),
            ('v_hub.avi', 4.0, 6, 'whip', None, [(0, 'build', 'Y', 'pop')]),
            ('END', 0, 10, 'flash', None, []),
        ],
    },
    # День 8: типы зомби
    'zombies': {
        'texts': {
            'hook': ('КТО ИЗ НИХ\nОПАСНЕЕ?', 'WHICH ONE IS\nMORE DANGEROUS?'), 'screamer': ('КРИКУН', 'SCREAMER'),
            'brute': ('БУГАЙ', 'BRUTE'), 'helmet': ('КАСКА', 'HELMET'), 'exploder': ('ВЗРЫВНОЙ', 'EXPLODER'),
            'spitter': ('ПЛЕВУН', 'SPITTER'), 'dog': ('СОБАКА', 'DOG'), 'crawler': ('ПОЛЗУН', 'CRAWLER'),
            'comment': ('ПИШИ\nВ КОММЕНТАХ', 'TELL US IN\nTHE COMMENTS'),
        },
        'segments': [
            ('z_brute.avi', 3.0, 4, 'cut', None, [(0, 'hook', 'W', 'slam', 'moan')]),
            ('z_screamer.avi', 2.5, 4, 'flash', None, [(0, 'screamer', 'Y', 'slam')]),
            ('z_brute.avi', 4.5, 4, 'punch', None, [(0, 'brute', 'R', 'slam')]),
            ('z_helmet.avi', 5.5, 4, 'punch', None, [(0, 'helmet', 'Y', 'slam')]),
            ('z_exploder.avi', 6.0, 4, 'punch', None, [(0, 'exploder', 'R', 'slam', 'boom')]),
            ('z_spitter.avi', 5.5, 4, 'punch', None, [(0, 'spitter', 'Y', 'slam')]),
            ('z_dog.avi', 1.5, 4, 'punch', None, [(0, 'dog', 'W', 'slam')]),
            ('z_crawler.avi', 4.5, 4, 'punch', None, [(0, 'crawler', 'Y', 'slam')]),
            ('z_helmet.avi', 7.5, 4, 'rgb', None, [(0, 'comment', 'W', 'pop')]),
            ('END', 0, 10, 'flash', None, []),
        ],
    },
    # День 9: жизнь у костра
    'camp': {
        'music': 'ambient_city',
        'texts': {
            'hook': ('ЖИЗНЬ\nУ КОСТРА', 'LIFE BY\nTHE CAMPFIRE'), 'saved': ('ЛЮДИ,\nКОТОРЫХ ТЫ СПАС', 'PEOPLE\nYOU SAVED'),
            'talk': ('ШУТЯТ, СПОРЯТ,\nЖАЛУЮТСЯ', 'JOKE, ARGUE\nAND COMPLAIN'), 'gosha': ('ДЯДЯ ГОША\nВАРИТ КОФЕ', 'UNCLE GOSHA\nMAKES COFFEE'),
            'home': ('ЭТО ТЕПЕРЬ\nТВОЙ ДОМ', 'THIS IS YOUR\nHOME NOW'),
        },
        'segments': [
            ('camp2.avi', 1.0, 8, 'cut', None, [(0, 'hook', 'Y', 'pop', None)]),
            ('camp2.avi', 4.5, 8, 'flash', None, [(0, 'saved', 'W', 'pop', None)]),
            ('camp2.avi', 8.5, 8, 'cut', None, [(0, 'talk', 'Y', 'pop', None)]),
            ('hub_gate.avi', 1.0, 8, 'flash', None, [(0, 'home', 'W', 'pop', None)]),
            ('END', 0, 10, 'flash', None, []),
        ],
    },
    # День 10: снайпер
    'sniper': {
        'texts': {
            'hook': ('ОДИН ВЫСТРЕЛ —\nОДИН ЗОМБИ', 'ONE SHOT —\nONE ZOMBIE'), 'awm': ('AWM', 'AWM'),
            'scope': ('ОПТИКА\nНА ВЕСЬ ЭКРАН', 'FULL-SCREEN\nSCOPE'), 'boom': ('ГОЛОВА — ПРОЧЬ', 'HEAD OFF'),
        },
        'segments': [
            ('hs_awm.avi', 8.0, 4, 'cut', None, [(0, 'hook', 'W', 'slam', 'shot')]),
            ('hs_awm.avi', 11.1, 6, 'rgb', SLOWMO, [(2, 'boom', 'R', 'slam', 'boom')]),
            ('hs_awm.avi', 5.0, 4, 'flash', None, [(0, 'awm', 'Y', 'slam', 'shot')]),
            ('hs_awm.avi', 12.4, 6, 'rgb', SLOWMO, [(2, 'scope', 'W', 'pop', 'shot')]),
            ('END', 0, 10, 'flash', None, []),
        ],
    },
    # День 11: набег на убежище
    'raid': {
        'texts': {
            'hook': ('ОРДА\nУ ВОРОТ!', 'HORDE AT\nTHE GATES!'), 'turret': ('ТУРЕЛИ', 'TURRETS'),
            'traps': ('КАПКАНЫ И МИНЫ', 'TRAPS AND MINES'), 'hold': ('ДЕРЖИ\nОБОРОНУ', 'HOLD\nTHE LINE'),
            'x2': ('НАГРАДА ×2', 'REWARD ×2'),
        },
        'segments': [
            ('raid3p.avi', 6.0, 4, 'cut', None, [(0, 'hook', 'R', 'slam', 'moan')]),
            ('raid3p.avi', 3.0, 6, 'flash', None, [(0, 'turret', 'Y', 'slam')]),
            ('raid1p.avi', 10.8, 6, 'whip', None, [(0, 'traps', 'W', 'slam', 'boom')]),
            ('raid3p.avi', 10.0, 6, 'punch', None, [(0, 'hold', 'Y', 'slam')]),
            ('raid1p.avi', 7.0, 4, 'rgb', None, [(0, 'x2', 'Y', 'pop')]),
            ('END', 0, 10, 'flash', None, []),
        ],
    },
    # День 12: бандиты
    'bandits': {
        'texts': {
            'hook': ('НЕ ВСЕ ВРАГИ —\nЗОМБИ', 'NOT EVERY ENEMY\nIS A ZOMBIE'), 'baron': ('БАРОН', 'THE BARON'),
            'gang': ('ЕГО БАНДА\nСТРЕЛЯЕТ В ОТВЕТ', 'HIS GANG\nSHOOTS BACK'), 'story': ('И ОН ЗНАЕТ,\nГДЕ ТЁМА', 'AND HE KNOWS\nWHERE TYOMA IS'),
        },
        'segments': [
            ('v_baron.avi', 10.0, 4, 'cut', None, [(0, 'hook', 'W', 'slam')]),
            ('film_baron{en}.avi', {'ru': 12.0, 'en': 14.0}, 8, 'flash', None, [(0, 'baron', 'R', 'slam', 'boom')]),
            ('loc_yard.avi', 7.0, 6, 'whip', None, [(0, 'gang', 'Y', 'slam', 'shot')]),
            ('v_baron.avi', 13.0, 4, 'punch', None, []),
            ('film_baron{en}.avi', 6.5, 8, 'rgb', None, [(0, 'story', 'W', 'pop')]),
            ('END', 0, 10, 'flash', None, []),
        ],
    },
    # День 13: локации
    'locations': {
        'texts': {
            'hook': ('8 ЛОКАЦИЙ', '8 LOCATIONS'), 'street': ('УЛИЦЫ', 'STREETS'), 'yard': ('СТОЯНКА', 'CONTAINER YARD'),
            'grave': ('КЛАДБИЩЕ', 'GRAVEYARD'), 'forest': ('ЛЕС', 'FOREST'), 'ind': ('ПРОМЗОНА', 'INDUSTRIAL ZONE'),
            'port': ('ПОРТ', 'SEAPORT'), 'mount': ('ГОРЫ', 'MOUNTAINS'), 'city': ('ОТКРЫТЫЙ ГОРОД', 'OPEN CITY'),
            'fav': ('КАКАЯ\nЛУЧШЕ?', 'WHICH ONE\nIS BEST?'),
        },
        'segments': [
            ('v_harbor.avi', 9.0, 4, 'cut', None, [(0, 'hook', 'Y', 'slam')]),
            ('v_street.avi', 12.0, 4, 'flash', None, [(0, 'street', 'W', 'slam')]),
            ('loc_yard.avi', 7.0, 4, 'punch', None, [(0, 'yard', 'W', 'slam')]),
            ('v_grave.avi', 8.0, 4, 'punch', None, [(0, 'grave', 'W', 'slam')]),
            ('loc_forest.avi', 5.5, 4, 'punch', None, [(0, 'forest', 'W', 'slam')]),
            ('loc_ind.avi', 4.0, 4, 'punch', None, [(0, 'ind', 'W', 'slam')]),
            ('v_harbor.avi', 12.0, 4, 'punch', None, [(0, 'port', 'W', 'slam')]),
            ('v_mountain.avi', 7.0, 4, 'punch', None, [(0, 'mount', 'W', 'slam')]),
            ('drive.avi', 10.0, 4, 'punch', None, [(0, 'city', 'W', 'slam')]),
            ('v_mountain.avi', 9.3, 4, 'rgb', None, [(0, 'fav', 'Y', 'pop')]),
            ('END', 0, 10, 'flash', None, []),
        ],
    },
}
# День 14: релиз — монтаж трейлера с концовкой «уже в Google Play»
EDITS['release'] = dict(EDITS['trailer'], end_text='out')
EDITS['release']['texts'] = dict(EDITS['trailer']['texts'], fall=('ВЫШЛА!', "IT'S OUT!"), night=('DEAD ZONE', 'DEAD ZONE'))
