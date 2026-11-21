"""Static checks that run without Xcode (any OS with Python 3).

1. Every user-facing string literal found in the Swift UI code has an Arabic translation.
2. JSON resources (string catalog, asset catalog) parse.
3. Swift sources have balanced braces/brackets/parentheses outside strings and comments
   (a cheap guard against truncated files; it is NOT a compiler).

Run from the repository root:  python tools/check_strings.py
Exit code 0 = all checks passed.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from build_strings import AR  # noqa: E402

# Call sites whose first string-literal argument is a localization key.
KEY_PATTERNS = [
    r'\bText\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bLabel\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bButton\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bSection\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bToggle\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bPicker\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bMenu\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bTextField\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bSecureField\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bProgressView\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bLabeledContent\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bColorPicker\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bContentUnavailableView\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bNamePrompt\(title:\s*"((?:[^"\\]|\\.)*)"',
    r'\bString\(localized:\s*"((?:[^"\\]|\\.)*)"',
    r'\.navigationTitle\(\s*"((?:[^"\\]|\\.)*)"',
    r'\.accessibilityLabel\(\s*"((?:[^"\\]|\\.)*)"',
    r'\.accessibilityHint\(\s*"((?:[^"\\]|\\.)*)"',
    r'\.confirmationDialog\(\s*"((?:[^"\\]|\\.)*)"',
    r'\.alert\(\s*"((?:[^"\\]|\\.)*)"',
    r'\btitle:\s*"((?:[^"\\]|\\.)*)"',
    r'\breason:\s*"((?:[^"\\]|\\.)*)"',
    r'\bdetail:\s*"((?:[^"\\]|\\.)*)"',
    r'\btwemojiSection\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bsummary:\s*"((?:[^"\\]|\\.)*)"',
    r'\bnote:\s*"((?:[^"\\]|\\.)*)"',
    r'\bStepper\(\s*"((?:[^"\\]|\\.)*)"',
    r':\s*LocalizedStringKey\s*=\s*[^"]*?\?\s*"((?:[^"\\]|\\.)*)"',
    r':\s*LocalizedStringKey\s*=\s*[^"]*?\?\s*"(?:[^"\\]|\\.)*"\s*:\s*"((?:[^"\\]|\\.)*)"',
    r'\breturn\s+"((?:[^"\\]|\\.)*)"\s*$',
]


def catalog_key(literal: str, source: str) -> str:
    """Converts Swift interpolation to the format specifier the string catalog uses."""
    def replace(match: re.Match) -> str:
        expression = match.group(1)
        # String-typed interpolations in this codebase; everything else is an integer.
        return "%@" if expression in {"milestone", "text", "name", "function", "time"} else "%lld"
    return re.sub(r"\\\(([^)]*)\)", replace, literal)


def check_translations() -> list[str]:
    problems = []
    used = set()
    for path in sorted((ROOT / "App").rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        for pattern in KEY_PATTERNS:
            for match in re.finditer(pattern, text, flags=re.MULTILINE):
                literal = match.group(1)
                # `return "..."` also matches SF Symbol names and other non-UI strings: only
                # count it inside computed properties typed LocalizedStringKey.
                if pattern.startswith(r"\breturn"):
                    head = text[: match.start()]
                    opener = head.rfind("LocalizedStringKey {")
                    other = max(head.rfind("String {"), head.rfind("String? {"))
                    if opener == -1 or other > opener:
                        continue
                if not literal:
                    continue
                key = catalog_key(literal, text)
                used.add(key)
                if key not in AR:
                    problems.append(f"{path.relative_to(ROOT)}: no Arabic translation for {key!r}")
    for key in sorted(set(AR) - used):
        problems.append(f"build_strings.py: entry {key!r} is not used by any Swift file")
    print(f"translations: {len(used)} keys used in code, {len(AR)} in catalog")
    return problems


def check_json() -> list[str]:
    problems = []
    files = list((ROOT / "App").rglob("*.json")) + list((ROOT / "App").rglob("*.xcstrings"))
    for path in files:
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except Exception as error:  # noqa: BLE001
            problems.append(f"{path.relative_to(ROOT)}: invalid JSON ({error})")
    catalog = ROOT / "App" / "Resources" / "Localizable.xcstrings"
    if catalog.exists():
        data = json.loads(catalog.read_text(encoding="utf-8"))
        if set(data["strings"]) != set(AR):
            problems.append("Localizable.xcstrings is stale: run python tools/build_strings.py")
    else:
        problems.append("Localizable.xcstrings is missing: run python tools/build_strings.py")
    print(f"json: {len(files)} files parsed")
    return problems


def strip_swift(text: str) -> str:
    """Removes comments and string literals (keeping interpolation code is not needed here)."""
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    out = []
    for line in text.splitlines():
        result = []
        i = 0
        in_string = False
        while i < len(line):
            ch = line[i]
            if in_string:
                if ch == "\\":
                    i += 2
                    continue
                if ch == '"':
                    in_string = False
            else:
                if ch == '"':
                    in_string = True
                elif line.startswith("//", i):
                    break
                else:
                    result.append(ch)
            i += 1
        out.append("".join(result))
    return "\n".join(out)


def check_balance() -> list[str]:
    problems = []
    pairs = {")": "(", "]": "[", "}": "{"}
    files = sorted(list((ROOT / "App").rglob("*.swift")) + list((ROOT / "Packages").rglob("*.swift")))
    for path in files:
        stack = []
        code = strip_swift(path.read_text(encoding="utf-8"))
        for line_number, line in enumerate(code.splitlines(), start=1):
            for ch in line:
                if ch in "([{":
                    stack.append((ch, line_number))
                elif ch in pairs:
                    if not stack or stack[-1][0] != pairs[ch]:
                        problems.append(f"{path.relative_to(ROOT)}:{line_number}: unbalanced {ch!r}")
                        stack = []
                        break
                    stack.pop()
        if stack:
            problems.append(f"{path.relative_to(ROOT)}:{stack[-1][1]}: unclosed {stack[-1][0]!r}")
    print(f"balance: {len(files)} Swift files scanned")
    return problems


if __name__ == "__main__":
    all_problems = check_translations() + check_json() + check_balance()
    for problem in all_problems:
        print("FAIL", problem)
    print("OK" if not all_problems else f"{len(all_problems)} problem(s)")
    sys.exit(1 if all_problems else 0)
