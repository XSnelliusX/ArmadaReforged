# Notice

Copyright (c) 2026 XSnelliusX. The Armada Reforged app and the files in this repository are released under the
[MIT licence](LICENSE), without any warranty.

## Legal notice

- Armada Reforged is an unofficial fan project. It is not affiliated with, authorised, or endorsed by Activision, Paramount / CBS
  Studios or GOG.
- Star Trek and Star Trek: Armada are trademarks of their respective owners. The names are used only to say what the project is
  compatible with.
- This repository and its releases contain no game data: no models, textures, sounds, videos, maps or mission files of the
  original game. You need an original, legally obtained copy of Star Trek: Armada to play. The project does not support piracy.
  The game can be bought at GOG: https://www.gog.com/en/game/star_trek_armada
- The screenshots and the gameplay clip on this page were captured from Armada Reforged running a legally owned copy of the game.

## Optional asset packs

The optional asset packs (upscaled textures, remodelled ships and stations, HD fonts) are fan-made upscales and remodels derived
from the original game's artwork. They are provided only for use with a legally owned copy of the game, and the rights of the
original artwork's owners remain reserved. The packs are not covered by the MIT licence.

## Third-party software in the app

| Component | Licence | Use |
|---|---|---|
| [SDL3](https://www.libsdl.org) 3.4.18 | zlib licence | window, input, audio and graphics (Metal) |
| [FFmpeg](https://ffmpeg.org) 9.0.2 (libavcodec, libavformat, libavutil, libswscale, libswresample) | LGPL-2.1-or-later; built without GPL or nonfree components, linked dynamically, unmodified source: https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz | plays the game's videos |
| zlib (part of macOS) | zlib licence | reads the compressed asset packs |
| [stb_truetype](https://github.com/nothings/stb) 1.26 | public domain or MIT | draws the menu fonts |
| [Oxanium](https://fonts.google.com/specimen/Oxanium) typeface | SIL Open Font License 1.1 | the HD font sheets of the optional upscaled look |

The shared libraries inside `Armada Reforged.app/Contents/Frameworks` keep their own licences and may be replaced by compatible
builds.
