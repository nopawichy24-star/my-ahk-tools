; mod_Checkln.ahk

global lastRunDate := ""

global g_IsLoggingIn := false
global g_LastActiveHwnd := 0
global g_BrutalEnabled := false

;----------------------------------------
; INIT
;----------------------------------------
CheckIn_Init() {

    SetTimer(CheckAutoCheckIn, 1000)
    SetTimer(LaunchApps, -1500)
  
    if !IsWorkTime() {
        SetTimer(() => DoCheckIn(true), -3000)
    }
}

CheckIn_Init()

;----------------------------------------
; 🕒 CHECK WORK TIME
;----------------------------------------
IsWorkTime() {

    current := A_Hour * 100 + A_Min
    return (current >= 850 && current <= 1725)

}

;----------------------------------------
; ScrollLock = Manual Check-in
;----------------------------------------
ScrollLock:: {
    DoCheckIn(true)
}


;----------------------------------------
; Auto popup 17:30
;----------------------------------------
CheckAutoCheckIn() {

    global lastRunDate

    currentDate := FormatTime(, "yyyyMMdd")

    if (A_Hour = 17 && A_Min = 30) {

        if (lastRunDate != currentDate) {

            btn := MsgBox(
                "ถึงเวลา 17:30 แล้ว ต้องการให้รันเช็คอินอัตโนมัติไหม?",
                "Auto Check-in",
                0x24
            )

            lastRunDate := currentDate

            if (btn = "Yes")
                DoCheckIn(true)
        }
    }
}


;----------------------------------------
; OPEN WEB + LOGIN
;----------------------------------------
DoCheckIn(force := false) {

    edge := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

    if !FileExist(edge)
        edge := "C:\Program Files\Microsoft\Edge\Application\msedge.exe"

    if !FileExist(edge) {
        MsgBox("ไม่พบ Microsoft Edge")
        return
    }

    url := "https://id.obc.jp/5d7vqw9mju18/"

    pid := Run('"' edge '" "' url '"')

    if (pid) {

        if !WinWait("ahk_pid " pid, , 10) {
            MsgBox("เปิดเว็บไม่สำเร็จ")
            return
        }

        WinActivate("ahk_pid " pid)
        WinMaximize("ahk_pid " pid)

    }

    Sleep 4000

    SendText(LOGIN_ID)
    Sleep 300
    Send("{Enter}")

    Sleep 1000

    SendText(LOGIN_PASS)
    Sleep 200
    Send("{Enter}")

    Sleep 3000

    Loop 7 {
        Send("{Tab}")
        Sleep(50)
    }

    Send("{Enter}")

    Sleep(100)

    Send("{Tab}")

    Sleep(100)

    Send("{Enter}")

    SoundBeep(1000,150)
}


;----------------------------------------
; AUTO START APPS
;----------------------------------------
LaunchApps() {

    if !WinExist("ahk_exe OUTLOOK.EXE") {

        Run("outlook.exe")

        if WinWait("ahk_exe OUTLOOK.EXE", , 10000)
            WinActivate("ahk_exe OUTLOOK.EXE")

    } else {

        WinActivate("ahk_exe OUTLOOK.EXE")

    }

    if !WinExist("ahk_exe chrome.exe") {

        chrome := "C:\Program Files\Google\Chrome\Application\chrome.exe"

        if !FileExist(chrome)
            chrome := "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"

        if FileExist(chrome) {

            url1 := "https://chatgpt.com/auth/login"
            url2 := "https://claude.ai/login"
            url3 := "https://translate.google.com/"

            Run('"' chrome '" --incognito "' url1 '" "' url2 '" "' url3 '"')
        }
    }
}


;----------------------------------------
; AppsKey = เปิดไฟล์ผังที่นั่ง (座席表) ตอนกด 1 ครั้ง
; กด 2 ครั้งติดกันเร็ว ๆ = ยกเลิกคำสั่งเดิม แล้วส่ง Ctrl+F ไปที่หน้าต่างที่ active อยู่แทน
; รูปแบบ deferred single/double press เดียวกับ F6/F10 ในไฟล์นี้/mod_Hotkeys.ahk - รอดูก่อนว่า
; จะมีครั้งที่ 2 ตามมาไหม ก่อนค่อยเรียกฟังก์ชันเดิม กันไม่ให้ single-click ทำงานไปก่อนโดยไม่ตั้งใจ
; ตอน double-click
;----------------------------------------
global AppsKey_Pending := false
AppsKey_DoublePressMs := 400

AppsKey:: {
    global AppsKey_Pending

    if (AppsKey_Pending) {
        ; กดครั้งที่ 2 ทันเวลา -> ยกเลิกคำสั่งเดิมที่รออยู่ แล้วทำ double-click แทน
        AppsKey_Pending := false
        SetTimer(AppsKey_RunSingle, 0)
        AppsKey_RunDouble()
        return
    }

    ; กดครั้งแรก -> รอดูว่าจะมีครั้งที่ 2 ตามมาไหม ก่อนค่อยเปิด PDF
    AppsKey_Pending := true
    SetTimer(AppsKey_RunSingle, -AppsKey_DoublePressMs)
}

