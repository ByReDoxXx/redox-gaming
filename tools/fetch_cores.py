"""Downloads prebuilt libretro cores from the official libretro buildbot
into app/cores/<platform>/.

Usage:  python tools/fetch_cores.py [windows|linux|android]   (default: windows)
"""

import io
import sys
import urllib.request
import zipfile
from pathlib import Path

CORES = ["fceumm"]  # NES. Add snes9x / bsnes etc. here later.

BUILDBOT = {
    "windows": ("https://buildbot.libretro.com/nightly/windows/x86_64/latest/{}_libretro.dll.zip", "{}_libretro.dll"),
    "linux": ("https://buildbot.libretro.com/nightly/linux/x86_64/latest/{}_libretro.so.zip", "{}_libretro.so"),
    "android": ("https://buildbot.libretro.com/nightly/android/latest/arm64-v8a/{}_libretro_android.so.zip", "{}_libretro_android.so"),
}


def main() -> None:
    platform = sys.argv[1] if len(sys.argv) > 1 else "windows"
    url_fmt, file_fmt = BUILDBOT[platform]
    out_dir = Path(__file__).resolve().parent.parent / "app" / "cores" / platform
    out_dir.mkdir(parents=True, exist_ok=True)

    for core in CORES:
        url = url_fmt.format(core)
        name = file_fmt.format(core)
        print(f"downloading {url}")
        with urllib.request.urlopen(url) as resp:
            data = resp.read()
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            (out_dir / name).write_bytes(z.read(name))
        print(f"  -> {out_dir / name}")


if __name__ == "__main__":
    main()
