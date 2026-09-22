#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

def verify_arb(arb_file: str, base_file: str = "lib/l10n/app_zh.arb") -> bool:
    path = Path(arb_file)
    if not path.exists():
        print(f"❌ File not found: {arb_file}")
        return False

    with open(base_file, "r", encoding="utf-8") as f:
        base_data = json.load(f)
    base_keys = {k: v for k, v in base_data.items() if not k.startswith("@")}

    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"❌ JSON parse error in {arb_file}: {e}")
        return False

    if "@@locale" not in data:
        print(f"❌ Missing @@locale in {arb_file}")
        return False

    target_keys = {k: v for k, v in data.items() if not k.startswith("@")}

    # Check key completeness
    missing = set(base_keys.keys()) - set(target_keys.keys())
    extra = set(target_keys.keys()) - set(base_keys.keys())
    if missing:
        print(f"❌ {arb_file}: Missing {len(missing)} keys: {list(missing)[:10]}...")
        return False
    if extra:
        print(f"❌ {arb_file}: Extra {len(extra)} keys: {list(extra)[:10]}...")
        return False

    # Check placeholders
    placeholder_errors = []
    for k, base_val in base_keys.items():
        base_ph = set(re.findall(r"\{([a-zA-Z0-9_]+)\}", base_val))
        target_val = target_keys.get(k, "")
        target_ph = set(re.findall(r"\{([a-zA-Z0-9_]+)\}", target_val))
        if base_ph != target_ph:
            placeholder_errors.append(f"Key '{k}': expected {base_ph}, got {target_ph} in '{target_val}'")

    if placeholder_errors:
        print(f"❌ {arb_file}: {len(placeholder_errors)} placeholder mismatches:")
        for err in placeholder_errors[:10]:
            print(f"   - {err}")
        return False

    print(f"✅ {arb_file}: PASS ({len(target_keys)} keys, locale '{data['@@locale']}')")
    return True

if __name__ == "__main__":
    files = sys.argv[1:] if len(sys.argv) > 1 else [
        "lib/l10n/app_en.arb",
        "lib/l10n/app_zh_HK.arb",
        "lib/l10n/app_zh_TW.arb",
        "lib/l10n/app_ru.arb",
    ]
    all_ok = True
    for f in files:
        if not verify_arb(f):
            all_ok = False
    sys.exit(0 if all_ok else 1)
