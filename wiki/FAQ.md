**English** · [Türkçe](SSS)

# FAQ

**Is RedoX Gaming free?**
Yes, free and open source under GPLv3. No ads, no accounts.

**Can I download Mario / Sonic / Zelda in the app?**
No. Commercial games are still protected by copyright, so RedoX Gaming does not offer or download them. You can play the free homebrew in the store, or your own legally obtained game files.

**The game list of a system says "HENÜZ OYUN YOK" (no games yet).**
Add a folder with **+ KLASÖR EKLE**, copy files into `roms/<system>/`, or download something from **ÜCRETSİZ OYUNLAR**. See [Adding Games](Adding-Games).

**My `.bin` / `.zip` games don't show up.**
These extensions are shared by several systems. Put them in a folder named after the system (for example `Mega Drive`, `Atari 2600`, `Arcade`). See [Adding Games](Adding-Games#how-systems-are-recognised).

**No box art for my game.**
Box art is matched by file name. Rename the file to its No-Intro name, for example `Sonic The Hedgehog (USA, Europe).md`.

**"Çekirdek indirilemedi" (core could not be downloaded).**
The first start of every system needs internet once. Check your connection and try again. Firewalls must allow `buildbot.libretro.com`.

**Windows says the app is from an unknown publisher.**
The app is not code-signed. Choose *More info → Run anyway*. You can check the source code and build it yourself.

**Where are my saves?**
`saves/` (battery saves) and `states/` (save states) inside the [data folder](Installation#where-your-data-is).

**Does my controller work?**
Any controller Windows/Android sees as a gamepad (Xbox, PlayStation, 8BitDo, generic USB) works. Buttons map by position, SNES style.

**The sound crackles.**
Close heavy programs and use a wired controller/display. A latency setting is on the roadmap.

**Where is the Android / Android TV version?**
It is planned for the next release.