AppsKey_RunSingle() {
    global AppsKey_Pending
    AppsKey_Pending := false

    path := "C:\Users\U004797\Desktop\販売管理\連絡\本社3F 座席表 260806.pdf"

    if !FileExist(path) {
        MsgBox("หาไฟล์ไม่เจอ:`n" path)
        return
    }

    OpenPdfInAcrobat(path)
}

; Double-click AppsKey: ไม่เปิด PDF - ส่ง Ctrl+F ไปที่หน้าต่าง/โปรแกรมที่ active อยู่ตอนนั้น
; (Send ไม่ระบุ target จะส่งไปที่หน้าต่างที่ OS โฟกัสอยู่ปัจจุบันเสมอ ตามโครงสร้างเดิมของสคริปต์)
AppsKey_RunDouble() {
    Send("^f")
}

;----------------------------------------
; เปิด PDF ด้วย Acrobat โดยตรง (ไม่ผ่าน Edge)
;----------------------------------------
; เหตุผลที่เปลี่ยนจาก Edge --new-window มาเป็นเรียก Acrobat.exe ตรง ๆ:
; Edge ต้องเปิด process เบราว์เซอร์ใหม่ทั้งตัว + init PDF viewer extension ก่อนเริ่ม render
; ทุกครั้ง ซึ่งช้ากว่า native PDF renderer ของ Acrobat มาก โดยเฉพาะไฟล์ใหญ่
; ใช้สวิตช์ /n (เอกสารของ Adobe: เปิดเป็น instance/หน้าต่างใหม่) กัน Acrobat เอาไฟล์ไปเปิด
; เป็นแท็บใหม่ในหน้าต่างที่เปิดอยู่แล้ว - ต้องการหน้าต่างแยกเสมอตามที่ผู้ใช้ระบุ
;
; ทำไมต้องหา HWND หน้าต่างใหม่เอง แทนที่จะ WinWait("ahk_exe Acrobat.exe") เฉย ๆ:
; Acrobat เป็นแอปแบบ single-instance - ถ้ามี Acrobat เปิดอยู่ก่อนแล้ว (ซึ่งเป็นกรณีปกติของ
; ผู้ใช้ที่ใช้ hotkey คลิก annotation ผ่าน mod_AcrobatAVPopupHotkeys.ahk เป็นประจำอยู่แล้ว)
; process ที่ Run() เปิดตรงนี้จะแค่ส่งสัญญาณไปให้ instance เดิมเปิดไฟล์ แล้วปิดตัวเองทันที
; ทำให้ WinWait("ahk_exe Acrobat.exe") จับหน้าต่าง Acrobat ที่มีอยู่ก่อนแล้ว (ซึ่งอาจ maximize
; อยู่แล้วจากก่อนหน้า ทำให้ดูเหมือน WinMaximize ไม่มีผล) แทนที่จะเป็นหน้าต่างใหม่ที่เพิ่งเปิดจริง ๆ
; แก้โดยจด HWND ของหน้าต่าง Acrobat ทั้งหมดที่มีอยู่ก่อน Run() แล้วหลังจากนั้น poll หา HWND ที่
; ไม่เคยอยู่ในลิสต์เดิม นั่นคือหน้าต่างใหม่แน่นอน
;
; ทำไมต้องเลือกตาม "ขนาดใหญ่สุด" ไม่ใช่แค่ "อันแรกที่เจอใหม่": Acrobat ไม่ได้สร้างแค่หน้าต่าง
; เอกสารหลักตอนเปิดไฟล์ - มันสร้างหน้าต่างเล็ก ๆ อื่นด้วย เช่น floating toolbar ของ annotation
; popup (ตัวเดียวกับที่ mod_AcrobatAVPopupHotkeys.ahk เล็งอยู่) ซึ่งก็นับเป็น "ahk_exe Acrobat.exe"
; เหมือนกัน ถ้า diff แล้วเจอหน้าต่างเล็กนี้ก่อนแล้วเอาไป WinMaximize ทันที มันจะขยายเต็มจอกลาย
; เป็นกล่องว่างเปล่า/ขาวทั้งจอ (พื้นที่ client ส่วนใหญ่ไม่มีอะไรวาด) - อาการตรงกับที่รายงานว่า
; "อีกจอนึงขาวทั้งจอ" เป๊ะ เพราะ popup toolbar อาจไปโผล่คนละจอกับเอกสารหลัก จึงต้องรอเก็บผู้สมัคร
; หลายตัว แล้วเลือกตัวที่มีพื้นที่ (กว้าง*สูง) มากที่สุด ซึ่งคือหน้าต่างเอกสารจริงเสมอ
OpenPdfInAcrobat(path) {
    acrobat := "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe"

    if !FileExist(acrobat)
        acrobat := "C:\Program Files (x86)\Adobe\Acrobat DC\Acrobat\Acrobat.exe"

    if !FileExist(acrobat) {
        MsgBox("หา Acrobat.exe ไม่เจอ:`n" acrobat)
        return
    }

    existing := WinGetList("ahk_exe Acrobat.exe")

    ; /A "navpanes=0&pagemode=none" คือ PDF Open Parameter มาตรฐานของ Adobe (ไม่ใช่การเดา -
    ; เป็นสเปกที่เอกสารทางการของ Adobe ระบุไว้) สั่งไม่ให้แสดง navigation pane/thumbnails ตอนเปิด
    ; แต่ต้องบอกตรง ๆ ว่าสเปกนี้มีมาก่อนแผง "All Tools"/"Comment" ของ Acrobat DC ยุคใหม่มาก จึง
    ; อาจไม่ครอบคลุมสองแผงนั้นโดยตรง - ใส่ไว้เพราะปลอดภัยและมีโอกาสช่วยได้บ้าง ไม่ใช่คำตอบเต็มรูปแบบ
    Run('"' acrobat '" /n /A "navpanes=0&pagemode=none" "' path '"')

    newHwnd := 0
    bestArea := 0
    foundGoodAt := 0
    start := A_TickCount
    while (A_TickCount - start < 10000) {
        for hwnd in WinGetList("ahk_exe Acrobat.exe") {
            isOld := false
            for old in existing {
                if (old = hwnd) {
                    isOld := true
                    break
                }
            }
            if isOld
                continue

            try
                WinGetPos(&wx, &wy, &ww, &wh, hwnd)
            catch
                continue

            area := ww * wh
            if (area > bestArea) {
                bestArea := area
                newHwnd := hwnd
            }
        }

        ; เจอหน้าต่างที่ใหญ่พอจะเป็นเอกสารจริงแล้ว (ไม่ใช่ toolbar เล็ก ๆ) - รออีกนิดเผื่อมีตัวที่
        ; ใหญ่กว่านี้โผล่ตามมา (กันกรณีเอกสารหลักยัง render ขนาดไม่นิ่ง) แล้วค่อยฟันธง
        if (bestArea >= 500 * 400) {
            if !foundGoodAt
                foundGoodAt := A_TickCount
            if (A_TickCount - foundGoodAt >= 250)
                break
        }
        Sleep(50)
    }

    if !newHwnd
        return  ; หาไม่เจอจริง ๆ (Acrobat เปิดช้าผิดปกติ) - ปล่อยผ่าน ไม่ยุ่งกับหน้าต่างอื่นที่ไม่ใช่ของเรา

    WinActivate(newHwnd)
    WinMaximize(newHwnd)

    ; ความพยายามเบื้องต้นให้ปิดแผง "All Tools"/Comment ที่บางทีเด้งขึ้นอัตโนมัติตอนเปิดไฟล์ -
    ; Escape เป็นคีย์ที่ปิด overlay/แผงชั่วคราวได้ในหลายโปรแกรมรวมถึง Acrobat แต่ยังไม่ยืนยันว่า
    ; ปิดแผงที่ค้างอยู่ถาวร (pinned) ได้ 100% เพราะไม่มีเครื่อง Acrobat จริงให้ทดสอบ ถ้าลองแล้ว
    ; แผงยังไม่ปิด รบกวนบอกชื่อไอคอน/ตำแหน่งปุ่มปิดที่กดอยู่ตอนนี้ จะได้ทำ ControlClick ที่แม่นยำแทน
    Sleep(400)
    Send("{Escape}")
}


