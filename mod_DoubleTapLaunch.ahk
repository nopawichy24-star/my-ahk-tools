; mod_DoubleTapLaunch.ahk

global doubleTapTime := 300
global C_Count := 0
global V_Count := 0

DoubleTap_Init() {
}

CheckDouble(lastTime) {
    global doubleTapTime
    return (A_TickCount - lastTime < doubleTapTime)
}

; ===== Double Tap =====

~e:: {
    static last := 0
    if (CheckDouble(last))
        Run "msedge.exe"
    last := A_TickCount
}

~t:: {
    static last := 0
    if (CheckDouble(last))
        Run "ms-teams:"
    last := A_TickCount
}

~s:: {
    static last := 0
    if (CheckDouble(last))
        Run "ms-settings:"
    last := A_TickCount
}

~f:: {
    static last := 0
    if (CheckDouble(last))
        Run "explorer.exe"
    last := A_TickCount
}

~o:: {
    static last := 0
    if (CheckDouble(last)) {
        if !WinExist("ahk_exe OUTLOOK.EXE") {
            Run "outlook.exe"
        }
    }
    last := A_TickCount
}

~r:: {
    static last := 0
    if (CheckDouble(last)) {
        Run "calc.exe"
    }
    last := A_TickCount
}

; ===== C (double / triple) =====
~c:: {
    global C_Count
    C_Count++
    SetTimer(ProcessC, -300)
}

ProcessC() {
    global C_Count

    if (C_Count = 2) {
        Run 'chrome.exe --incognito'
    } else if (C_Count >= 3) {
        Run 'chrome.exe "https://www.google.com"'
    }

    C_Count := 0
}

; ===== V (TRIPLE TAP ONLY) =====
~v:: {
    global V_Count
    V_Count++
    SetTimer(ProcessV, -300)
}

ProcessV() {
    global V_Count

    if (V_Count >= 3) {
        if WinExist("ahk_exe Code.exe") {
            WinActivate "ahk_exe Code.exe"
        } else {
            Run "code"
        }
    }

    V_Count := 0
}