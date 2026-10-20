#!/usr/bin/env python3
"""Audit a built macOS app; this does not qualify playback or listening quality."""

import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys


RETIRED = re.compile(r"kokoro|onnxruntime|tvm|soloud|just_audio", re.IGNORECASE)
MACH_O = {
    b"\xfe\xed\xfa\xce", b"\xce\xfa\xed\xfe",
    b"\xfe\xed\xfa\xcf", b"\xcf\xfa\xed\xfe",
    b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca",
    b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca",
}


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def audit(app, package):
    problems = []
    files = [p for p in app.rglob("*") if p.is_file() and not p.is_symlink()]
    for path in files:
        if RETIRED.search(str(path.relative_to(app))) or path.suffix == ".onnx":
            problems.append(f"Retired asset/runtime: {path.relative_to(app)}")

    roots = list(app.glob("Contents/Frameworks/App.framework/**/flutter_assets/packages/mlsr_app_models"))
    # Framework version symlinks can expose the same directory more than once.
    roots = sorted({path.resolve() for path in roots})
    if len(roots) != 1:
        raise ValueError(f"Expected one bundled MLSR asset package, found {len(roots)}")
    bundled = roots[0]
    source = (package / "lib/app_models.dart").read_text()
    model_ids = re.findall(r'assetPath: "([^"]+)"', source)
    if len(model_ids) != 1:
        raise ValueError("This audit expects the app's single generated MLSR model")
    model_path = Path(model_ids[0])
    pins = re.findall(
        r'ModelAssetFile\(path: "([^"]+)", sha256: "([0-9a-f]{64})", sizeBytes: (\d+)\)',
        source,
    )
    if not pins:
        raise ValueError("No pinned model files in the generated package")
    for relative, digest, size in pins:
        path = bundled / model_path / relative
        if not path.is_file():
            problems.append(f"Missing model file: {relative}")
        elif path.stat().st_size != int(size) or sha256(path) != digest:
            problems.append(f"Model hash/size mismatch: {relative}")
    notices = [package / "LICENSE", package / "catalog.yaml", package / "package-index.yaml"]
    notices += sorted((package / "notices").glob("*"))
    for path in notices:
        destination = bundled / path.relative_to(package)
        if not destination.is_file() or sha256(destination) != sha256(path):
            problems.append(f"Missing or changed model notice/index: {path.name}")

    native_libraries = {}
    for path in files:
        with path.open("rb") as stream:
            if stream.read(4) not in MACH_O:
                continue
        linked = subprocess.check_output(["otool", "-L", str(path)], text=True)
        dependencies = linked.splitlines()[1:]
        native_libraries[str(path.relative_to(app))] = [line.strip() for line in dependencies]
        if any(RETIRED.search(line) for line in dependencies):
            problems.append(f"Retired linked library: {path.relative_to(app)}")
    if not any("mlsr" in path.lower() for path in native_libraries):
        problems.append("MLSR native library is missing")
    if not any("rust_lib_audiobookify_app5" in path for path in native_libraries):
        problems.append("EPUB Rust bridge is missing")

    with (app / "Contents/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    signature = subprocess.run(
        ["codesign", "--verify", "--deep", "--strict", str(app)],
        text=True, capture_output=True,
    )
    if signature.returncode:
        problems.append(f"Code signature: {signature.stderr.strip()}")
    signed_entitlements = subprocess.run(
        ["codesign", "-d", "--entitlements", ":-", str(app)],
        capture_output=True,
    )
    entitlements = {}
    if signed_entitlements.returncode:
        problems.append(
            "Cannot read signed entitlements: "
            + signed_entitlements.stderr.decode(errors="replace").strip()
        )
    else:
        try:
            entitlements = plistlib.loads(signed_entitlements.stdout)
        except plistlib.InvalidFileException:
            problems.append("Signed entitlements are missing or invalid")
    if not any(
        entitlements.get(key) is True
        for key in (
            "com.apple.security.files.user-selected.read-only",
            "com.apple.security.files.user-selected.read-write",
        )
    ):
        problems.append("EPUB import requires a signed user-selected file access entitlement")
    return {
        "passed": not problems,
        "app": str(app),
        "minimum_macos": info.get("LSMinimumSystemVersion"),
        "model": str(model_path),
        "verified_model_files": len(pins),
        "verified_model_bytes": sum(int(pin[2]) for pin in pins),
        "verified_notices_and_indexes": len(notices),
        "native_libraries": native_libraries,
        "entitlements": entitlements,
        "problems": problems,
        "scope": "Packaged files, pinned hashes, linkage, signature and import entitlement; runtime playback is a separate check",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("--package", type=Path, default=Path(".mlsr/model_assets"))
    args = parser.parse_args()
    try:
        report = audit(args.app.resolve(strict=True), args.package.resolve(strict=True))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        report = {"passed": False, "problems": [str(error)]}
    print(json.dumps(report, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
