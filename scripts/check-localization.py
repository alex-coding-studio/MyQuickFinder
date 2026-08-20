#!/usr/bin/env python3
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCES = ROOT / "Sources"
CATALOG = SOURCES / "Localizable.xcstrings"
LANGUAGES = ("zh-Hans", "en")
NAMESPACES = (
    "a11y",
    "action",
    "breadcrumb",
    "command",
    "favorites",
    "help",
    "key",
    "list",
    "menu",
    "menubar",
    "panel",
    "picker",
    "settings",
    "status",
)

CJK = re.compile(r"[　-〿一-鿿＀-￯]")
LITERAL = re.compile(r'"([^"\\\n]*)"')
KEY_SHAPE = re.compile(r"^[a-z][A-Za-z0-9]*(\.[A-Za-z0-9]+)+$")

failures = []


def swift_files():
    return sorted(SOURCES.rglob("*.swift"))


def check_no_hardcoded_prose():
    for path in swift_files():
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if CJK.search(line):
                failures.append(
                    f"{path.relative_to(ROOT)}:{number} 用户可见文本必须走 Localizable.xcstrings: {line.strip()}"
                )


def values(entry, language):
    localization = entry.get("localizations", {}).get(language)
    if localization is None:
        return []
    if "stringUnit" in localization:
        return [localization["stringUnit"].get("value", "")]
    plural = localization.get("variations", {}).get("plural", {})
    return [unit.get("stringUnit", {}).get("value", "") for unit in plural.values()]


def check_catalog(catalog):
    for key, entry in catalog["strings"].items():
        for language in LANGUAGES:
            rendered = values(entry, language)
            if not rendered or any(not value for value in rendered):
                failures.append(f"Localizable.xcstrings: {key} 缺 {language} 译文")


def check_keys_match_sources(catalog):
    literals = set()
    for path in swift_files():
        literals.update(LITERAL.findall(path.read_text(encoding="utf-8")))

    referenced = set()
    for path in swift_files():
        text = path.read_text(encoding="utf-8")
        for key in catalog["strings"]:
            if f'"{key.split(" %")[0]}' in text:
                referenced.add(key)

    for key in sorted(set(catalog["strings"]) - referenced):
        failures.append(f"Localizable.xcstrings: {key} 没有任何代码引用")

    bases = {key.split(" %")[0] for key in catalog["strings"]}
    for literal in sorted(literals):
        if not KEY_SHAPE.match(literal):
            continue
        if literal.split(".")[0] not in NAMESPACES:
            continue
        if literal not in bases:
            failures.append(f"Sources: {literal} 不在 Localizable.xcstrings 里")


catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
check_no_hardcoded_prose()
check_catalog(catalog)
check_keys_match_sources(catalog)

if failures:
    for failure in failures:
        print(failure, file=sys.stderr)
    sys.exit(1)

print(f"Localization checks passed ({len(catalog['strings'])} keys).")