;----------------------------------------
; TOGGLE BRUTAL MODE
;----------------------------------------
^!b:: {

    global g_BrutalEnabled

    if (g_BrutalEnabled) {

        g_BrutalEnabled := false
        SetTimer(BrutalAutoEnter, 0)

        TrayTip("Brutal Auto-Enter","ปิดโหมดโหดแล้ว",2)

    } else {

        g_BrutalEnabled := true
        SetTimer(BrutalAutoEnter, 200)

        TrayTip("Brutal Auto-Enter","เปิดโหมดโหด (200 ms)",2)

    }
}


;----------------------------------------
; BRUTAL AUTO ENTER
;----------------------------------------
BrutalAutoEnter() {

    global g_IsLoggingIn, g_LastActiveHwnd, g_BrutalEnabled

    if !g_BrutalEnabled
        return

    if g_IsLoggingIn
        return

    hwnd := 0

    try hwnd := WinGetID("A")
    catch
        return

    if !hwnd
        return

    if (hwnd = g_LastActiveHwnd)
        return

    exe := ""

    try exe := WinGetProcessName(hwnd)
    catch
        exe := ""

    if (exe ~= "i)OUTLOOK\.EXE") {
        g_LastActiveHwnd := hwnd
        return
    }

    g_LastActiveHwnd := hwnd

    Sleep 20
    Send "{Enter}"
}