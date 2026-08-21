#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook
#MaxThreads 20
#MaxThreadsPerHotkey 10

; ================= DPI AWARE =================
; หมายเหตุ: ไฟล์นี้เคยตั้ง thread DPI awareness เป็น per-monitor แบบ global ทั้งสคริปต์ตรงนี้
; (เพื่อแก้กรอบ F6 บนจอสเกลต่างกัน) แต่ทำให้ A_ScreenDPI ที่ใช้คำนวณ SHIFT_PX_UP ด้านล่าง
; (สำหรับ K8/K9) เปลี่ยนค่าไปจากตอนที่ผู้ใช้ปรับเทียบ offset ปุ่มคลิกไว้แต่แรก ทำให้คลิกไม่ลงจุด
; ย้าย DPI awareness ไปตั้งแบบ scope เฉพาะช่วงสร้าง/ขยับกรอบ F6 ใน F6_StartOCR
; (mod_Hotkeys.ahk) แทน เพื่อให้ A_ScreenDPI ตรงนี้กลับไปเป็นค่าเดิมที่ผู้ใช้ปรับเทียบไว้

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
global g_sc002Gen := 0        ; token ของตำแหน่งเมาส์ต้นฉบับ คงที่ตลอด gesture การกด 1 รอบเดียวกัน
global g_sc002PressSeq := 0   ; เพิ่มทุกครั้งที่กด 1 ใช้แยกว่า timer ของการกดครั้งไหนยังเป็นตัวล่าสุด

STEP_DELAY  := 70
RETRY_SLEEP := 45
RETRY_COUNT := 6

; =========================
; คืนตำแหน่งเมาส์กลับจุดเดิมก่อนกด (ย้อนกลับจากที่เคยเปลี่ยนเป็น "ไปกึ่งกลางจอ" ไปแล้ว) แบบ
; transaction มี generation token เหมือนเดิม
;
; ทำไมต้องย้อนกลับ: การบังคับย้ายเมาส์ไปกึ่งกลางจอทันทีหลังคลิก ทำให้เคอร์เซอร์เคลื่อนออกจาก
; บริเวณ floating toolbar ของ Acrobat (AVL_AVPopup) ซึ่งพฤติกรรมทั่วไปของ toolbar ลอยแบบนี้คือ
; ซ่อนตัวเอง/ปิดไปเมื่อเมาส์เคลื่อนออกจากบริเวณมัน - พอกดปุ่มตัวเลขถัดไปเร็ว ๆ ติดกัน
; GetAVPopup() เลยหาไม่เจอหรือเจอ popup ที่สถานะไม่ตรงแล้ว ทำให้คลิกไม่ลงจุดที่ต้องการ
; คืนกลับเป็นคืนตำแหน่งเดิมแทน เพราะเมาส์จะได้ไม่ขยับออกจากบริเวณ toolbar โดยไม่จำเป็น
;
; ทำไมต้องมี token/generation: ทุกปุ่มตัวเลขใช้ตัวแปรร่วมกันชุดเดียว (g_SavedMouseX/Y)
; ถ้ากดปุ่มถัดไปเร็ว ๆ ก่อนที่ delayed restore ของปุ่มก่อนหน้าจะยิง ตัว delayed restore
; เก่านั้นต้องไม่ยิงไปทับตำแหน่งของ action ใหม่ที่กำลังทำอยู่ - MouseRestore_Begin()
; จะเพิ่ม generation ทุกครั้งที่เริ่ม action ใหม่ ทำให้ callback ของ generation เก่าเช็คแล้ว
; รู้ว่าตัวเองล้าสมัยแล้ว ไม่ต้องทำอะไร
; =========================
global g_MouseRestoreGen := 0
global g_SavedMouseX := 0
global g_SavedMouseY := 0

; เริ่ม "ธุรกรรม" คืนเมาส์ใหม่: บันทึกตำแหน่งปัจจุบัน + คืน token สำหรับ commit ทีหลัง
MouseRestore_Begin() {
    global g_MouseRestoreGen, g_SavedMouseX, g_SavedMouseY
    g_MouseRestoreGen += 1
    CoordMode("Mouse", "Screen")
    MouseGetPos(&g_SavedMouseX, &g_SavedMouseY)
    return g_MouseRestoreGen
}

