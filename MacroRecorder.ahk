#Requires AutoHotkey v2.0+
;#NoTrayIcon
#SingleInstance Off
Thread("NoTimers")
CoordMode("ToolTip")
SetTitleMatchMode(2)
DetectHiddenWindows(true)
;-----------------------------------
;  Macro Recorder v3.8 by Arty McLabin
;  Based on v2 by Raeleus (https://github.com/raeleus/AHK-Macro-Recorder). Raeleus based his on v2.1 of FeiYue
;
;  F1              = Play macro
;  F2              = Record macro           (legacy: only delays >200ms, halved, commented out)
;  Shift + F2      = Record macro (TIMED)   (every delay recorded verbatim, active immediately)
;  Ctrl+Shift+F2   = Record macro (HUMAN)   (TIMED + natural bezier mouse travel on playback)
;  F3              = Edit macro in Notepad
;  F4              = Toggle enable/disable script
;  F6              = Play macro in a loop
;
;  Press the same chord again (or F2) to stop recording.
;
;  TIMED / HUMAN recordings emit a `SPEED := 1.0` global at the top of the macro.
;  Edit it (F3) to scale the whole playback: 0.5 = twice as fast, 2.0 = half speed.
;  HUMAN recordings force screen coordinates (mouse paths are absolute by nature).
;-----------------------------------

DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")  ; Fix mouse coords on scaled monitors (>100%)

PLAY_KEY         := "F1"     ; Play macro
RECORD_KEY       := "F2"     ; Record macro (legacy behaviour)
RECORD_TIMED_KEY := "+F2"    ; Record macro, respecting real delays
RECORD_HUMAN_KEY := "^+F2"   ; Record macro, real delays + human mouse movement
EDIT_KEY         := "F3"     ; Edit macro in Notepad
TOGGLE_KEY       := "F4"     ; Toggle enable/disable script
scriptEnabled    := true     ; Start enabled by default
LOOP_KEY         := "F6"     ; Play macro indefinitely (F5 is too commonly reserved by other apps)
LOOP_DELAY       := 1000     ; Delay in milliseconds between loops
loopPID          := 0        ; Track loop child process

MIN_SLEEP        := 8        ; ms; below A_TickCount resolution, not worth emitting
RecordMode       := "legacy" ; legacy | timed | human

if (A_Args.Length < 1) {
  A_Args.Push("~Record1.ahk")
}

if (A_Args.Length < 2) {
  A_Args.Push("F1")
}

LogFile := A_Temp "\" A_Args[1]
UpdateSettings
Recording := false
Playing := false
ActionKey := A_Args[2]

Hotkey(PLAY_KEY,         (*) => PlayKeyAction())
Hotkey(RECORD_KEY,       (*) => RecordKeyAction("legacy"))
Hotkey(RECORD_TIMED_KEY, (*) => RecordKeyAction("timed"))
Hotkey(RECORD_HUMAN_KEY, (*) => RecordKeyAction("human"))
Hotkey(EDIT_KEY,         (*) => EditKeyAction())
Hotkey(LOOP_KEY,         (*) => LoopKeyAction())
Hotkey(TOGGLE_KEY,       (*) => ToggleScript())

ReleaseModifiers() {
  ; Release any physically held modifier keys to prevent them from
  ; bleeding into macro playback (fixes issue with +F1, ^F1, !F1 hotkeys)
  Send("{Shift up}{Ctrl up}{Alt up}{LWin up}{RWin up}")
}

StopLoop() {
  global loopPID
  if (!loopPID)
    return false
  try ProcessClose(loopPID)
  loopPID := 0
  ShowTip("LOOP Stopped", "y35", "Red|FF4444")
  SetTimer(() => ShowTip(), -2000)
  return true
}

ShowTip(s := "", pos := "y35", color := "Red|00FFFF") {
  static bak := "", idx := 0, ShowTip := Gui(), RecordingControl
  if (bak = color "," pos "," s)
    return
  bak := color "," pos "," s
  SetTimer(ShowTip_ChangeColor, 0)
  ShowTip.Destroy()
  if (s = "")
    return

  ShowTip := Gui("+LastFound +AlwaysOnTop +ToolWindow -Caption +E0x08000020", "ShowTip")
  WinSetTransColor("FFFFF0 150")
  ShowTip.BackColor := "cFFFFF0"
  ShowTip.MarginX := 10
  ShowTip.MarginY := 5
  ShowTip.SetFont("q3 s20 bold cRed")
  RecordingControl := ShowTip.Add("Text", , s)
  ShowTip.Show("NA " . pos)
  SetTimer(ShowTip_ChangeColor, 1000)

  ShowTip_ChangeColor() {
    r := StrSplit(SubStr(bak, 1, InStr(bak, ",") - 1), "|")
    RecordingControl.SetFont("q3 c" r[idx := Mod(Round(idx), r.Length) + 1])
    return
  }
}

; Script starts silently — label only shown on user toggle (F4)

;============ Hotkey =============

RecordKeyAction(mode := "legacy") {
  global RecordMode
  if (Recording) {
    Stop()
    return
  }
  StopLoop()
  #SuspendExempt
  RecordMode := mode
  RecordScreen()
}

RecordScreen() {
  global LogArr := []
  global oldid := ""
  global Recording := false
  global RelativeX, RelativeY, RecordMode, MouseMode

  if (Recording || Playing)
    return
  UpdateSettings()

  ; HUMAN playback drives the cursor in absolute screen space.
  if (RecordMode == "human")
    MouseMode := "screen"

  ; Paint the indicator BEFORE SetHotkey(1) registers its 254 hotkeys, so it
  ; appears immediately rather than after the registration loop finishes.
  ShowTip(RecordMode == "human" ? "RECORDING WITH DELAYS (SIMULATED HUMAN MOVEMENT)"
        : RecordMode == "timed" ? "RECORDING WITH DELAYS"
        : "LEGACY RECORDING")

  ; Let go of the trigger chord before we start listening, so the release of
  ; Shift/Ctrl from +F2 / ^+F2 can never leak into the recording.
  if (RecordMode != "legacy") {
    KeyWait("Shift")
    KeyWait("Ctrl")
  }

  LogArr := []
  oldid := ""
  Log()
  Recording := true
  SetHotkey(1)
  CoordMode("Mouse", "Screen")
  MouseGetPos(&RelativeX, &RelativeY)
  return
}

UpdateSettings() {
  global MouseMode, RecordSleep, RecordMode, LogFile
  MouseMode := "screen"
  RecordSleep := "false"

  ; Parse the settings header by name, not by line position. The v3.7 parser
  ; did `Loop 3 { ReadLine() }` then read line 4 as MouseMode and line 6 as
  ; RecordSleep — an off-by-one that consumed the ";MouseMode=" line itself and
  ; left both settings permanently pinned to their defaults.
  if (FileExist(LogFile)) {
    LogFileObject := FileOpen(LogFile, "r")
    Loop 16 {
      if (LogFileObject.AtEOF)
        break
      line := LogFileObject.ReadLine()
      if (RegExMatch(line, "i)^\s*;\s*MouseMode\s*=\s*(\S*)", &m))
        MouseMode := m[1]
      else if (RegExMatch(line, "i)^\s*;\s*RecordSleep\s*=\s*(\S*)", &m))
        RecordSleep := m[1]
    }
    LogFileObject.Close()
  }

  if (MouseMode != "screen" && MouseMode != "window" && MouseMode != "relative")
    MouseMode := "screen"

  if (RecordSleep != "true" && RecordSleep != "false")
    RecordSleep := "false"

  ; TIMED and HUMAN always emit live Sleep() calls — the setting is never
  ; consulted, so the behaviour is active the moment you press the hotkey.
  if (RecordMode != "legacy")
    RecordSleep := "true"
}

Stop() {
  global LogArr, Recording, isPaused, RecordMode, MouseMode, RecordSleep, LogFile
  global ActionKey, LOOP_KEY, LOOP_DELAY
  #SuspendExempt
  if (Recording) {
    if (LogArr.Length > 0) {
      UpdateSettings()

      ; UpdateSettings() re-reads the previous macro file, which can flip
      ; MouseMode back to "window" after LogKey_Mouse already emitted the
      ; screen-coordinate lines uncommented. Re-assert the HUMAN override so
      ; the CoordMode written into the preamble matches the recorded lines.
      if (RecordMode == "human")
        MouseMode := "screen"

      TrimTrailingModifiers()

      ; Consolidate key combinations. Only meaningful in legacy mode;
      ; TIMED/HUMAN interleave Sleep() lines between the down/key/up triplet,
      ; which is precisely the timing we are trying to keep.
      if (RecordMode == "legacy")
        ProcessKeySequences()

      s := ""
      if (RecordMode != "legacy")
        s .= BuildPreamble()

      s .= ";#####SETTINGS#####`n;What is the preferred method of recording mouse coordinates (screen,window,relative)`n;MouseMode=" MouseMode "`n;Record sleep between input actions (true,false)`n;RecordSleep=" RecordSleep "`n;RecordMode=" RecordMode "`n"

      s .= "try {`n"
      s .= "isLoop := (A_Args.Has(1) && A_Args[1] == `"loop`")`n"
      s .= "while (isLoop || A_Index == 1)`n{`n`n"

      s .= "StartingValue := 0`ni := RegRead(`"HKEY_CURRENT_USER\SOFTWARE\`" A_ScriptName, `"i`", StartingValue)`nRegWrite(i + 1, `"REG_DWORD`", `"HKEY_CURRENT_USER\SOFTWARE\`" A_ScriptName, `"i`")`n`n"

      if (RecordMode == "legacy") {
        s .= "SetKeyDelay(30)`nSendMode(`"Event`")`nSetTitleMatchMode(2)"
      } else {
        ; Timing comes exclusively from the recorded Sleep() calls, so strip the
        ; implicit 30ms per-key delay instead of stacking it on top of them.
        ; 25ms press duration keeps the keystrokes physically plausible.
        s .= "SendMode(`"Event`")`nSetKeyDelay(0, 25)`nSetMouseDelay(-1)`nSetDefaultMouseSpeed(2)`nSetTitleMatchMode(2)"
      }

      if (MouseMode == "window") {
        s .= "`n;CoordMode(`"Mouse`", `"Screen`")`nCoordMode(`"Mouse`", `"Window`")`n"
      } else {
        s .= "`nCoordMode(`"Mouse`", `"Screen`")`n;CoordMode(`"Mouse`", `"Window`")`n"
      }

      For k, v in LogArr
        s .= "    " v "`n"

      s .= "    if (isLoop)`n"
      s .= "        Sleep(" LOOP_DELAY ")`n"

      s .= "}`n"
      s .= "} finally {`n"
      s .= "  BlockInput(false)`n"
      s .= "}`n"
      s .= "ExitApp()`n`n" ActionKey "::ExitApp()`n" LOOP_KEY "::ExitApp()`n"

      if (RecordMode == "human")
        s .= "`n" BuildHumanHelpers()

      s := RegExReplace(s, "\R", "`n")
      if (FileExist(LogFile))
        FileDelete(LogFile)
      FileAppend(s, LogFile, "UTF-16")
      s := ""
    }
    ; Unregister the logging hotkeys before releasing LogArr, and leave it an
    ; empty Array rather than a String so any thread still unwinding out of a
    ; KeyWait cannot trip over a missing .Length.
    Recording := 0
    SetHotkey(0)
    LogArr := []
  }

  ShowTip()
  Suspend(false)
  Pause(false)
  isPaused := false
  return
}

