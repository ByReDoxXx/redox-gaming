**English** · [Türkçe](Katki)

# Contributing

Thank you for helping! RedoX Gaming is GPLv3; contributions are accepted under the same license.

## Reporting a bug

Open an [issue](https://github.com/ByReoxXx/redox-gaming/issues) with:

- your OS and the RedoX Gaming version,
- the system and the game (a homebrew name, never a ROM file or a download link),
- what you did, what you expected, what happened,
- the log file: `logs/godot.log` inside the [data folder](Installation#where-your-data-is).

## Pull requests

1. Fork, create a branch, keep changes focused.
2. Follow the [design system](https://github.com/ByReoxXx/redox-gaming/blob/main/docs/DESIGN.md): colours and sizes come from `app.gd`, every new screen must work with D-pad + A/B.
3. Run both tests (`smoke_test` and `services_test`); they must print `RESULT: PASS`.
4. Describe what changed and how you tested it.

## Rules

- No commercial ROMs, BIOS files or links to them, anywhere: code, issues, screenshots.
- New free game sources must allow redistribution.
- Cores stay downloaded at runtime, not committed.

## Adding a system

See [Technical documentation → Extending](https://github.com/ByReoxXx/redox-gaming/blob/main/docs/TECHNICAL.md#9-extending): one entry in `App.SYSTEMS`, folder hints, box-art folder, an illustration, optional free-game source.