; คืนตำแหน่งเมาส์ตาม token ที่ระบุ (ถ้ายังเป็น generation ล่าสุดอยู่) แล้วตั้ง delayed
; restore ซ้ำอีกครั้งเผื่อ Acrobat เองขยับเมาส์ช้ากว่าที่เราคืนตอนแรก (เช่น toolbar ลอย
; มี hover/animation ของตัวเองหลังรับคลิก)
MouseRestore_Commit(gen) {
    global g_MouseRestoreGen, g_SavedMouseX, g_SavedMouseY

    if (gen != g_MouseRestoreGen)
        return  ; มี action ใหม่เริ่มไปแล้วระหว่างนี้ ปล่อยให้ของใหม่จัดการแทน

    x := g_SavedMouseX, y := g_SavedMouseY
    CoordMode("Mouse", "Screen")
    MouseMove(x, y, 0)

    ; ตั้ง CoordMode ใหม่ในนี้ด้วย เพราะ SetTimer callback รันเป็นคนละ thread
    ; ไม่ได้สืบทอด CoordMode จาก thread ที่ตั้งเวลาไว้
    SetTimer(MouseRestore_DelayedFire.Bind(gen, x, y), -150)
}

MouseRestore_DelayedFire(gen, x, y) {
    global g_MouseRestoreGen

    if (gen != g_MouseRestoreGen)
        return  ; ถูก action ใหม่แทนที่ไปแล้ว ของเก่าไม่ต้องคืนอะไรแล้ว

    CoordMode("Mouse", "Screen")
    MouseMove(x, y, 0)
}

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
; ระหว่างคลิกเลย ที่ต้องบันทึก/คืนด้วย MouseRestore_Begin/Commit ด้านบนคือกันไว้เผื่อ
; Acrobat เองมีพฤติกรรม focus-follows-mouse/hover ขยับเคอร์เซอร์เอง ไม่ใช่เพราะ ControlClick

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

; ใช้ TrayTip แทน ToolTip เดิม (ToolTip โผล่ตรงตำแหน่งเมาส์เท่านั้น) - ตอนกดปุ่ม "1" สามครั้ง
; หรือ double-press SC019 ผู้ใช้กำลังใช้คีย์บอร์ด/มองที่เอกสารอยู่ เมาส์อาจอยู่คนละจุดกับที่กำลัง
; มอง ทำให้พลาดไม่เห็น ToolTip เข้าใจผิดว่าฟังก์ชันไม่ทำงานทั้งที่จริงทำงานถูกต้องแล้ว (ไม่พบบั๊ก
; ในลอจิกนับจำนวนครั้งกด/toggle เลยเมื่อตรวจโค้ด) TrayTip แจ้งในตำแหน่งคงที่มองเห็นได้แน่นอนกว่า
; แล้วหายไปเองตามที่ Windows กำหนด เหมือน TrayTip ที่ใช้อยู่แล้วทั่วทั้งโปรเจกต์
ShowToast(msg, opt := 2) {
    TrayTip("Acrobat", msg, opt)
}

ToggleAcrobatHotkeys() {
    global g_AcroHotkeysEnabled
    g_AcroHotkeysEnabled := !g_AcroHotkeysEnabled
    ShowToast("Acrobat Hotkeys: " (g_AcroHotkeysEnabled ? "ON" : "OFF"))
}