; Emitted above the settings header so SPEED is in scope for every Sleep() below.
BuildPreamble() {
  return "SPEED := 1.0  `; playback rate: 0.5 = 2x faster, 2.0 = half speed`n"
       . "DllCall(`"SetThreadDpiAwarenessContext`", `"ptr`", -3, `"ptr`")`n"
}

LoopKeyAction() {
  global loopPID, LogFile
  #SuspendExempt

  ; If loop is running, stop it
  if (StopLoop())
    return

  if (Recording || Playing)
    Stop()
  ahk := A_AhkPath
  if (!FileExist(ahk))
  {
    MsgBox("Can't Find " ahk " !", "Error", 4096)
    Exit()
  }

  EnsureEmptyMacroFile()

  ReleaseModifiers()
  if (A_IsCompiled) {
    Run(ahk " /script /restart `"" LogFile "`" loop", , , &pid)
  } else {
    Run(ahk " /restart `"" LogFile "`" loop", , , &pid)
  }
  loopPID := pid
  ShowTip("LOOP Started", "y35", "Green|00FF00")
  SetTimer(() => ShowTip(), -2000)
  return
}

; Stopping with +F2 / ^+F2 logs the chord's own modifier Down before Stop()
; runs, and the matching Up never arrives (Log() refuses it once Recording is
; off). Left in place, playback would press Shift/Ctrl and never release it.
; Drop unmatched trailing modifier presses, plus the Sleep emitted just ahead
; of each one so no phantom pause is left dangling at the end of the macro.
TrimTrailingModifiers() {
  global LogArr
  if !(LogArr is Array)
    return
  while (LogArr.Length > 0) {
    if !RegExMatch(LogArr[LogArr.Length], 'i)^Send\("\{(Ctrl|Shift|Alt|LWin|RWin) Down\}"\)$')
      break
    LogArr.Pop()
    if (LogArr.Length > 0 && RegExMatch(LogArr[LogArr.Length], 'i)^;?Sleep\('))
      LogArr.Pop()
  }
}

; Helper function to process key sequences and consolidate key combinations
ProcessKeySequences() {
  global LogArr
  newLogArr := []

  i := 1
  while (i <= LogArr.Length) {
    currentLine := LogArr[i]

    ; Look for patterns like "Send("{Alt Down}")" followed by "Send("{Something}")" and then "Send("{Alt Up}")"
    if (i + 2 <= LogArr.Length) {
      modDown := RegExMatch(currentLine, 'Send\("{([^}]+) Down}"\)')
      if (modDown) {
        modifier := RegExReplace(currentLine, 'Send\("{([^}]+) Down}"\)', "$1")
        nextLine := LogArr[i + 1]
        upLine := LogArr[i + 2]

        ; Check if this is a modifier + key + modifier up pattern
        if (RegExMatch(upLine, 'Send\("{' modifier ' Up}"\)')) {
          ; This is a modifier key combination
          if (RegExMatch(nextLine, 'Send\("{Blind}([^}]*)"\)')) {
            key := RegExReplace(nextLine, 'Send\("{Blind}([^}]*)"\)', "$1")
            ; Create a proper key combination
            newLogArr.Push("Send(`"{" modifier " down}" key "{" modifier " up}`")")
            i += 3  ; Skip the next two lines as we've processed them
            continue
          }
        }
      }
    }

    ; Add the current line if it wasn't part of a key combination
    newLogArr.Push(currentLine)
    i++
  }

  ; Replace the original LogArr with our processed version
  LogArr := newLogArr
}

PlayKeyAction() {
  global LogFile
  #SuspendExempt
  StopLoop()
  if (Recording || Playing)
    Stop()
  ahk := A_AhkPath
  if (!FileExist(ahk))
  {
    MsgBox("Can't Find " ahk " !", "Error", 4096)
    Exit()
  }

  EnsureEmptyMacroFile()

  ReleaseModifiers()
  if (A_IsCompiled) {
    Run(ahk " /script /restart `"" LogFile "`"")
  } else {
    Run(ahk " /restart `"" LogFile "`"")
  }
  return
}

EditKeyAction() {
  global LogFile
  #SuspendExempt
  StopLoop()
  EnsureEmptyMacroFile()
  Run("notepad.exe `"" LogFile "`"")
  return
}

ToggleScript() {
    global scriptEnabled, PLAY_KEY, RECORD_KEY, EDIT_KEY, LOOP_KEY
    global RECORD_TIMED_KEY, RECORD_HUMAN_KEY
    scriptEnabled := !scriptEnabled
    state := scriptEnabled ? "On" : "Off"
    for k in [PLAY_KEY, RECORD_KEY, RECORD_TIMED_KEY, RECORD_HUMAN_KEY, EDIT_KEY, LOOP_KEY]
        Hotkey(k, state)
    if scriptEnabled {
        ShowTip("Macro Recorder ENABLED", "y35", "Green|00FF00")
        SetTimer(() => ShowTip(), -500)
    } else {
        ShowTip("Macro Recorder DISABLED", "y35", "Gray|888888")
        SetTimer(() => ShowTip(), -500)
    }
}

;============ Functions =============

EnsureEmptyMacroFile() {
  ; Create an empty macro file at LogFile if it doesn't exist yet.
  ; SSoT for the empty-macro template (was duplicated 3x; AHK2 escape `n, not literal \n).
  global LogFile
  if (!FileExist(LogFile)) {
    FileAppend("; Empty macro file created by script`nExitApp()`n", LogFile, "UTF-16")
  }
}

SetHotkey(f := false) {
  f := f ? "On" : "Off"
  Loop 254
  {
    k := GetKeyName(vk := Format("vk{:X}", A_Index))
    if (!(k ~= "^(?i:|Control|Alt|Shift)$"))
      Hotkey("~*" vk, LogKey, f)
  }
  For i, k in StrSplit("NumpadEnter|Home|End|PgUp" . "|PgDn|Left|Right|Up|Down|Delete|Insert", "|")
  {
    sc := Format("sc{:03X}", GetKeySC(k))
    if (!(k ~= "^(?i:|Control|Alt|Shift)$"))
      Hotkey("~*" sc, LogKey, f)
  }

  if (f = "On") {
    SetTimer(LogWindow)
    LogWindow()
  } else
    SetTimer(LogWindow, 0)
}

LogKey(HotkeyName) {
  global Recording, LogArr
  Critical()
  ; A hotkey thread can already be in flight when Stop() runs.
  if (!Recording || !(LogArr is Array))
    return
  k := GetKeyName(vksc := SubStr(A_ThisHotkey, 3))
  k := StrReplace(k, "Control", "Ctrl"), r := SubStr(k, 2)
  if (r ~= "^(?i:Alt|Ctrl|Shift|Win)$")
    LogKey_Control(k)
  else if (k ~= "^(?i:LButton|RButton|MButton)$")
    LogKey_Mouse(k)
  else {
    if (k = "NumpadLeft" || k = "NumpadRight") && !GetKeyState(k, "P")
      return
    k := StrLen(k) > 1 ? "{" k "}" : k ~= "\w" ? k : "{" vksc "}"
    Log(k, 1)
  }
}

LogKey_Control(key) {
  global LogArr
  static downKeys := Map()
  originalKey := key  ; Store original before remapping
  k := InStr(key, "Win") ? key : SubStr(key, 2)

  ; Record the key as being pressed
  downKeys[originalKey] := true

  ; Log the key down event
  Log("{" k " Down}", 1)

  Critical("Off")
  ErrorLevel := !KeyWait(key)
  Critical()

  ; Log the key up event. In TIMED/HUMAN mode the elapsed time between these
  ; two Log() calls becomes a Sleep(), so the real hold duration survives.
  Log("{" k " Up}", 1)

  ; Remove the key from pressed keys
  downKeys.Delete(originalKey)
}

LogKey_Mouse(key) {
  global LogArr, RelativeX, RelativeY, RecordMode, MouseMode, Recording
  k := SubStr(key, 1, 1)
  ; HumanClick mirrors MouseClick's signature and the trailing-comment widths,
  ; so the down/up consolidation SubStr() offsets below stay valid for both.
  fn := (RecordMode == "human") ? "HumanClick" : "MouseClick"

  ;screen
  CoordMode("Mouse", "Screen")
  MouseGetPos(&X, &Y, &id)
  Log((MouseMode == "window" || MouseMode == "relative" ? ";" : "") fn "(`"" k "`", " X ", " Y ",,, `"D`") `;screen")

  ;window
  CoordMode("Mouse", "Window")
  MouseGetPos(&WindowX, &WindowY, &id)
  Log((MouseMode != "window" ? ";" : "") fn "(`"" k "`", " WindowX ", " WindowY ",,, `"D`") `;window")

  ;relative
  CoordMode("Mouse", "Screen")
  MouseGetPos(&tempRelativeX, &tempRelativeY, &id)
  Log((MouseMode != "relative" ? ";" : "") fn "(`"" k "`", " (tempRelativeX - RelativeX) ", " (tempRelativeY - RelativeY) ",,, `"D`", `"R`") `;relative")
  RelativeX := tempRelativeX
  RelativeY := tempRelativeY

  ;get dif
  CoordMode("Mouse", "Screen")
  MouseGetPos(&X1, &Y1)
  t1 := A_TickCount
  Critical("Off")
  ErrorLevel := !KeyWait(key)
  Critical()
  t2 := A_TickCount
  if (t2 - t1 <= 200)
    X2 := X1, Y2 := Y1
  else
    MouseGetPos(&X2, &Y2)

  ; Same teardown race as LogKey_Control: recording may have been stopped
  ; while this thread sat in KeyWait, so LogArr can be gone.
  if (!Recording || !(LogArr is Array))
    return

  ;log screen
  i := LogArr.Length - 2, r := LogArr[i]
  if (InStr(r, ",,, `"D`")") && Abs(X2 - X1) + Abs(Y2 - Y1) < 5)
    LogArr[i] := SubStr(r, 1, -16) ") `;screen", Log()
  else
    Log((MouseMode == "window" || MouseMode == "relative" ? ";" : "") fn "(`"" k "`", " (X + X2 - X1) ", " (Y + Y2 - Y1) ",,, `"U`") `;screen")

  ;log window
  i := LogArr.Length - 1, r := LogArr[i]
  if (InStr(r, ",,, `"D`")") && Abs(X2 - X1) + Abs(Y2 - Y1) < 5)
    LogArr[i] := SubStr(r, 1, -16) ") `;window", Log()
  else
    Log((MouseMode != "window" ? ";" : "") fn "(`"" k "`", " (WindowX + X2 - X1) ", " (WindowY + Y2 - Y1) ",,, `"U`") `;window")

  ;log relative
  i := LogArr.Length, r := LogArr[i]
  if (InStr(r, ",,, `"D`", `"R`")") && Abs(X2 - X1) + Abs(Y2 - Y1) < 5)
    LogArr[i] := SubStr(r, 1, -23) ",,,, `"R`") `;relative", Log()
  else
    Log((MouseMode != "relative" ? ";" : "") fn "(`"" k "`", " (X2 - X1) ", " (Y2 - Y1) ",,, `"U`", `"R`") `;relative")
}

LogWindow() {
  global oldid, LogArr, MouseMode, Recording
  static oldtitle
  if (!Recording || !(LogArr is Array))
    return
  id := WinExist("A")
  if (!id)
    return
  title := WinGetTitle(id)
  class := WinGetClass(id)
  if (title = "" && class = "")
    return
  if (id = oldid && title = oldtitle)
    return
  oldid := id, oldtitle := title
  title := SubStr(title, 1, 50)
  title .= class ? " ahk_class " class : ""
  title := RegExReplace(Trim(title), "[``%;]", "``$0")
  CommentString := ""
  if (MouseMode != "window")
    CommentString := ";"
  s := CommentString "tt := `"" title "`"`n" CommentString "WinWait(tt)" . "`n" CommentString "if (!WinActive(tt))`n" CommentString "  WinActivate(tt)"
  i := LogArr.Length
  r := i = 0 ? "" : LogArr[i]
  if (InStr(r, "tt = ") = 1)
    LogArr[i] := s, Log()
  else
    Log(s)
}

; Push a Sleep line for `Delay` ms, honouring the active recording mode.
;   legacy      : only >200ms, halved, and commented out unless RecordSleep=true
;   timed/human : every delay >= MIN_SLEEP, verbatim, scaled by SPEED at runtime
EmitSleep(Delay) {
  global LogArr, RecordSleep, RecordMode, MIN_SLEEP
  if (RecordMode == "legacy") {
    if (Delay > 200)
      LogArr.Push((RecordSleep == "false" ? ";" : "") "Sleep(" (Delay // 2) ")")
    return
  }
  if (Delay >= MIN_SLEEP)
    LogArr.Push("Sleep(Round(" Delay " * SPEED))")
}

Log(str := "", Keyboard := false) {
  global LogArr, RecordSleep, RecordMode, Recording
  static LastTime := 0, KeyboardBuffer := ""
  t := A_TickCount
  Delay := (LastTime ? t - LastTime : 0)
  LastTime := t
  if (str = "")
    return
  ; LogKey_Control drops Critical and blocks in KeyWait while a modifier is
  ; held. Stopping with +F2 / ^+F2 runs Stop() during that wait, so the thread
  ; resumes and logs its "Up" after recording has already ended. Bail out
  ; instead of pushing onto a torn-down LogArr.
  if (!Recording || !(LogArr is Array))
    return
  i := LogArr.Length
  r := i = 0 ? "" : LogArr[i]

  if (Keyboard) {
    ; Special handling for modifier keys and key combinations
    if (InStr(str, " Down}") || InStr(str, " Up}")) {
      ; This is a modifier key event, handle it directly
      EmitSleep(Delay)
      LogArr.Push("Send(`"" . str . "`")")
      return
    }

    ; Legacy mode coalesces runs of keystrokes into a single Send("{Blind}abc"),
    ; which throws away the cadence between them. TIMED/HUMAN keep one Send per
    ; keystroke so each gets its own preceding Sleep.
    if (RecordMode == "legacy" && InStr(r, "Send") && Delay < 1000 && !InStr(r, " Down}") && !InStr(r, " Up}")) {
      ; Continue normal keyboard sequence for regular keys
      KeyboardBuffer .= str
      ; Update the existing Send command with the complete buffer
      LogArr[i] := "Send(`"{Blind}" . KeyboardBuffer . "`")"
    } else {
      ; Start a new keyboard buffer
      KeyboardBuffer := str
      ; Create a new Send command
      EmitSleep(Delay)
      LogArr.Push("Send(`"{Blind}" . KeyboardBuffer . "`")")
    }
    return
  }

  ; For non-keyboard actions, reset the keyboard buffer
  KeyboardBuffer := ""

  EmitSleep(Delay)
  LogArr.Push(str)
}

;============ Human mouse movement (injected into HUMAN recordings) =============

BuildHumanHelpers() {
  ; Single-quoted literals so the embedded double quotes need no escaping.
  ; Backtick escapes still apply inside single quotes in AHK v2, hence `; below.
  L := [
    ';============ HumanMove: natural cursor travel =============',
    '; Drop-in replacement for MouseClick(). The signature is kept identical so',
    '; recorded lines can be flipped between MouseClick and HumanClick freely.',
    'HumanClick(btn, x := "", y := "", clicks := "", speed := "", opts := "", rel := "") {',
    '    if (x != "" && y != "") {',
    '        if (rel = "R") {',
    '            CoordMode("Mouse", "Screen")',
    '            MouseGetPos(&cx, &cy)',
    '            HumanMove(cx + x, cy + y)',
    '        } else {',
    '            HumanMove(x, y)',
    '        }',
    '    }',
    '    u := StrUpper(opts)',
    '    n := (clicks = "") ? 1 : clicks',
    '    if (InStr(u, "D"))',
    '        Click(btn " Down")',
    '    else if (InStr(u, "U"))',
    '        Click(btn " Up")',
    '    else',
    '        Click(btn " " n)',
    '}',
    '',
    '; Absolute move through the injected-input path (mouse_event) rather than',
    '; SetCursorPos, so the motion is visible to apps that read raw input',
    '; instead of polling the cursor position.',
    'HumanPos(x, y) {',
    '    static vx := DllCall("GetSystemMetrics", "int", 76)   `; SM_XVIRTUALSCREEN',
    '    static vy := DllCall("GetSystemMetrics", "int", 77)   `; SM_YVIRTUALSCREEN',
    '    static vw := DllCall("GetSystemMetrics", "int", 78)   `; SM_CXVIRTUALSCREEN',
    '    static vh := DllCall("GetSystemMetrics", "int", 79)   `; SM_CYVIRTUALSCREEN',
    '    nx := Round((x - vx) * 65535 / (vw - 1))',
    '    ny := Round((y - vy) * 65535 / (vh - 1))',
    '    `; MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK',
    '    DllCall("mouse_event", "uint", 0xC001, "int", nx, "int", ny, "uint", 0, "uptr", 0)',
    '}',
    '',
    '; Windows defaults to a ~15.6ms scheduler tick, which makes Sleep(4) sleep',
    '; ~15.6ms and stretches a paced move to 2-3x its intended duration. Ask for',
    '; 1ms resolution once; the OS restores it when this macro process exits.',
    'HumanTimer() {',
    '    static init := DllCall("winmm\timeBeginPeriod", "uint", 1)',
    '    return init',
    '}',
    '',
    '; Monotonic high-resolution clock, in milliseconds.',
    'HumanNow() {',
    '    static freq := 0',
    '    if (!freq)',
    '        DllCall("QueryPerformanceFrequency", "int64*", &freq)',
    '    cnt := 0',
    '    DllCall("QueryPerformanceCounter", "int64*", &cnt)',
    '    return cnt * 1000.0 / freq',
    '}',
    '',
    '; Cubic bezier path with a randomised perpendicular bow, ease-in-out',
    '; velocity, per-step jitter, and an overshoot-then-correct on long throws.',
    '; Duration follows Fitts law: a + b * log2(2D/W + 1).',
    '; The loop is driven by elapsed wall-clock time rather than a fixed step',
    '; count, so the total duration stays correct even if Sleep() overshoots.',
    'HumanMove(tx, ty) {',
    '    global SPEED',
    '    HumanTimer()',
    '    CoordMode("Mouse", "Screen")',
    '    MouseGetPos(&sx, &sy)',
    '    dx := tx - sx, dy := ty - sy',
    '    dist := Sqrt(dx * dx + dy * dy)',
    '    if (dist < 2) {',
    '        HumanPos(tx, ty)',
    '        return',
    '    }',
    '',
    '    `; Tuned so a ~1100px throw lands near 700ms end-to-end (measured), which',
    '    `; sits in the middle of the human range. Raise b to make travel lazier.',
    '    dur := (70 + 85 * Log(2 * dist / 12 + 1) / Log(2)) * Random(0.85, 1.2) * SPEED',
    '',
    '    px := -dy / dist, py := dx / dist               `; unit normal to the path',
    '    bow := dist * Random(0.04, 0.14) * (Random(0, 1) ? 1 : -1)',
    '    c1x := sx + dx * 0.30 + px * bow',
    '    c1y := sy + dy * 0.30 + py * bow',
    '    c2x := sx + dx * 0.68 + px * bow * 0.55',
    '    c2y := sy + dy * 0.68 + py * bow * 0.55',
    '',
    '    ox := tx, oy := ty',
    '    over := (dist > 220)',
    '    if (over) {',
    '        om := Random(4.0, 14.0)                     `; aim past the target',
    '        ox += dx / dist * om, oy += dy / dist * om',
    '    }',
    '',
    '    t0 := HumanNow()',
    '    Loop 4000 {                                     `; safety cap, not the pacer',
    '        t := (HumanNow() - t0) / dur',
    '        if (t >= 1)',
    '            break',
    '        e := (t < 0.5) ? 4 * t * t * t : 1 - ((-2 * t + 2) ** 3) / 2   `; easeInOutCubic',
    '        u := 1 - e',
    '        x := u*u*u*sx + 3*u*u*e*c1x + 3*u*e*e*c2x + e*e*e*ox',
    '        y := u*u*u*sy + 3*u*u*e*c1y + 3*u*e*e*c2y + e*e*e*oy',
    '        if (t < 0.97 && dist > 40) {',
    '            x += Random(-1.0, 1.0)',
    '            y += Random(-1.0, 1.0)',
    '        }',
    '        HumanPos(Round(x), Round(y))',
    '        Sleep(4)                                    `; ~200Hz with 1ms timer res',
    '    }',
    '',
    '    if (over) {',
    '        Sleep(Round(Random(20, 65) * SPEED))        `; correction latency',
    '        HumanSettle(ox, oy, tx, ty)',
    '    }',
    '    HumanPos(tx, ty)',
    '    Sleep(Round(Random(15, 55) * SPEED))            `; dwell before the click',
    '}',
    '',
    '; Short decelerating corrective hop from the overshoot point to the target.',
    'HumanSettle(sx, sy, tx, ty) {',
    '    n := Random(6, 11)',
    '    Loop n {',
    '        t := A_Index / n',
    '        e := 1 - (1 - t) ** 3                       `; easeOutCubic',
    '        HumanPos(Round(sx + (tx - sx) * e), Round(sy + (ty - sy) * e))',
    '        Sleep(Random(5, 11))',
    '    }',
    '}'
  ]
  out := ""
  for line in L
    out .= line "`n"
  return out
}
