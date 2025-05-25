# AHK2 Macro Recorder

A fork of [Raeleus's AHK Macro Recorder](https://github.com/raeleus/AHK-Macro-Recorder) with bug fixes, and different controls. (multiple F keys, for different functions)

## 🎯 About

This is an AutoHotkey v2 script that enables you to record keyboard and mouse macros. It's based on the work of [Raeleus](https://github.com/raeleus/AHK-Macro-Recorder), who based his work on FeiYue's original AHK1 macro recorder.

## 🙏 Acknowledgments

- Original AHK1 Macro Recorder by FeiYue
- [Raeleus's AHK Macro Recorder](https://github.com/raeleus/AHK-Macro-Recorder) for the v2 adaptation
- Special thanks to both creators for their excellent work!

## 🔄 Differences from Raeleus's Version

- Added script enable/disable toggle (F4)
- Bug Fixes
- Added more robust error handling
- **Control Philosophy**: While Raeleus's version follows a minimalistic approach with just F1 for recording/playback, this fork adopts a more traditional control scheme (F1-F4) to provide better stability and slightly more control.

## ⚠️ Known Issues

While this version fixes some bugs from the original, some issues may still exist:
- Some recorded scripts fail to execute (when i spot it, i run some fixes. it's artifcats from the ahk1->ahk2 engine migration.

## 🚀 Installation

1. Install [AutoHotkey v2](https://www.autohotkey.com/)
2. Download the latest release from this repository
3. Run `MacroRecorder.ahk`

## 🎮 Usage

### Hotkeys
- `F1` - Play recorded macro
- `F2` - Start/Stop recording macro
- `F3` - Edit macro in Notepad
- `F4` - Toggle enable/disable script

### Recording Modes
The script supports three mouse coordinate modes (configurable in the recorded macro file):
- `screen` - Absolute screen coordinates
- `window` - Window-relative coordinates
- `relative` - Relative to starting position

### Customization
You can customize the hotkeys by editing the following variables in the script:
```autohotkey
PLAY_KEY   := "F1"   ; Play macro
RECORD_KEY := "F2"   ; Record macro
EDIT_KEY   := "F3"   ; Edit macro in Notepad
TOGGLE_KEY := "F4"   ; Toggle enable/disable script
```

## 📝 Recording Tips

1. Start recording with F2
2. Perform your actions
3. Press F2 again to stop recording
4. Press F1 to play the macro
5. Use F3 to edit the macro if needed

The recorded macro will be saved in your temp directory as `~Record1.ahk` by default.

## 🤝 Contributing

Feel free to open issues for bugs or feature requests. Pull requests are MUCH more welcome though!
