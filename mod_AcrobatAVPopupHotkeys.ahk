#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook
#MaxThreads 20
#MaxThreadsPerHotkey 10

; ================= DPI AWARE =================
; ทำให้รองรับหลายจอ + scaling ต่างกัน
DllCall("SetProcessDpiAwarenessContext", "ptr", -4, "ptr")

; =========================================================
; Acrobat / Reader Group
; =========================================================
GroupAdd "AcrobatApps", "ahk_exe Acrobat.exe"
GroupAdd "AcrobatApps", "ahk_exe AcroRd32.exe"

; =========================
; GLOBALS
; =========================
global g_AcroHotkeysEnabled := false
SC002_WINDOW_MS := 650
global g_sc002Count := 0

STEP_DELAY  := 70
RETRY_SLEEP := 45
RETRY_COUNT := 6

; =========================
; FINAL MOUSE POSITION (Client-safe version)
; =========================
END_CX := 922
END_CY := 516

; =========================
; OFFSETS
; =========================
K1 := [[34,291],[51,216]]
K2 := [[33,106]]
K3 := [[33,227],[91,206]]
K4 := [[26,50]]
K5 := [[33,227],[66,105]]
K6 := [[33,227],[88,153]]
K7 := [[33,227],[83,27]]

K7_FIRST_X := 33
K7_FIRST_Y := 227

SHIFT_CM_UP := 1
SHIFT_PX_UP := Round((SHIFT_CM_UP / 2.54) * A_ScreenDPI)

K89_FIRST_X := K7_FIRST_X
K89_FIRST_Y := K7_FIRST_Y - SHIFT_PX_UP

K8 := [[K89_FIRST_X, K89_FIRST_Y],[97,146]]
K9 := [[K89_FIRST_X, K89_FIRST_Y],[94,86]]

K0_SECOND_X := 119
K0_SECOND_Y := 386
K0 := [[K7_FIRST_X, K7_FIRST_Y],[K0_SECOND_X, K0_SECOND_Y]]

; =========================================================
; HELPERS (CLIENT-BASED SAFE)
; =========================================================

MoveMouseToEnd() {
    if !WinActive("ahk_group AcrobatApps")
        return
    hwnd := WinExist("A")
    CoordMode "Mouse", "Client"
    MouseMove END_CX, END_CY, 0
}

GetAVPopup(which) {
    for hwnd in WinGetList("ahk_class AVL_AVPopup ahk_group AcrobatApps") {
        WinGetPos ,, &w,, hwnd
        if (which="toolbar" && w <= 140)
            return hwnd
        if (which="panel" && w >= 160)
            return hwnd
    }
    return 0
}

ClickOffset(which, x, y) {
    hwnd := GetAVPopup(which)
    if !hwnd
        return false

    ; Client-based click (ไม่สน scaling ไม่สนจอ)
    ControlClick "x" x " y" y, hwnd,, "Left", 1, "NA"
    return true
}

ClickStep(step, which) {
    global RETRY_COUNT, RETRY_SLEEP
    Loop RETRY_COUNT {
        if ClickOffset(which, step[1], step[2])
            return true
        Sleep RETRY_SLEEP
    }
    return false
}

ClickMultiStep_NoMove(steps) {
    global STEP_DELAY
    for i, step in steps {
        which := Mod(i, 2) = 1 ? "toolbar" : "panel"
        ClickStep(step, which)
        Sleep STEP_DELAY
    }
}

ClickSingle_NoMove(step) {
    ClickStep(step, "toolbar")
}

ShowToast(msg, ms := 1200) {
    ToolTip msg
    SetTimer(() => ToolTip(), -ms)
}

ToggleAcrobatHotkeys() {
    global g_AcroHotkeysEnabled
    g_AcroHotkeysEnabled := !g_AcroHotkeysEnabled
    ShowToast("Acrobat Hotkeys: " (g_AcroHotkeysEnabled ? "ON" : "OFF"))
}

; =========================
; TRIPLE PRESS (ปุ่ม 1)
; =========================
HandleSC002TriplePress() {
    global g_sc002Count, SC002_WINDOW_MS

    if (A_PriorHotkey = "SC002" && A_TimeSincePriorHotkey <= SC002_WINDOW_MS)
        g_sc002Count += 1
    else
        g_sc002Count := 1

    if (g_sc002Count >= 3) {
        g_sc002Count := 0
        ToggleAcrobatHotkeys()
    } else {
        global g_AcroHotkeysEnabled
        if (g_AcroHotkeysEnabled) {
            ClickMultiStep_NoMove(K1)
            MoveMouseToEnd()
        }
    }
}

; =========================================================
; HOTKEYS
; =========================================================
#HotIf WinActive("ahk_group AcrobatApps")

SC002:: HandleSC002TriplePress()

#HotIf WinActive("ahk_group AcrobatApps") && g_AcroHotkeysEnabled
SC00B:: (ClickMultiStep_NoMove(K0), MoveMouseToEnd())
SC003:: (ClickMultiStep_NoMove(K2), MoveMouseToEnd())
SC004:: (ClickMultiStep_NoMove(K3), MoveMouseToEnd())
SC005:: (ClickSingle_NoMove(K4[1]), MoveMouseToEnd())
SC006:: (ClickMultiStep_NoMove(K5), MoveMouseToEnd())
SC007:: (ClickMultiStep_NoMove(K6), MoveMouseToEnd())
SC008:: (ClickMultiStep_NoMove(K7), MoveMouseToEnd())
SC009:: (ClickMultiStep_NoMove(K8), MoveMouseToEnd())
SC00A:: (ClickMultiStep_NoMove(K9), MoveMouseToEnd())

#HotIf

;SC079 คือ Scan Code ของปุ่ม 変換 ;

#SingleInstance Force

DOUBLE_MS := 350

plusCount := 0
minusCount := 0

#HotIf WinActive("ahk_exe EXCEL.EXE")

NumpadAdd::
{
    global plusCount, DOUBLE_MS

    plusCount++

    SetTimer HandlePlus, -DOUBLE_MS
}

NumpadSub::
{
    global minusCount, DOUBLE_MS

    minusCount++

    SetTimer HandleMinus, -DOUBLE_MS
}

HandlePlus()
{
    global plusCount

    try
    {
        xl := ComObjActive("Excel.Application")

        if (plusCount = 2)
        {
            ; เพิ่มเฉพาะช่วงที่เลือก
            xl.Selection.Insert()
        }
        else if (plusCount >= 3)
        {
            ; เพิ่มทั้งแถว
            xl.ActiveCell.EntireRow.Insert()
        }
    }
    catch
    {
        MsgBox "ไม่พบ Excel ที่กำลังทำงานอยู่"
    }

    plusCount := 0
}

HandleMinus()
{
    global minusCount

    try
    {
        xl := ComObjActive("Excel.Application")

        if (minusCount = 2)
        {
            ; ลบเฉพาะช่วงที่เลือก
            xl.Selection.Delete()
        }
        else if (minusCount >= 3)
        {
            ; ลบทั้งแถว
            xl.ActiveCell.EntireRow.Delete()
        }
    }
    catch
    {
        MsgBox "ไม่พบ Excel ที่กำลังทำงานอยู่"
    }

    minusCount := 0
}

#HotIf