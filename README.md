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
- `F2` - Start/Stop recording macro
- `F3` - Edit macro in Notepad
- `F4` - Toggle enable/disable script
- 

## 🙏 Acknowledgments

- Original AHK1 Macro Recorder by FeiYue
- [Raeleus's AHK Macro Recorder](https://github.com/raeleus/AHK-Macro-Recorder) for the v2 adaptation
- Special thanks to both creators for their excellent work!

## 🔄 Differences from Raeleus's Version

- Added F4 to enable/disable the other keys (F1-F3) so you can use them for other stuff
- More stable (less errors)
- **Control Philosophy**: While Raeleus's version follows a minimalistic approach with just F1 for recording/playback, this fork adopts a more traditional control scheme (F1-F4) to provide better stability and slightly more control.

## ⚠️ Known Issues

While this version fixes some bugs from the original, some issues may still exist:
- Some recorded scripts fail to execute (when i spot it, i run some fixes. it's artifcats from the ahk1->ahk2 engine migration.
- Sometimes cries upon trying to start recording. but can start again and then it works

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

1. Pressing F1 will also force to stop the recording process
5. The recorded macro will be saved in your temp directory as `~Record1.ahk` by default. or you can F3 it and save anywhere else.

## 🤝 Contributing

Feel free to open issues for bugs or feature requests. Pull requests are MUCH more welcome though!
