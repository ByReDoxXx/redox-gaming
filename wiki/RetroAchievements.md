**English** · [Türkçe](RetroAchievements-TR)

# RetroAchievements

[RetroAchievements](https://retroachievements.org) is a free community service that adds achievements (trophies) to classic games. RedoX Gaming has it built in through the official [rcheevos](https://github.com/RetroAchievements/rcheevos) library.

## Sign in

1. Create a free account at [retroachievements.org](https://retroachievements.org) (on a computer or phone browser).
2. In RedoX Gaming: **Settings → RetroAchievements → SIGN IN**, type your username and password.
3. The app keeps only the **login token** RetroAchievements returns; your password is not stored.

To sign out: **Settings → RetroAchievements → SIGN OUT**.

## Playing

- Start a supported game. When RetroAchievements knows the game, a banner shows how many achievements you have unlocked.
- When you unlock one, a gold banner slides in with its badge, title and points.
- Pause → **ACHIEVEMENTS** lists every achievement of the game: unlocked ones in gold, locked ones with their progress.

RetroAchievements recognises games by the exact file (a hash), so the ROM must match a version in their database. Many homebrew games are supported too.

## Hardcore mode

**Settings → RetroAchievements → Hardcore mode.** In hardcore, unlocks count as "hardcore" on the site and the app turns off:

- rewind,
- loading save states (saving still works),
- cheats.

Normal (softcore) mode allows everything; loading a save state then restarts the achievement checks.

## Supported systems

NES, SNES, Game Boy, Game Boy Color, Game Boy Advance, Mega Drive, Master System, Game Gear, PC Engine, Atari 2600, Neo Geo Pocket, PlayStation and Arcade (FBNeo) are sent to RetroAchievements with their console ids.

## Troubleshooting

| Problem | What to do |
|---|---|
| "Sign-in failed" | check the username and password on the website; the account must be confirmed by e-mail |
| No banner when a game starts | the game (this exact file) has no achievements, or you are not signed in |
| Unlocks while offline | rcheevos retries them when the connection comes back |
