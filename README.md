# AHK2 Macro Recorder

## 🎯 About

This is an AutoHotkey v2 script that enables you to record keyboard and mouse macros. 

It's based on the work of [Raeleus](https://github.com/raeleus/AHK-Macro-Recorder), who based his work on FeiYue's original AHK1 macro recorder.

## 🚀 Installation

1. Install [AutoHotkey v2](https://www.autohotkey.com/)
2. Download + Run `MacroRecorder.ahk` (it's the only file you need. all the rest is for development only)

## 🎮 Usage

### Hotkeys

- `F1` - Play recorded macro
- `F2` - Start/Stop recording macro (legacy timing)
- `Shift`+`F2` - Start/Stop recording **with delays** — replays your real timing
- `Ctrl`+`Shift`+`F2` - Start/Stop recording **with delays + simulated human mouse movement**
- `F3` - Edit macro in Notepad
- `F4` - Toggle enable/disable script
- `F6` - Play macro in a loop (F5 skipped — too commonly reserved by other apps)

> **Looking for the anti-idle feature?** The `with-f7-anti-idle-feature` branch includes an extra `F7` hotkey that auto-replays your macro after a configurable inactivity timeout. Useful as an anti-AFK tool.

## ⏱️ Recording Modes (timing & movement)

`F2` records the way it always has. The two new chords are opt-in and change nothing about the legacy path.

| Hotkey | Mode | What it does |
|---|---|---|
| `F2` | Legacy | Only delays over 200ms are kept, halved, and commented out. Unchanged behaviour. |
| `Shift`+`F2` | **Delays** | Every delay is recorded verbatim and active immediately. Key and mouse hold durations are preserved too. |
| `Ctrl`+`Shift`+`F2` | **Delays + human movement** | Everything above, plus the cursor travels between click points along a curved, eased path instead of teleporting. |

The on-screen indicator tells you which mode you're in: `LEGACY RECORDING`, `RECORDING WITH DELAYS`, or `RECORDING WITH DELAYS (SIMULATED HUMAN MOVEMENT)`.

### Playback speed

Macros recorded with either new mode start with a `SPEED` global you can edit with `F3`:

```autohotkey
SPEED := 1.0  ; 0.5 = twice as fast, 2.0 = half speed
```

Every recorded `Sleep` and the mouse travel duration scale with it, so you can retime a whole macro from one line.

### How the human movement works

Between recorded click points the cursor follows a cubic bezier with a randomised perpendicular bow, ease-in-out velocity, per-step jitter, and an overshoot-then-correct on longer throws. Duration comes from Fitts's law, so short hops are quick and long ones take proportionally longer. Movement is injected via `mouse_event` rather than `SetCursorPos`, so apps reading raw input see it.

Note this **synthesises** plausible motion — it does not replay your actual recorded path, since cursor movement between clicks still isn't sampled during recording. `Ctrl`+`Shift`+`F2` recordings use screen coordinates, as absolute paths require them.

## 🙏 Acknowledgments

- Original AHK1 Macro Recorder by FeiYue
- [Raeleus's AHK Macro Recorder](https://github.com/raeleus/AHK-Macro-Recorder) for the v2 adaptation
- Special thanks to both creators for their excellent work!

## 🔄 Differences from Raeleus's Version

- Added F4 to enable/disable the other keys (F1-F3) so you can use them for other stuff
- More stable (less errors)
- **Control Philosophy**: While Raeleus's version follows a minimalistic approach with just F1 for recording/playback, this fork adopts a more traditional control scheme (F1-F4, F6) to provide better stability and more control.

## ⚠️ Known Issues

While this version fixes some bugs from the original, some issues may still exist:
- Some recorded scripts fail to execute (when i spot it, i run some fixes. it's artifcats from the ahk1->ahk2 engine migration.
- Sometimes cries upon trying to start recording. but can start again and then it works

**Fixed:** `;MouseMode=` and `;RecordSleep=` in the macro header were previously ignored — `UpdateSettings()` read them one line off and silently fell back to defaults, so editing them had no effect. They are now matched by name and work as documented.

### Recording Modes
The script supports three mouse coordinate modes (configurable in the recorded macro file):
- `screen` - Absolute screen coordinates
- `window` - Window-relative coordinates
- `relative` - Relative to starting position

### Customization
You can customize the hotkeys by editing the following variables in the script:
```autohotkey
PLAY_KEY       := "F1"   ; Play macro
RECORD_KEY     := "F2"   ; Record macro
EDIT_KEY       := "F3"   ; Edit macro in Notepad
TOGGLE_KEY     := "F4"   ; Toggle enable/disable script
LOOP_KEY       := "F6"   ; Play macro in a loop
```

## 📝 Recording Tips

1. Pressing F1 will also force to stop the recording process
2. The recorded macro will be saved in your temp directory as `~Record1.ahk` by default. or you can F3 it and save anywhere else.

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=ArtyMcLabin/AHK2-Macro-Recorder&type=Date)](https://star-history.com/#ArtyMcLabin/AHK2-Macro-Recorder&Date)

## 🤝 Contributing

Feel free to open issues for bugs or feature requests. Pull requests are MUCH more welcome though!
