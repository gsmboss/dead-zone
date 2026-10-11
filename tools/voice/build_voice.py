#!/usr/bin/env python3
"""Озвучка реплик нейросетью Piper (бесплатно, без интернета после скачивания голосов).

Собирает все реплики игры из .tres (сюжетное кино, вступление, интро миссий, разговоры у костра),
озвучивает голосом роли из tools/voice/voices.json и кладёт в audio/voice/<язык>/<ключ>.ogg.
Ключ — первые 16 знаков md5 текста (как VoiceOver.file_key в игре). Уже готовые файлы не переделываются.

Установка (один раз):
    python3 -m venv .venv-voice && .venv-voice/bin/pip install piper-tts numpy
    (нужен ffmpeg: на Маке — brew install ffmpeg)
Запуск из корня проекта:
    .venv-voice/bin/python tools/voice/build_voice.py            # всё
    .venv-voice/bin/python tools/voice/build_voice.py --lang ru  # только русский
    .venv-voice/bin/python tools/voice/build_voice.py --list     # только список реплик и ролей
    .venv-voice/bin/python tools/voice/build_voice.py --force    # переозвучить всё заново
Голоса скачиваются с huggingface.co в tools/voice/models/ (в .gitignore).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).resolve().parent
MODELS_DIR = TOOLS / "models"
OUT_DIR = ROOT / "audio" / "voice"
MANIFEST = TOOLS / "manifest.json"
SPEAKER_CACHE = TOOLS / "speaker_cache.json"
HF = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0"
SAMPLE_RATE = 22050
# Высота голоса для auto:female / auto:male (Гц)
FEMALE_F0 = 175.0
MALE_F0 = 140.0
AUTO_SCAN = 120  # сколько голосов многоголосой модели прослушать при подборе
CAMP_ROLES = ["camp_1", "camp_2", "camp_3", "camp_4"]
# Пары голосов для диалогов у костра (реплики по очереди)
CAMP_PAIRS = [("camp_1", "camp_2"), ("camp_2", "camp_3"), ("camp_4", "camp_1"), ("camp_3", "camp_4")]


# ---------- Чтение .tres ----------

STRING_RE = r'"((?:[^"\\]|\\.)*)"'


def unescape(text: str) -> str:
    """Строка Godot в кавычках → текст (как его увидит игра)."""
    out = []
    i = 0
    while i < len(text):
        c = text[i]
        if c == "\\" and i + 1 < len(text):
            n = text[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(n, n))
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def strings_in(fragment: str) -> list[str]:
    return [unescape(m) for m in re.findall(STRING_RE, fragment)]


def sections(text: str) -> list[str]:
    """Разделы [sub_resource]/[resource] файла."""
    return re.split(r"^\[(?:sub_resource|resource)[^\]]*\]\s*$", text, flags=re.M)[1:]


def prop(section: str, name: str) -> str | None:
    m = re.search(r"^" + re.escape(name) + r" = " + STRING_RE + r"\s*$", section, re.M)
    return unescape(m.group(1)) if m else None


def array_prop(section: str, name: str) -> list[str]:
    m = re.search(r"^" + re.escape(name) + r" = PackedStringArray\((.*)\)\s*$", section, re.M)
    return strings_in(m.group(1)) if m else []


def nested_prop(section: str, name: str) -> list[list[str]]:
    """Array[PackedStringArray]([PackedStringArray(...), ...])"""
    m = re.search(r"^" + re.escape(name) + r" = Array\[PackedStringArray\]\(\[(.*)\]\)\s*$", section, re.M)
    if not m:
        return []
    groups = re.findall(r"PackedStringArray\(((?:" + STRING_RE + r"|[^()\"])*)\)", m.group(1))
    return [strings_in(g[0]) for g in groups]


def spoken(text: str) -> str:
    """Как MissionManager._spoken: строчными, первая заглавная."""
    lower = text.strip().lower()
    return lower[:1].upper() + lower[1:] if lower else lower


def collect() -> list[dict]:
    """Все реплики: {lang, text, role, source}."""
    lines: list[dict] = []

    def add(lang: str, text: str, role: str, source: str) -> None:
        if text and text.strip():
            lines.append({"lang": lang, "text": text, "role": role, "source": source})

    # Сюжетное кино: роль — говорящий, без него — рассказчик
    for path in sorted((ROOT / "story" / "films").glob("*.tres")):
        for section in sections(path.read_text(encoding="utf-8")):
            speaker = prop(section, "speaker") or "narrator"
            for lang in ("ru", "en"):
                add(lang, prop(section, "voice_" + lang) or "", speaker, path.name)

    # Вступление в убежище — рассказчик
    for path in sorted((ROOT / "cutscene").glob("*.tres")):
        if path.name == "voice_lines.tres":
            continue
        for section in sections(path.read_text(encoding="utf-8")):
            for lang in ("ru", "en"):
                add(lang, prop(section, "voice_" + lang) or "", "narrator", path.name)

    # Интро миссий и босс: подстановки {location}/{boss} (только в русских)
    locations, bosses = mission_names()
    voice_lines = ROOT / "cutscene" / "voice_lines.tres"
    if voice_lines.exists():
        for section in sections(voice_lines.read_text(encoding="utf-8")):
            for group in ("location", "goal", "fight", "boss"):
                for lang in ("ru", "en"):
                    for text in array_prop(section, f"{group}_{lang}"):
                        for variant in expand(text, locations, bosses):
                            add(lang, variant, "narrator", voice_lines.name)

    # Разговоры у костра
    chatter = ROOT / "hub" / "camp_chatter.tres"
    if chatter.exists():
        section = sections(chatter.read_text(encoding="utf-8"))[-1]
        for lang in ("ru", "en"):
            for index, dialogue in enumerate(nested_prop(section, "dialogues_" + lang)):
                pair = CAMP_PAIRS[index % len(CAMP_PAIRS)]
                for line_index, text in enumerate(dialogue):
                    add(lang, text, pair[line_index % 2], chatter.name)
            for index, text in enumerate(array_prop(section, "solo_" + lang)):
                add(lang, text, CAMP_ROLES[index % len(CAMP_ROLES)], chatter.name)
            for index, joke in enumerate(nested_prop(section, "jokes_" + lang)):
                for line_index, text in enumerate(joke):
                    add(lang, text, "player" if line_index % 2 == 0 else CAMP_ROLES[index % len(CAMP_ROLES)],
                        chatter.name)
            for index, text in enumerate(array_prop(section, "facts_" + lang)):
                add(lang, text, CAMP_ROLES[(index + 1) % len(CAMP_ROLES)], chatter.name)
            for text in array_prop(section, "ask_" + lang):
                add(lang, text, "player", chatter.name)

    # Один текст — одна запись (первая роль побеждает)
    unique: dict[tuple[str, str], dict] = {}
    for line in lines:
        unique.setdefault((line["lang"], line["text"]), line)
    return list(unique.values())


def mission_names() -> tuple[list[str], list[str]]:
    """Названия локаций и боссов, которые MissionManager подставляет в реплики."""
    locations: set[str] = set()
    data = (ROOT / "missions" / "mission_data.gd").read_text(encoding="utf-8")
    block = re.search(r"const LOCATIONS: Dictionary = \{(.*?)\}", data, re.S)
    if block:
        for key, value in re.findall(STRING_RE + r"\s*:\s*" + STRING_RE, block.group(1)):
            locations.add(unescape(value))
    bosses: set[str] = set()
    for path in (ROOT / "missions" / "data").glob("*.tres"):
        text = path.read_text(encoding="utf-8")
        override = re.search(r"^location_name = " + STRING_RE, text, re.M)
        if override:
            locations.add(unescape(override.group(1)))
        boss_ref = re.search(r'^boss = ExtResource\("([^"]+)"\)', text, re.M)
        if boss_ref:
            ext = re.search(r'\[ext_resource[^\]]*path="res://([^"]+)"[^\]]*id="' + re.escape(boss_ref.group(1)) + '"',
                            text)
            if ext and (ROOT / ext.group(1)).exists():
                name = prop((ROOT / ext.group(1)).read_text(encoding="utf-8"), "display_name")
                if name:
                    bosses.add(name)
    return sorted(locations), sorted(bosses)


def expand(text: str, locations: list[str], bosses: list[str]) -> list[str]:
    if "{location}" in text:
        return [text.replace("{location}", spoken(name)) for name in locations]
    if "{boss}" in text:
        return [text.replace("{boss}", spoken(name)) for name in bosses]
    return [text]


def file_key(text: str) -> str:
    return hashlib.md5(text.encode("utf-8")).hexdigest()[:16]


# ---------- Голоса ----------

def download_model(name: str) -> Path:
    lang_code = name.split("_")[0]
    locale, voice, quality = name.split("-")
    base = f"{HF}/{lang_code}/{locale}/{voice}/{quality}/{name}"
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    model = MODELS_DIR / f"{name}.onnx"
    for url, target in ((base + ".onnx", model), (base + ".onnx.json", MODELS_DIR / f"{name}.onnx.json"),
                        (f"{HF}/{lang_code}/{locale}/{voice}/{quality}/MODEL_CARD",
                         MODELS_DIR / f"{name}.MODEL_CARD.txt")):
        if target.exists():
            continue
        print(f"  скачиваю {url}")
        try:
            urllib.request.urlretrieve(url + "?download=true", target)
        except Exception as error:  # noqa: BLE001
            if target.suffix == ".txt":
                print(f"  (нет MODEL_CARD: {error})")
                continue
            sys.exit(f"Не удалось скачать голос {name}: {error}\n"
                     "Нужен доступ к huggingface.co (в облаке — разрешить домен в настройках среды).")
    return model


class Voices:
    def __init__(self) -> None:
        from piper import PiperVoice  # noqa: PLC0415
        self._piper_voice = PiperVoice
        self._loaded: dict[str, object] = {}
        self._cache = json.loads(SPEAKER_CACHE.read_text()) if SPEAKER_CACHE.exists() else {}

    def get(self, model: str):
        if model not in self._loaded:
            path = download_model(model)
            self._loaded[model] = self._piper_voice.load(str(path))
        return self._loaded[model]

    def synthesize(self, model: str, text: str, speaker: int | None, length: float, wav_path: Path) -> None:
        from piper import SynthesisConfig  # noqa: PLC0415
        voice = self.get(model)
        config = SynthesisConfig(speaker_id=speaker, length_scale=length, noise_scale=0.667, noise_w_scale=0.8)
        with wave.open(str(wav_path), "wb") as wav_file:
            voice.synthesize_wav(text, wav_file, syn_config=config)

    def resolve_speaker(self, model: str, spec) -> int | None:
        """speaker: число, None или auto:female:N / auto:male:N (по высоте голоса тестовой фразы)."""
        if spec is None or isinstance(spec, int):
            return spec
        _, gender, number = str(spec).split(":")
        found = self._scan(model)[gender]
        if int(number) >= len(found):
            sys.exit(f"Мало голосов {gender} в {model}: нужен №{number}, найдено {len(found)}")
        return found[int(number)]

    def _scan(self, model: str) -> dict[str, list[int]]:
        if model in self._cache:
            return self._cache[model]
        import numpy as np  # noqa: PLC0415
        voice = self.get(model)
        count = int(getattr(voice.config, "num_speakers", 1) or 1)
        print(f"  подбираю голоса {model}: {min(count, AUTO_SCAN)} из {count}")
        result: dict[str, list[int]] = {"female": [], "male": []}
        with tempfile.TemporaryDirectory() as tmp:
            for speaker in range(min(count, AUTO_SCAN)):
                wav_path = Path(tmp) / "probe.wav"
                self.synthesize(model, "Hello there, the zombies are coming, stay close to the fire.", speaker, 1.0,
                                wav_path)
                with wave.open(str(wav_path), "rb") as wav_file:
                    rate = wav_file.getframerate()
                    samples = np.frombuffer(wav_file.readframes(wav_file.getnframes()), dtype=np.int16)
                f0 = estimate_f0(samples.astype(np.float32), rate)
                if f0 >= FEMALE_F0:
                    result["female"].append(speaker)
                elif 0 < f0 <= MALE_F0:
                    result["male"].append(speaker)
        self._cache[model] = result
        SPEAKER_CACHE.write_text(json.dumps(self._cache, indent=1))
        return result


def estimate_f0(samples, rate: int) -> float:
    """Средняя высота голоса по автокорреляции громких кусков (грубо, для мужской/женской)."""
    import numpy as np  # noqa: PLC0415
    frame = int(rate * 0.04)
    values = []
    lo, hi = int(rate / 400), int(rate / 70)
    for start in range(0, len(samples) - frame, frame):
        chunk = samples[start:start + frame]
        if np.sqrt(np.mean(chunk ** 2)) < 500:
            continue
        chunk = chunk - chunk.mean()
        corr = np.correlate(chunk, chunk, "full")[frame - 1:]
        if corr[0] <= 0:
            continue
        lag = lo + int(np.argmax(corr[lo:hi]))
        if corr[lag] / corr[0] > 0.45:
            values.append(rate / lag)
    return float(np.median(values)) if values else 0.0


def clean_for_speech(text: str) -> str:
    """Без значков, которые синтезатор читает вслух или на которых спотыкается."""
    result = text.replace("\n", " ")
    for symbol in ("*", "▸", "▼", "•", "«", "»", "„", "“", "”"):
        result = result.replace(symbol, "")
    result = result.replace(" — ", ", ").replace("—", ", ").replace("…", "...")
    return re.sub(r"\s+", " ", result).strip()


def encode(wav_path: Path, ogg_path: Path, pitch: float) -> None:
    """Сдвиг тона без изменения темпа, выравнивание громкости, OGG Vorbis моно."""
    filters = []
    if abs(pitch - 1.0) > 0.005:
        filters.append(f"asetrate={SAMPLE_RATE}*{pitch:.3f},aresample={SAMPLE_RATE},atempo={1.0 / pitch:.4f}")
    filters.append("loudnorm=I=-17:TP=-2:LRA=11")
    filters.append("silenceremove=start_periods=1:start_threshold=-50dB")
    ogg_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-af", ",".join(filters),
                    "-ac", "1", "-ar", str(SAMPLE_RATE), "-c:a", "libvorbis", "-q:a", "3", str(ogg_path)],
                   check=True)


def write_pack(lang: str, count: int) -> None:
    """Признак набора озвучки для VoiceOver (ResourceLoader.exists работает и в сборке)."""
    pack = OUT_DIR / lang / "voice_pack.tres"
    pack.parent.mkdir(parents=True, exist_ok=True)
    pack.write_text('[gd_resource type="Resource" format=3]\n\n[resource]\n'
                    f'metadata/lines = {count}\nmetadata/engine = "piper"\n', encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--lang", choices=["ru", "en"], action="append")
    parser.add_argument("--list", action="store_true", help="только показать реплики и роли")
    parser.add_argument("--force", action="store_true", help="переозвучить и готовые")
    parser.add_argument("--limit", type=int, default=0, help="озвучить не больше N новых (проба)")
    parser.add_argument("--role", action="append", help="только эти роли (проба голоса)")
    args = parser.parse_args()
    langs = args.lang or ["ru", "en"]
    config = json.loads((TOOLS / "voices.json").read_text(encoding="utf-8"))
    lines = [line for line in collect() if line["lang"] in langs]
    if args.role:
        lines = [line for line in lines if line["role"] in args.role]

    if args.list:
        for line in lines:
            print(f'{line["lang"]}  {file_key(line["text"])}  {line["role"]:<10} {line["text"]}')
        print(f"реплик: {len(lines)}")
        return
    if shutil.which("ffmpeg") is None:
        sys.exit("Нужен ffmpeg (на Маке: brew install ffmpeg)")

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    voices = Voices()
    made = 0
    with tempfile.TemporaryDirectory() as tmp:
        for number, line in enumerate(lines, 1):
            lang, text, role = line["lang"], line["text"], line["role"]
            roles = config["roles"][lang]
            spec = roles.get(role) or roles[CAMP_ROLES[int(file_key(role), 16) % len(CAMP_ROLES)]]
            key = file_key(text)
            ogg = OUT_DIR / lang / f"{key}.ogg"
            signature = json.dumps([text, spec], ensure_ascii=False, sort_keys=True)
            entry_id = f"{lang}/{key}"
            if ogg.exists() and not args.force and manifest.get(entry_id, {}).get("signature") == signature:
                continue
            if args.limit and made >= args.limit:
                break
            speaker = voices.resolve_speaker(spec["model"], spec.get("speaker"))
            wav = Path(tmp) / "line.wav"
            voices.synthesize(spec["model"], clean_for_speech(text), speaker, float(spec.get("length", 1.0)), wav)
            encode(wav, ogg, float(spec.get("pitch", 1.0)))
            manifest[entry_id] = {"text": text, "role": role, "signature": signature}
            made += 1
            print(f"[{number}/{len(lines)}] {lang} {role}: {text[:60]}")

    # Лишние записи (реплику убрали или поменяли текст) — удалить, если собирали все роли
    if not args.role and not args.limit:
        wanted = {f'{line["lang"]}/{file_key(line["text"])}' for line in lines}
        for lang in langs:
            for ogg in (OUT_DIR / lang).glob("*.ogg"):
                entry_id = f"{lang}/{ogg.stem}"
                if entry_id not in wanted:
                    ogg.unlink()
                    Path(str(ogg) + ".import").unlink(missing_ok=True)
                    manifest.pop(entry_id, None)
                    print(f"удалено: {entry_id}")
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")
    for lang in langs:
        count = len(list((OUT_DIR / lang).glob("*.ogg"))) if (OUT_DIR / lang).exists() else 0
        if count:
            write_pack(lang, count)
    print(f"готово: новых {made}")


if __name__ == "__main__":
    main()
