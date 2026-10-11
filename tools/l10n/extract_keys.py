# Собрать ключи перевода: русские строки из .gd (кроме отладочных), .tres и .tscn (кроме реплик *_ru —
# у них свои английские поля). Запуск из корня проекта: python3 tools/l10n/extract_keys.py
# Печатает ключи, которых ещё нет в locale/en.json (их нужно перевести и добавить).
import re, glob, os, json, sys

cyr = re.compile(r'[А-Яа-яЁё]')
lit = re.compile(r'"((?:[^"\\]|\\.)*)"')
SKIP = ('push_warning', 'push_error', 'print(', 'assert(', 'printerr', 'print_verbose', '_warn')


def unescape(s):
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c == '\\' and i + 1 < len(s):
            n = s[i + 1]
            out.append({'n': '\n', 't': '\t', '"': '"', '\\': '\\', "'": "'"}.get(n, '\\' + n))
            i += 2
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def collect():
    keys = set()
    for f in glob.glob('**/*.gd', recursive=True):
        if f.startswith(('addons/', 'tools/')):
            continue
        for line in open(f, encoding='utf-8'):
            if line.strip().startswith('#') or any(k in line for k in SKIP):
                continue
            quoted = False
            cut = len(line)
            for i, ch in enumerate(line):
                if ch == '"' and (i == 0 or line[i - 1] != '\\'):
                    quoted = not quoted
                elif ch == '#' and not quoted:
                    cut = i
                    break
            for m in lit.finditer(line[:cut]):
                value = unescape(m.group(1))
                if cyr.search(value):
                    keys.add(value)
    for f in glob.glob('**/*.tres', recursive=True) + glob.glob('**/*.tscn', recursive=True):
        if f.startswith(('addons/', 'tools/')):
            continue
        for line in open(f, encoding='utf-8'):
            if re.match(r'^\w*_ru\s*=', line):
                continue
            for m in lit.finditer(line):
                value = unescape(m.group(1))
                if cyr.search(value):
                    keys.add(value)
    return keys


if __name__ == '__main__':
    known = json.load(open('locale/en.json', encoding='utf-8')) if os.path.exists('locale/en.json') else {}
    missing = sorted(k for k in collect() if k not in known)
    json.dump(missing, sys.stdout, ensure_ascii=False, indent=1)
    print('\n# не переведено: %d' % len(missing), file=sys.stderr)
