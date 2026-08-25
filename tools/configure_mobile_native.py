from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_ID = "com.bidbook.app"


def patch_android() -> None:
    app_dir = ROOT / "android" / "app"
    if not app_dir.exists():
        return
    for gradle_name in ("build.gradle.kts", "build.gradle"):
        path = app_dir / gradle_name
        if not path.exists():
            continue
        text = path.read_text()
        text = re.sub(r'namespace\s*=\s*["\'][^"\']+["\']', f'namespace = "{APP_ID}"', text)
        text = re.sub(r'applicationId\s*=\s*["\'][^"\']+["\']', f'applicationId = "{APP_ID}"', text)
        path.write_text(text)

    manifest = app_dir / "src" / "main" / "AndroidManifest.xml"
    if manifest.exists():
        text = manifest.read_text()
        permissions = [
            '<uses-permission android:name="android.permission.INTERNET" />',
            '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />',
            '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
            '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
        ]
        insert = "\n    ".join(permission for permission in permissions if permission not in text)
        if insert:
            text = text.replace("<manifest", "<manifest", 1)
            marker = ">"
            index = text.find(marker)
            text = text[: index + 1] + "\n    " + insert + text[index + 1 :]
        manifest.write_text(text)

    kotlin_root = app_dir / "src" / "main" / "kotlin"
    if kotlin_root.exists():
        candidates = list(kotlin_root.rglob("MainActivity.kt"))
        if candidates:
            source = candidates[0]
            target = kotlin_root / "com" / "bidbook" / "app" / "MainActivity.kt"
            target.parent.mkdir(parents=True, exist_ok=True)
            text = source.read_text()
            text = re.sub(r"^package\s+[^\n]+", f"package {APP_ID}", text, flags=re.MULTILINE)
            target.write_text(text)
            if source != target:
                source.unlink()
                _remove_empty_parents(source.parent, kotlin_root)


def _remove_empty_parents(path: Path, stop: Path) -> None:
    while path != stop and path.exists():
        try:
            path.rmdir()
        except OSError:
            break
        path = path.parent


def patch_ios() -> None:
    plist = ROOT / "ios" / "Runner" / "Info.plist"
    if plist.exists():
        text = plist.read_text()
        additions = {
            "NSLocationWhenInUseUsageDescription": "Bid&Book uses your location only when you ask to find nearby providers or set a provider service area.",
            "NSPhotoLibraryUsageDescription": "Bid&Book lets you choose job, service and dispute photos to upload.",
            "NSCameraUsageDescription": "Bid&Book lets you take job and service photos when you choose to.",
        }
        for key, value in additions.items():
            if f"<key>{key}</key>" not in text:
                text = text.replace(
                    "</dict>",
                    f"\t<key>{key}</key>\n\t<string>{value}</string>\n</dict>",
                    1,
                )
        plist.write_text(text)

    project = ROOT / "ios" / "Runner.xcodeproj" / "project.pbxproj"
    if project.exists():
        text = project.read_text()
        text = re.sub(
            r"PRODUCT_BUNDLE_IDENTIFIER = [^;]+;",
            lambda match: (
                f"PRODUCT_BUNDLE_IDENTIFIER = {APP_ID}.RunnerTests;"
                if "RunnerTests" in match.group(0)
                else f"PRODUCT_BUNDLE_IDENTIFIER = {APP_ID};"
            ),
            text,
        )
        project.write_text(text)


def main() -> None:
    del shutil  # keeps this script standard-library only and explicit about no external tooling
    patch_android()
    patch_ios()
    print(f"Configured native mobile wrappers for {APP_ID}")


if __name__ == "__main__":
    main()
