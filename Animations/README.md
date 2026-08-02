# Animations Summons

The game supports custom summon-animation videos. Video files are loaded when the corresponding summon starts.

## Animations (no subfolder)

Place the files directly in this `Animations` folder. They are played when a certain action is performed in a duel, and you can disable them with **Enable summon animations** in the game settings.

The audio may be easier to hear if you turn down or disable the game music.

Supported file types are `.gif`, `.mp4`, `.webm`, and `.mkv`. You may replace the files with custom videos as long as the base name remains the same. If more than one supported extension exists for the same summon, the priority is `.gif`, then `.mp4`, then `.webm`, then `.mkv`.

- `synchro.gif`: played when a Synchro Summon starts.
- `xyz.gif`: played when an Xyz Summon starts.
- `pendulum.gif`: played when a Pendulum Summon starts.
- `link.gif`: played when a Link Summon starts.
- `ritual.gif`: played when a Ritual Summon starts.
- `fusion.gif`: played when a Fusion Summon starts.

The same names work with the other supported extensions, for example `synchro.mp4`, `xyz.webm`, or `fusion.mkv`.

## Windows and Linux runtime

Animation decoding uses FFmpeg. The packaged Windows build includes `ffmpeg.exe` and `ffplay.exe` next to the game executable. On Linux, install `ffmpeg` and `ffplay` so they are available in `PATH`, or place compatible binaries next to the game executable.

`ffmpeg` provides the embedded video; `ffplay` provides the video's audio. If `ffplay` is unavailable, the animation still plays without its own audio.