; =========================
; ปุ่ม "1" (SC002): deferred state machine
; ปุ่มนี้ทำ 2 หน้าที่ปนกัน (คลิก K1 ปกติ / triple-press = toggle เปิดปิดชุดปุ่มลัด)
; เดิมทุกครั้งที่กด (ครั้งที่ 1, 2) จะคลิก K1 ทันที แล้วค่อยมาพบทีหลังว่าเป็นครั้งที่ 3
; (triple press) ทำให้กดรัว 3 ครั้งเพื่อ toggle กลายเป็นคลิก K1 ไปก่อน 2 ครั้งโดยไม่ตั้งใจ
; และแต่ละคลิกนั้นก็ยิง MouseRestore ของตัวเอง ทับกันเองจนตำแหน่งเมาส์สุดท้ายไม่แน่นอน
;
; ตอนนี้เปลี่ยนเป็น "รอดูก่อน" (deferred): กดครั้งแรกจะยังไม่ทำอะไร แค่บันทึกตำแหน่งเมาส์
; ต้นฉบับไว้ครั้งเดียว (ครั้งถัดไปในชุดเดียวกันจะไม่บันทึกทับ) แล้วตั้งเวลารอ
;   - กดครบ 3 ครั้งภายในเวลา -> ยกเลิก timer ที่รอไว้ ทำ toggle อย่างเดียว (ไม่คลิก)
;   - หมดเวลาโดยไม่ครบ 3 (คือกดแค่ 1 หรือ 2 ครั้ง) -> ทำพฤติกรรมเดิมคือคลิก K1 "ครั้งเดียว"
;     (ของเดิมกดกี่ครั้งก็คลิกเท่านั้นครั้ง ซึ่งไม่ใช่ behavior ที่ตั้งใจ แค่เป็นผลพลอยได้
;     จากดีไซน์เดิมที่ทำงานทันทีทุกครั้งกด - ที่นี่เลยคงไว้แค่ "คลิกได้ผลลัพธ์เหมือนเดิม")
; ไม่ว่าจะจบแบบไหนก็ตาม จะคืนเมาส์กลับตำแหน่งต้นฉบับเดียวกันเสมอ
; =========================
HandleSC002Press() {
    global g_sc002Count, g_sc002Gen, g_sc002PressSeq, SC002_WINDOW_MS

    if (g_sc002Count = 0)
        g_sc002Gen := MouseRestore_Begin()  ; บันทึกตำแหน่งต้นฉบับแค่ครั้งแรกของ gesture นี้

    g_sc002Count += 1
    g_sc002PressSeq += 1
    mySeq := g_sc002PressSeq

    if (g_sc002Count >= 3) {
        g_sc002Count := 0
        ToggleAcrobatHotkeys()
        MouseRestore_Commit(g_sc002Gen)
        return
    }

    SetTimer(SC002_Timeout.Bind(mySeq), -SC002_WINDOW_MS)
}

SC002_Timeout(mySeq) {
    global g_sc002Count, g_sc002Gen, g_sc002PressSeq, g_AcroHotkeysEnabled

    if (mySeq != g_sc002PressSeq)
        return  ; มีการกดครั้งใหม่มาแทนที่ก่อนหมดเวลา ปล่อยให้ timer ของครั้งใหม่จัดการแทน

    g_sc002Count := 0

    if (g_AcroHotkeysEnabled)
        ClickMultiStep_NoMove(K1)

    MouseRestore_Commit(g_sc002Gen)
}

; =========================================================
; SC019 (ปุ่ม "P"): กด 2 ครั้งติดกันเร็ว ๆ = พิมพ์เฉพาะหน้าปัจจุบันทันที (ไม่มี Print dialog)
; กด 1 ครั้ง = พฤติกรรมเดิมของปุ่ม P ตามปกติ (พิมพ์ตัวอักษร p ถ้ามีช่องข้อความ focus อยู่ ฯลฯ)
;
; ใช้ deferred single/double press แบบเดียวกับ AppsKey/SC070/F6/F10 - กดครั้งแรกไม่ทำอะไรทันที
; รอดูก่อนว่าจะมีครั้งที่ 2 ตามมาไหม กันไม่ให้การพิมพ์ตัวอักษร p ปกติ (ครั้งเดียว) ไปเรียก
; ฟังก์ชันพิมพ์เอกสารโดยไม่ตั้งใจ และกันไม่ให้ single-press ทำงานไปก่อนตอน double-press เช่นกัน
;
; สั่งพิมพ์ผ่าน Acrobat COM (AcroExch.App -> GetActiveDoc -> PrintPages) โดยตรง ไม่ผ่าน Print
; dialog เลย เพราะระบุเลขหน้าที่จะพิมพ์ (หน้าปัจจุบันที่ AVPageView กำลังแสดงอยู่) ตรง ๆ ผ่าน
; COM ได้แม่นยำอยู่แล้ว ไม่ต้องเดา keyboard navigation ภายใน dialog ที่มองไม่เห็นและตรวจสอบไม่ได้
;
; หมายเหตุด้านความปลอดภัย: ยังมีความเสี่ยงที่พิมพ์ตัวอักษร p สองครั้งเร็ว ๆ ในช่องข้อความใด ๆ
; ของ Acrobat เอง (เช่น ช่อง search, ช่องแสดงความคิดเห็น) จะไปเข้าเงื่อนไข double-press โดยไม่ตั้งใจ
; ถ้าเกิดปัญหานี้บ่อย แนะนำให้เปลี่ยนไปใช้ปุ่มอื่นที่ชนกับการพิมพ์ข้อความทั่วไปน้อยกว่า
; =========================================================
global SC019_Pending := false
SC019_DoublePressMs := 400

