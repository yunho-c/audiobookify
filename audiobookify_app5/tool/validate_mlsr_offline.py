#!/usr/bin/env python3
"""Build and run the real reader in a sandboxed, network-disabled release copy."""

import argparse
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile


APP_ROOT = Path(__file__).resolve().parents[1]
APP = APP_ROOT / "build/macos/Build/Products/Release/audiobookify_app5.app"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter", default=shutil.which("flutter") or "flutter")
    parser.add_argument("--no-build", action="store_true", help="Use an already-built offline test target")
    parser.add_argument(
        "--source-cache-file", type=Path,
        default=Path.home() / ".cache/mlsr/models/supertonic3-coreml-fp16-t384-voices-v1/unicode_indexer.json",
    )
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("This qualification targets macOS Apple Silicon")
    source = args.source_cache_file.resolve(strict=True)
    (APP_ROOT / ".mlsr").mkdir(exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix="release-offline-", dir=APP_ROOT / ".mlsr"))
    print(f"Validation artifacts: {output}", flush=True)
    if not args.no_build:
        subprocess.run([
            args.flutter, "build", "macos", "--release", "--no-pub",
            "--target=integration_test/mlsr_reader_test.dart",
            "--dart-define=MLSR_TEST_STANDALONE=true",
            "--dart-define=MLSR_TEST_OFFLINE=true",
            f"--dart-define=MLSR_TEST_FORBIDDEN_FILE={source}",
        ], cwd=APP_ROOT, check=True)
    app = output / APP.name
    # APFS clones keep this isolated test copy from duplicating the model bytes.
    subprocess.run(["cp", "-cR", str(APP), str(app)], check=True)
    signed = subprocess.run(
        ["codesign", "-d", "--entitlements", ":-", str(app)],
        check=True, text=True, capture_output=True,
    )
    entitlements = plistlib.loads(signed.stdout.encode())
    if entitlements.get("com.apple.security.app-sandbox") is not True:
        raise RuntimeError("Release validation requires App Sandbox to remain enabled")
    entitlements.pop("com.apple.security.network.client", None)
    entitlements.pop("com.apple.security.network.server", None)
    entitlement_file = output / "offline.entitlements"
    entitlement_file.write_bytes(plistlib.dumps(entitlements))
    subprocess.run([
        "codesign", "--force", "--sign", "-", "--entitlements", str(entitlement_file), str(app),
    ], check=True)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    with (output / "run.log").open("w") as log:
        completed = subprocess.run(
            [str(app / "Contents/MacOS/audiobookify_app5")], cwd=APP_ROOT,
            stdout=log, stderr=subprocess.STDOUT, timeout=240,
        )
    match = re.search(r"MLSR_VALIDATION_REPORT=(.+)", (output / "run.log").read_text())
    if not match:
        raise RuntimeError(f"Release test exited {completed.returncode} without a report; see {output / 'run.log'}")
    evidence = Path(match.group(1).strip())
    for name in ["summary.json", "reader.png"]:
        if (evidence / name).is_file():
            shutil.copy2(evidence / name, output / name)
    report = json.loads((output / "summary.json").read_text())
    passed = completed.returncode == 0 and all(report.get(key) is True for key in [
        "passed", "test_suite_passed", "network_and_source_cache_denied",
    ])
    print(json.dumps({"passed": passed, "process_exit": completed.returncode, "report": str(output / "summary.json")}, indent=2))
    print("Rebuild lib/main.dart before using the release product as the normal app.")
    return 0 if passed else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
