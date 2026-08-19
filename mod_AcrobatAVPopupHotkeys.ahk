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
; คืนตำแหน่งเมาส์กลับจุดเดิม (บันทึกตำแหน่งก่อนคลิก แล้วคืนกลับหลังคลิกเสร็จ)
; ใช้พิกัดแบบ Screen (พิกเซลจริง) แทน Client เดิม เพราะสคริปต์ตั้ง DPI awareness
; ไว้แล้วด้านบนสุดของไฟล์ (SetProcessDpiAwarenessContext) พิกัด Screen จึงตรงเป๊ะ
; ทุกจอแม้แต่ละจอจะขนาด/สเกลไม่เท่ากัน (ไม่ต้องแปลงพิกัดต่อจอเอง)
; =========================
global g_SavedMouseX := 0
global g_SavedMouseY := 0

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

; หมายเหตุ: ClickOffset() ใช้ ControlClick ซึ่งไม่ขยับเมาส์จริงระหว่างคลิกอยู่แล้ว
; (ControlClick ส่งคลิกตรงเข้า control โดยไม่ต้องย้ายเคอร์เซอร์) ตำแหน่งเมาส์จึงไม่ขยับ
; ระหว่างคลิกเลย ที่ต้องบันทึก/คืนตรงนี้คือกันไว้เผื่อ Acrobat มีพฤติกรรม
; focus-follows-mouse หรืออนาคตเปลี่ยนไปใช้การคลิกแบบขยับเมาส์จริง
SaveMousePos() {
    global g_SavedMouseX, g_SavedMouseY
    CoordMode("Mouse", "Screen")
    MouseGetPos(&g_SavedMouseX, &g_SavedMouseY)
}

RestoreMousePos() {
    global g_SavedMouseX, g_SavedMouseY
    ; ไม่เช็ค WinActive ตรงนี้ (ต่างจาก MoveMouseToEnd เดิม) เพราะจุดประสงค์คือ
    ; คืนเมาส์กลับให้ผู้ใช้เสมอไม่ว่า Acrobat จะยังโฟกัสอยู่หรือไม่ตอนคลิกเสร็จ
    ; ถ้าเช็คแล้วบังเอิญ false ช่วงนั้นพอดี จะไม่คืนตำแหน่งให้เลยแบบเงียบ ๆ
    CoordMode("Mouse", "Screen")
    MouseMove(g_SavedMouseX, g_SavedMouseY, 0)
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
            SaveMousePos()
            ClickMultiStep_NoMove(K1)
            RestoreMousePos()
        }
    }
}

; =========================================================
; HOTKEYS
; =========================================================
#HotIf WinActive("ahk_group AcrobatApps")

SC002:: HandleSC002TriplePress()

#HotIf WinActive("ahk_group AcrobatApps") && g_AcroHotkeysEnabled
SC00B:: (SaveMousePos(), ClickMultiStep_NoMove(K0), RestoreMousePos())
SC003:: (SaveMousePos(), ClickMultiStep_NoMove(K2), RestoreMousePos())
SC004:: (SaveMousePos(), ClickMultiStep_NoMove(K3), RestoreMousePos())
SC005:: (SaveMousePos(), ClickSingle_NoMove(K4[1]), RestoreMousePos())
SC006:: (SaveMousePos(), ClickMultiStep_NoMove(K5), RestoreMousePos())
SC007:: (SaveMousePos(), ClickMultiStep_NoMove(K6), RestoreMousePos())
SC008:: (SaveMousePos(), ClickMultiStep_NoMove(K7), RestoreMousePos())
SC009:: (SaveMousePos(), ClickMultiStep_NoMove(K8), RestoreMousePos())
SC00A:: (SaveMousePos(), ClickMultiStep_NoMove(K9), RestoreMousePos())

#HotIf

;SC079 คือ Scan Code ของปุ่ม 変換 ;

#SingleInstance Force

#HotIf WinActive("ahk_exe EXCEL.EXE")

; ปุ่มข้างเมาส์ (ปุ่ม Back) = เขียนเลข 1 ลงคอลัมน์ Q ของแถวที่กำลังเลือกอยู่
; ไม่เลื่อน/ไม่เปลี่ยนตำแหน่งหน้าจอ Excel — ใช้งานได้เฉพาะตอนโฟกัส Excel เท่านั้น
; นอกเหนือจากนี้ปุ่มจะกลับไปเป็นปุ่มย้อนกลับตามปกติ
; กดครั้งเดียว = เขียนเลข 1 ที่ Q ของแถวนั้น
; กด 2 ครั้งติดกันเร็ว ๆ (ภายใน 400ms, แถวเดียวกัน) = คัดลอกช่วง S:Y ของแถวนั้นเพิ่ม
XButton1::
{
    try
    {
        xl := ComObjActive("Excel.Application")
        row := xl.ActiveCell.Row
        xl.Range("Q" row).Value := 1

        if (A_PriorHotkey = "XButton1" && A_TimeSincePriorHotkey <= 400)
            xl.Range("S" row ":Y" row).Copy()
    }
    catch
    {
        MsgBox "ไม่พบ Excel ที่กำลังทำงานอยู่"
    }
}

; ปุ่มข้างเมาส์ (ปุ่ม Forward) = ลบค่าออกจากคอลัมน์ Q ของแถวที่กำลังเลือกอยู่
; (ย้อนสิ่งที่ XButton1 เขียนไว้) เงื่อนไข/ขอบเขตเหมือนกับ XButton1 ทุกประการ
XButton2::
{
    try
    {
        xl := ComObjActive("Excel.Application")
        row := xl.ActiveCell.Row
        xl.Range("Q" row).Value := ""
    }
    catch
    {
        MsgBox "ไม่พบ Excel ที่กำลังทำงานอยู่"
    }
}

#HotIf