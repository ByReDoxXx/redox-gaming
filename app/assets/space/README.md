# Space sprites for the home screen background

`app/scripts/ui/space_backdrop.gd` uses the PNG files in this folder for short
scenes on the home screen (chases, shoot-outs, crashes). The file name decides
the role of a sprite:

| Name starts with | Movement |
|---|---|
| `asteroid` | slow drift, slowly turning |
| `ufo` | medium speed, bobbing up and down |
| `ship` | fast, straight line |

- Transparent PNG, square-ish, about 256 px. Pixel art, dark navy outline.
- Ships and UFOs face **right**; they are mirrored when flying left.
- Any number per kind: `ship_1.png`, `ship_2.png`, ...
- Art: Gemini Nano Banana on a plain white background. Put the JPG in
  `art/gemini/space/` and run `python tools/cutout_space.py`.

Without files here only the stars move.
