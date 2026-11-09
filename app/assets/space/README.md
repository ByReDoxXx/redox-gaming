# Space sprites for the home screen background

`app/scripts/ui/space_backdrop.gd` flies the PNG files in this folder across
the home screen now and then. The file name decides how a sprite moves:

| Name starts with | Movement |
|---|---|
| `asteroid` | slow drift, slowly turning |
| `ufo` | medium speed, bobbing up and down |
| `ship` | fast, straight line |

- Transparent PNG, square-ish, about 256 px. Pixel art, dark navy outline.
- Ships and UFOs face **right**; they are mirrored when flying left.
- Any number per kind: `ship_1.png`, `ship_2.png`, ...
- Art: Gemini Nano Banana, cut out with `tools/cutout_icons.py`
  (put the JPG in `art/gemini/`, then copy the PNG from `systems_hd/` here).

Without files here only the stars move.