SC019_RunSingle() {
    global SC019_Pending
    SC019_Pending := false
    Send("{sc019}")  ; ส่งกลับด้วย scan code ตรง ๆ ให้ modifier (Shift ฯลฯ) ทำงานตามจริงเหมือนไม่ถูกดัก
}

; พิมพ์เฉพาะหน้าปัจจุบันทันทีผ่าน Acrobat COM แล้วโชว์ toast ยืนยันสั้น ๆ (ไม่ใช้ dialog ค้าง
; เพราะผู้ใช้ต้องการให้พิมพ์ทันที - toast นี้คือ feedback เดียวที่จะได้เห็นว่าเพิ่งสั่งพิมพ์ไป)
SC019_RunDouble() {
    try {
        app := ComObjActive("AcroExch.App")
        avDoc := app.GetActiveDoc()
        pdDoc := avDoc.GetPDDoc()
        pageView := avDoc.GetAVPageView()
        curPage := pageView.GetPageNum()  ; 0-based

        pdDoc.PrintPages(curPage, curPage, 2, true, true)

        ShowToast("🖨 สั่งพิมพ์หน้า " (curPage + 1) " แล้ว")
    } catch as e {
        MsgBox("สั่งพิมพ์ไม่สำเร็จ: " e.Message)
    }
}

; =========================================================
; HOTKEYS
; =========================================================
#HotIf WinActive("ahk_group AcrobatApps")

SC002:: HandleSC002Press()

SC019:: {
    global SC019_Pending

    if (SC019_Pending) {
        SC019_Pending := false
        SetTimer(SC019_RunSingle, 0)
        SC019_RunDouble()
        return
    }

    SC019_Pending := true
    SetTimer(SC019_RunSingle, -SC019_DoublePressMs)
}

#HotIf WinActive("ahk_group AcrobatApps") && g_AcroHotkeysEnabled
SC00B:: (gen := MouseRestore_Begin(), ClickMultiStep_NoMove(K0), MouseRestore_Commit(gen))
SC003:: (gen := MouseRestore_Begin(), ClickMultiStep_NoMove(K2), MouseRestore_Commit(gen))
SC004:: (gen := MouseRestore_Begin(), ClickMultiStep_NoMove(K3), MouseRestore_Commit(gen))
SC005:: (gen := MouseRestore_Begin(), ClickSingle_NoMove(K4[1]), MouseRestore_Commit(gen))
SC006:: (gen := MouseRestore_Begin(), ClickMultiStep_NoMove(K5), MouseRestore_Commit(gen))
SC007:: (gen := MouseRestore_Begin(), ClickMultiStep_NoMove(K6), MouseRestore_Commit(gen))
SC008:: (gen := MouseRestore_Begin(), ClickMultiStep_NoMove(K7), MouseRestore_Commit(gen))
SC009:: (gen := MouseRestore_Begin(), ClickMultiStep_NoMove(K8), MouseRestore_Commit(gen))
SC00A:: (gen := MouseRestore_Begin(), ClickMultiStep_NoMove(K9), MouseRestore_Commit(gen))

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