"""Installs Godot's Android Gradle build template into app/android/ and adds
the Android TV launcher banner. Needed once before exporting the APK (the
"Android" preset uses a Gradle build so the app shows up on Android TV).

    python tools/setup_android_build.py [path/to/android_source.zip]

Without an argument the zip is taken from the installed export templates:
  Windows  %APPDATA%/Godot/export_templates/<version>/android_source.zip
  Linux    ~/.local/share/godot/export_templates/<version>/android_source.zip
"""
import os
import shutil
import sys
import zipfile
from pathlib import Path

VERSION = "4.7.2.stable"
ROOT = Path(__file__).resolve().parent.parent
ANDROID = ROOT / "app" / "android"
BANNER = ROOT / "app" / "assets" / "brand" / "android" / "tv_banner_320x180.png"


def template_zip() -> Path:
    if len(sys.argv) > 1:
        return Path(sys.argv[1])
    if os.name == "nt":
        base = Path(os.environ["APPDATA"]) / "Godot"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "godot"
    return base / "export_templates" / VERSION / "android_source.zip"


def main() -> None:
    src = template_zip()
    if not src.exists():
        sys.exit(f"android_source.zip not found: {src}")
    build = ANDROID / "build"
    build.mkdir(parents=True, exist_ok=True)   # extracted over any older copy
    with zipfile.ZipFile(src) as z:
        z.extractall(build)
    (ANDROID / ".build_version").write_text(VERSION, encoding="utf-8")
    (build / ".gdignore").write_text("", encoding="utf-8")
    gradlew = build / "gradlew"
    if gradlew.exists():
        gradlew.chmod(0o755)

    # Android TV launcher banner
    drawable = build / "res" / "drawable"
    drawable.mkdir(parents=True, exist_ok=True)
    shutil.copy(BANNER, drawable / "tv_banner.png")
    manifest = build / "src" / "main" / "AndroidManifest.xml"
    text = manifest.read_text(encoding="utf-8")
    if "android:banner" not in text:
        text = text.replace('android:icon="@mipmap/icon"',
                            'android:icon="@mipmap/icon"\n        android:banner="@drawable/tv_banner"', 1)
        manifest.write_text(text, encoding="utf-8", newline="\n")
    # No Gradle daemon: a daemon left running keeps Godot's headless export
    # from exiting after the APK is written (CI would wait until its timeout).
    props = build / "gradle.properties"
    text = props.read_text(encoding="utf-8")
    if "org.gradle.daemon" not in text:
        props.write_text(text.rstrip("\n") + "\n\norg.gradle.daemon=false\n",
                         encoding="utf-8", newline="\n")
    print("Android build template ready in", build)


if __name__ == "__main__":
    main()
