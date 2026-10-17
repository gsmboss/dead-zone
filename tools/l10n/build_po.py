# Собрать locale/en.po из locale/en.json ({русская строка: английский перевод}).
# Запуск из корня проекта: python3 tools/l10n/build_po.py
import json


def po_escape(s):
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\t', '\\t')


data = json.load(open('locale/en.json', encoding='utf-8'))
lines = ['# Dead Zone — английский перевод. Ключи — русские строки. Не править вручную:',
         '# источник — locale/en.json, сборка — tools/l10n/build_po.py',
         'msgid ""', 'msgstr ""', '"Language: en\\n"', '"MIME-Version: 1.0\\n"',
         '"Content-Type: text/plain; charset=UTF-8\\n"', '"Content-Transfer-Encoding: 8bit\\n"', '']
for ru in sorted(data):
    en = data[ru]
    if not en:
        continue
    lines.append('msgid "%s"' % po_escape(ru))
    lines.append('msgstr "%s"' % po_escape(en))
    lines.append('')
open('locale/en.po', 'w', encoding='utf-8').write('\n'.join(lines))
print('en.po: %d строк перевода' % len(data))
