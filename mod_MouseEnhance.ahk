; mod_MouseEnhance.ahk

MouseEnhance_Init() {
    ; ยังไม่ต้องทำอะไรเป็นพิเศษ
}

; =========================
; EXPLORER: click-to-open / long-press-rename
; =========================
global ClickOpenMaxTime := 250
global LongPressTime    := 400
global MoveThreshold    := 7

global g_IsDown   := false
global g_DownX    := 0
global g_DownY    := 0
global g_DownTick := 0
global g_Mode     := ""

~LButton:: {
    global g_IsDown, g_DownX, g_DownY, g_DownTick, g_Mode, LongPressTime

    ; ต้องเป็น Explorer ที่ Active เท่านั้น
    if !WinActive("ahk_class CabinetWClass")
        return

    MouseGetPos &x, &y, &win, &ctrl

    ; ต้องคลิกในพื้นที่ไฟล์จริง ๆ เท่านั้น
    if !(ctrl ~= "SysListView32|DirectUIHWND")
        return

    g_IsDown   := true
    g_Mode     := "maybeOpen"
    g_DownX    := x
    g_DownY    := y
    g_DownTick := A_TickCount

    SetTimer CheckLongPress, -LongPressTime
}

CheckLongPress() {
    global g_IsDown, g_Mode, g_DownX, g_DownY, MoveThreshold

    if !g_IsDown
        return

    if !WinActive("ahk_class CabinetWClass")
        return

    MouseGetPos &x, &y, &win, &ctrl

    if !(ctrl ~= "SysListView32|DirectUIHWND")
        return

    if (Abs(x - g_DownX) > MoveThreshold
     || Abs(y - g_DownY) > MoveThreshold)
        return

    g_Mode := "rename"
}

~LButton Up:: {
    global g_IsDown, g_DownX, g_DownY, g_DownTick
    global g_Mode, ClickOpenMaxTime, MoveThreshold

    if !g_IsDown
        return

    g_IsDown := false

    if !WinActive("ahk_class CabinetWClass")
        return

    MouseGetPos &x, &y, &win, &ctrl

    if !(ctrl ~= "SysListView32|DirectUIHWND")
        return

    if (Abs(x - g_DownX) > MoveThreshold
     || Abs(y - g_DownY) > MoveThreshold) {
        g_Mode := "drag"
        return
    }

    elapsed := A_TickCount - g_DownTick

    if (g_Mode = "rename") {
        Send "{F2}"
        return
    }

    if (elapsed <= ClickOpenMaxTime) {
        Send "{Enter}"
    }
}

; =========================
; EXCEL: long-press = double-click
; =========================
global ExcelLongPressTime := 300
global ExcelMoveThreshold := 8

global ex_IsDown    := false
global ex_DownX     := 0
global ex_DownY     := 0
global ex_LongPress := false

#HotIf WinActive("ahk_exe EXCEL.EXE")

~LButton:: {
    global ex_IsDown, ex_DownX, ex_DownY, ex_LongPress, ExcelLongPressTime

    ex_IsDown    := true
    ex_LongPress := false

    MouseGetPos &ex_DownX, &ex_DownY

    SetTimer ExcelCheckLongPress, -ExcelLongPressTime
}

ExcelCheckLongPress() {
    global ex_IsDown, ex_DownX, ex_DownY, ex_LongPress, ExcelMoveThreshold

    if !ex_IsDown
        return

    MouseGetPos &x, &y

    if (Abs(x - ex_DownX) > ExcelMoveThreshold
     || Abs(y - ex_DownY) > ExcelMoveThreshold)
        return

    ex_LongPress := true
}

~LButton Up:: {
    global ex_IsDown, ex_DownX, ex_DownY, ex_LongPress, ExcelMoveThreshold

    if !ex_IsDown
        return

    ex_IsDown := false

    MouseGetPos &x, &y

    if (Abs(x - ex_DownX) > ExcelMoveThreshold
     || Abs(y - ex_DownY) > ExcelMoveThreshold)
        return

    if !ex_LongPress
        return

    Sleep 20
    Click 2
}

#HotIf
