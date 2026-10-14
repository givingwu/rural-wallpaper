"""Reject inconsistent or incorrectly tagged release inputs before building."""
import json
import plistlib
import re
import sys
from pathlib import Path
from typing import Optional


SEMVER = r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"


def check_version(root: Path, tag: Optional[str] = None) -> str:
    version = (root / "version.txt").read_text().strip()
    if not re.fullmatch(SEMVER, version):
        raise ValueError("version.txt must contain a stable SemVer (for example 0.3.0)")

    manifest = json.loads((root / ".release-please-manifest.json").read_text())["."]
    with (root / "Resources/Info.plist").open("rb") as file:
        bundle = plistlib.load(file)["CFBundleShortVersionString"]
    source = (root / "Sources/RuralWallpaperCore/RuralWallpaperCore.swift").read_text()
    match = re.search(r'public static let version = "([^"]+)"', source)
    if match is None:
        raise ValueError("RuralWallpaperCore.version could not be read")
    if not version == manifest == bundle == match.group(1):
        raise ValueError(
            "Version mismatch: "
            f"version.txt={version}, manifest={manifest}, plist={bundle}, source={match.group(1)}"
        )
    if tag is not None and tag != f"v{version}":
        raise ValueError(f"Tag {tag!r} does not match v{version}")
    return version


if __name__ == "__main__":
    try:
        print(check_version(Path(__file__).resolve().parent.parent, sys.argv[1] if len(sys.argv) > 1 else None))
    except (ValueError, KeyError) as error:
        sys.exit(str(error))
