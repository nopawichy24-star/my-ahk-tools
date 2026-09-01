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
; ค่าดีเลย์ SC002_WINDOW_MS ย้ายไปรวมไว้ที่ mod_HotkeyTiming.ahk แล้ว
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

; หมายเหตุ DPI awareness (แก้บั๊ก "เมาส์ไม่กลับที่เดิมบนจอรอง"): ฟังก์ชัน 3 ตัวนี้ต้อง
; MouseGetPos/MouseMove ด้วย per-monitor DPI awareness แบบ "จริง" ไม่งั้นบนจอที่สเกลต่างจาก
; จอหลัก พิกัดที่ได้/ที่ตั้งจะถูก DWM virtualize ผิดเพี้ยนไป (จอหลักด้วยสเกล 100% เผอิญไม่เพี้ยน
; เลยดูเหมือนใช้ได้ปกติ) - ไฟล์นี้เคยตั้ง DPI awareness ไว้แบบ global ทั้งสคริปต์มาก่อน แต่ถอด
; ออกไปแล้ว (ย้ายไปตั้งเฉพาะตอนวาดกรอบ F6 ใน mod_Hotkeys.ahk) เพราะไปกระทบค่า SHIFT_PX_UP
; ที่คำนวณจาก A_ScreenDPI ตอนโหลดสคริปต์ (ดูคอมเมนต์ด้านบนสุดของไฟล์) จึงต้องตั้งแบบ scope
; เฉพาะช่วงเรียก MouseGetPos/MouseMove ในนี้แทน - ไม่กระทบ SHIFT_PX_UP เลยเพราะฟังก์ชันพวกนี้
; ถูกเรียกตอนกด hotkey (runtime) ซึ่งเกิดขึ้นหลังสคริปต์โหลดเสร็จไปนานแล้ว คนละช่วงเวลากับตอน
; คำนวณ SHIFT_PX_UP ตอนโหลดสคริปต์โดยสิ้นเชิง
MouseRestore_SetDpiAware() {
    return DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
}

; เริ่ม "ธุรกรรม" คืนเมาส์ใหม่: บันทึกตำแหน่งปัจจุบัน + คืน token สำหรับ commit ทีหลัง
MouseRestore_Begin() {
    global g_MouseRestoreGen, g_SavedMouseX, g_SavedMouseY
    g_MouseRestoreGen += 1

    prevDpiCtx := MouseRestore_SetDpiAware()
    CoordMode("Mouse", "Screen")
    MouseGetPos(&g_SavedMouseX, &g_SavedMouseY)
    DllCall("SetThreadDpiAwarenessContext", "ptr", prevDpiCtx, "ptr")

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

    prevDpiCtx := MouseRestore_SetDpiAware()
    CoordMode("Mouse", "Screen")
    MouseMove(x, y, 0)
    DllCall("SetThreadDpiAwarenessContext", "ptr", prevDpiCtx, "ptr")

    ; ตั้ง CoordMode ใหม่ในนี้ด้วย เพราะ SetTimer callback รันเป็นคนละ thread
    ; ไม่ได้สืบทอด CoordMode จาก thread ที่ตั้งเวลาไว้
    SetTimer(MouseRestore_DelayedFire.Bind(gen, x, y), -150)
}

MouseRestore_DelayedFire(gen, x, y) {
    global g_MouseRestoreGen

    if (gen != g_MouseRestoreGen)
        return  ; ถูก action ใหม่แทนที่ไปแล้ว ของเก่าไม่ต้องคืนอะไรแล้ว

    prevDpiCtx := MouseRestore_SetDpiAware()
    CoordMode("Mouse", "Screen")
    MouseMove(x, y, 0)
    DllCall("SetThreadDpiAwarenessContext", "ptr", prevDpiCtx, "ptr")
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

; แจ้งเตือนของฟังก์ชันนี้ (กด "1" สามครั้ง) กลับไปใช้ ToolTip แบบเดิมตามที่ขอ - ไม่ใช้ ShowToast
; (TrayTip) ร่วมกับฟังก์ชันพิมพ์ของ SC019 เพราะจะกระทบ toast ของ SC019 ไปด้วยโดยไม่ตั้งใจ
; ฟังก์ชันนี้จึงมี ToolTip ของตัวเองแยกต่างหาก ไม่ใช้ ShowToast() ที่ใช้ร่วมกับฟังก์ชันอื่น
ToggleAcrobatHotkeys() {
    global g_AcroHotkeysEnabled
    g_AcroHotkeysEnabled := !g_AcroHotkeysEnabled
    msg := "Acrobat Hotkeys: " (g_AcroHotkeysEnabled ? "ON" : "OFF")
    ToolTip(msg)
    SetTimer(() => ToolTip(), -1200)
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
; SC019 (ปุ่ม "P"): แยกเป็น 2 ขั้นตอน
;   กด 3 ครั้งติดกันเร็ว ๆ = สลับสถานะ g_SC019_PrintArmed ON/OFF (toggle - ครั้งนี้ OFF->ON
;     ครั้งหน้า ON->OFF สลับกลับไปมา) เท่านั้น - ไม่พิมพ์ทันที และสถานะจะค้างอยู่ตามที่ตั้งไว้
;     ไม่ reset เอง แม้พิมพ์ไปแล้วก็ตาม (เริ่มที่ OFF เสมอตอนเปิดสคริปต์ใหม่ เพราะ global ตัวนี้
;     เริ่มที่ false)
;   กด 2 ครั้งติดกันเร็ว ๆ = เปิดหน้าต่าง Print ผ่าน Ctrl+P แล้วเลือก "พิมพ์เฉพาะหน้าปัจจุบัน"
;     ให้อัตโนมัติด้วย Alt+U (ดูรายละเอียดที่ SC019_DoPrint) แล้วหยุด - ไม่กด Enter/คลิก Print
;     ให้เอง ผู้ใช้กดยืนยันพิมพ์เองที่หน้าต่างนั้น ทำได้ก็ต่อเมื่อ g_SC019_PrintArmed เป็น ON
;     (true) อยู่ตอนนั้นเท่านั้น ถ้าสถานะเป็น OFF การกด 2 ครั้งจะไม่เปิด Print dialog เลย - ทำ
;     เหมือนพิมพ์ตัวอักษร p ปกติ 2 ตัวแทน
;   กด 1 ครั้งแล้วหมดเวลา = พฤติกรรมเดิมของปุ่ม P ตามปกติ (พิมพ์ตัวอักษร p)
;
; ใช้ state machine นับจำนวนครั้งกดแบบเดียวกับ SC002 (HandleSC002Press/SC002_Timeout) - ไม่ทำ
; อะไรทันทีตอนกดครั้งที่ 1 หรือ 2 เลย ต้องรอดูให้ครบ (หมดเวลา หรือกดครบ 3) ก่อนเสมอ กันไม่ให้
; ครั้งที่ 3 ถูกตีความว่าเป็นครั้งที่ 2 ไปก่อนแล้วโดยไม่ตั้งใจ
;
; สั่งเปิดหน้าต่าง Print ผ่าน Ctrl+P แล้ว Alt+U เลือก "พิมพ์เฉพาะหน้าปัจจุบัน" ให้เท่านั้น -
; ไม่กด Enter และไม่คลิกปุ่ม Print/印刷 ให้อัตโนมัติเด็ดขาดตามที่ผู้ใช้ระบุ ผู้ใช้จะเป็นคนกด
; ยืนยันพิมพ์เองที่หน้าต่าง Print โดยตรง (ไม่ใช้ COM/AcroExch.App แบบที่เคยลองมาก่อน เพราะ
; Adobe Reader ตัวฟรีบล็อกปิดกั้น COM automation ของโปรแกรมภายนอกไว้ - ยืนยันแล้วว่าเป็น
; สาเหตุจริงของ error 0x800401E3 ที่เจอ)
; =========================================================
global SC019_Count := 0
global SC019_PressSeq := 0
global g_SC019_PrintArmed := false
; ค่าดีเลย์ SC019_WINDOW_MS ย้ายไปรวมไว้ที่ mod_HotkeyTiming.ahk แล้ว

SC019_Timeout(mySeq) {
    global SC019_Count, SC019_PressSeq, g_SC019_PrintArmed

    if (mySeq != SC019_PressSeq)
        return  ; มีการกดครั้งใหม่มาแทนที่ก่อนหมดเวลา ปล่อยให้ timer ของครั้งใหม่จัดการแทน

    n := SC019_Count
    SC019_Count := 0

    if (n = 2 && g_SC019_PrintArmed) {
        SC019_DoPrint()
        return
    }

    ; ไม่ใช่กรณีพิมพ์ (กด 1 ครั้ง หรือกด 2 ครั้งแต่ยังไม่เปิดใช้งานคำสั่งพิมพ์) - คืนพฤติกรรมเดิม
    ; ของปุ่ม p ตามจำนวนครั้งที่กดจริง ด้วย scan code ตรง ๆ ให้ modifier (Shift ฯลฯ) ทำงานตามจริง
    ; เหมือนไม่เคยถูกดักเลย
    Loop n
        Send("{sc019}")
}

; พิมพ์เฉพาะหน้าปัจจุบัน ผ่านคีย์ลัด Ctrl+P + Alt+U (ไม่ใช่ COM แบบเดิม) เพราะ Adobe Reader
; ตัวฟรี (ยืนยันแล้วว่าผู้ใช้ใช้ตัวนี้อยู่) บล็อกปิดกั้น COM automation แบบ AcroExch.App/PrintPages
; ไว้ ทำให้วิธีเดิมใช้ไม่ได้เลยกับ Reader - Ctrl+P เป็นคีย์ลัดมาตรฐานที่ Reader รองรับแน่นอน
; ส่วน Alt+U (เลือก "พิมพ์เฉพาะหน้าปัจจุบัน") ผู้ใช้ตรวจสอบเองแล้วว่าถูกต้องกับหน้าต่าง Print
; ของ Reader เวอร์ชันที่ใช้อยู่จริง ไม่ใช่การเดา
;
; ROOT CAUSE ของปัญหา "Alt+U ไม่ถูกส่งหลัง Ctrl+P" (รอบก่อน): โค้ดตอนนั้นรอหน้าต่าง Print ด้วย
; WinWait("ahk_class #32770") ซึ่งสมมติ class ผิด ทำให้ timeout เงียบ ๆ แล้ว return ก่อนถึงบรรทัด
; ส่ง Alt+U เลยด้วยซ้ำ - แก้ไปแล้วโดยเปลี่ยนมาตรวจจับ "หน้าต่างใหม่ที่เพิ่งปรากฏ" ด้วยการ diff
; รายชื่อหน้าต่างก่อน/หลังกด Ctrl+P แทนการเดา class (เทคนิคเดียวกับ OpenPdfInAcrobat)
;
; ผู้ใช้ทดสอบจริงแล้วยืนยันว่า Ctrl+P ทำงาน (หน้าต่าง/แผง Print เปิดขึ้นจริง) แต่ Alt+U ยังคง
; "ไม่เกิดผล" แม้แก้ปัญหา class ไปแล้ว - นั่นแปลว่าการ diff หา "หน้าต่างใหม่" ยังมีจุดอ่อนที่ทำให้
; ส่ง WM_SYSCHAR ไปผิดเป้าหมาย ซึ่งมีได้ 2 กรณี:
;   1) diff เจอหน้าต่างใหม่ผิดตัว (เช่น หน้าต่าง/tooltip อื่นของ Reader ที่เกิดขึ้นพอดีในช่วงเวลา
;      เดียวกันโดยบังเอิญ ไม่ใช่ Print dialog จริง) - ส่ง WM_SYSCHAR ไปแล้วไม่มีผลเพราะไปคนละ
;      หน้าต่างกับที่ต้องการ
;   2) Reader บางเวอร์ชันแสดงตัวเลือก Print เป็นแผงในหน้าต่างเดิม (in-place panel) ไม่ได้เปิด
;      หน้าต่าง popup ใหม่เลย - กรณีนี้ diff จะไม่เจอ "หน้าต่างใหม่" อะไรเลย ทำให้ dlgHwnd เป็น 0
;      ตลอด (เดิมจะขึ้น MsgBox แจ้ง error แต่ถ้าเกิดกรณีนี้ผู้ใช้น่าจะเห็น MsgBox ด้วย)
; แก้โดยเปลี่ยนวิธีเลือกเป้าหมายใหม่ทั้งหมด: ไม่เชื่อผลจาก diff เพียงอย่างเดียวอีกต่อไป แต่ใช้
; foreground window ปัจจุบัน (WinExist("A")) ณ ตอนกำลังจะส่ง Alt+U เป็นตัวตัดสินใจสุดท้ายเสมอ
; เพราะไม่ว่า Print UI จะเป็นหน้าต่าง popup ใหม่หรือแผงในหน้าต่างเดิม คีย์บอร์ดจริงก็จะวิ่งไปที่
; foreground window เท่านั้นอยู่ดี - ผลจาก diff ใช้แค่เป็นข้อมูลรอไทม์เอาต์/log เท่านั้น ไม่ใช้
; ตัดสินเป้าหมายโดยตรงอีกต่อไป และเพิ่มการหา control ที่ keyboard focus อยู่จริงภายใน foreground
; window นั้นด้วย (ControlGetFocus/ControlGetHwnd) แล้วส่ง WM_SYSCHAR ซ้ำไปที่ control นั้นด้วย
; เพราะ WM_SYSCHAR จากการกดจริงจะมาพร้อม hwnd ของ control ที่ focus อยู่ ไม่ใช่ตัวหน้าต่าง dialog
; เอง เสมอไป - ส่งทั้งสองเป้าหมายเผื่อกรณี IsDialogMessage ของแต่ละ implementation ต้องการรูปแบบ
; ต่างกัน
;
; (ยืนยันแล้วว่า Alt+U ทำงานถูกต้องหลัง fix นี้ - เคยมี logging ไฟล์ sc019_print_debug.log ไว้
; ช่วย debug ปัญหานี้ตอนยังไม่ยืนยันผล ตอนนี้ถอดออกแล้วเพราะแก้เสร็จและยืนยันผลแล้ว ไม่จำเป็นต้อง
; เขียน log ทุกครั้งที่พิมพ์อีกต่อไป)
;
; ทำไมยังส่ง Alt+U ด้วย PostMessage(WM_SYSCHAR) แทน Send("!u") ตรง ๆ: Send("!u") จำลองการกดแป้น
; จริงตามตำแหน่ง แล้วให้ Windows แปลเป็นตัวอักษรตาม keyboard layout ที่ active อยู่ตอนนั้น - ถ้า
; เป็นภาษาไทย แป้นตำแหน่งเดียวกันจะแปลเป็นอักษรไทยแทน 'u' ทำให้ dialog จับ mnemonic ไม่ตรง (บั๊ก
; ที่เคยแก้ไปแล้วก่อนหน้านี้ จึงไม่ย้อนกลับไปใช้ Send("!u") อีก) ส่ง WM_SYSCHAR ตรง ๆ พร้อมรหัส
; ตัวอักษร 'U' (0x55) ในตัวเองเลย ข้ามขั้นตอนแปลผ่าน physical keyboard layout ไปทั้งหมด จึงได้ผล
; เหมือนกันไม่ว่าจะตั้ง layout เป็นภาษาไหน - ปัญหารอบนี้อยู่ที่ "เป้าหมาย" ที่ส่งไป ไม่ใช่กลไกการ
; ส่งเอง จึงแก้เฉพาะการเลือกเป้าหมายโดยไม่เปลี่ยนกลไกนี้
;
; ส่วน Ctrl+P ใช้ Send แบบแยก step กด/ปล่อยชัดเจน (Ctrl down -> p down -> p up -> Ctrl up) - ปลอดภัย
; กับทุก keyboard layout เพราะ Ctrl+ตัวอักษร เป็น accelerator ที่ Windows จับคู่ด้วย virtual-key
; code ตรง ๆ ไม่ใช่ mnemonic ที่จับคู่ด้วยตัวอักษรที่แปลผ่าน layout แบบ Alt+U - เพิ่มการตรวจสอบด้วย
; GetKeyState ว่า Ctrl ถูกปล่อยจริงตามฟิสิคัลก่อนไปขั้นต่อไป (ไม่ใช่แค่ Sleep เฉย ๆ) และก่อน/หลัง
; ทำงานทั้งหมดจะบังคับปล่อย Ctrl/Shift/Alt ทุกตัว (ทั้งซ้าย/ขวา) กันไว้เผื่อ modifier ค้างจากรอบ
; ก่อนหรือจาก error ระหว่างทาง (ครอบด้วย try/finally ให้ปล่อย modifier แน่นอนไม่ว่าจะเกิด
; exception หรือไม่)
SC019_DoPrint() {
    ; กันไว้ก่อนว่าไม่มี modifier ค้างจากรอบก่อนหน้า (เช่น เคยเกิด error/interrupt กลางทางมาก่อน)
    Send("{LCtrl up}{RCtrl up}{LShift up}{RShift up}{LAlt up}{RAlt up}")

    try {
        ; จดหน้าต่างทั้งหมดของ Reader/Acrobat ที่มีอยู่ก่อนกด Ctrl+P ไว้ก่อน - ใช้แค่ประกอบการรอ
        ; ให้ dialog/panel ใหม่เปิดเสร็จ ไม่ใช้ตัดสินเป้าหมายส่ง Alt+U โดยตรง (ดู comment ด้านบน
        ; ฟังก์ชันสำหรับเหตุผลเต็ม)
        existing := WinGetList("ahk_group AcrobatApps")

        Send("{Ctrl down}")
        Sleep(15)
        Send("{p down}")
        Sleep(15)
        Send("{p up}")
        Sleep(15)
        Send("{Ctrl up}")

        ; ตรวจสอบว่า Ctrl ถูกปล่อยจริงตามฟิสิคัลก่อนไปขั้นต่อไป (ไม่ใช่แค่เชื่อว่า Send("{Ctrl up}") พอ)
        Loop 10 {
            if !GetKeyState("Ctrl", "P")
                break
            Send("{LCtrl up}{RCtrl up}")
            Sleep(20)
        }

        ; รอหน้าต่างใหม่ (ถ้ามี) เพื่อให้เวลา dialog/panel render เสร็จก่อนค่อยส่ง Alt+U ต่อ
        dlgHwnd := 0
        start := A_TickCount
        while (A_TickCount - start < 4000) {
            for hwnd in WinGetList("ahk_group AcrobatApps") {
                isOld := false
                for old in existing {
                    if (old = hwnd) {
                        isOld := true
                        break
                    }
                }
                if !isOld {
                    dlgHwnd := hwnd
                    break
                }
            }
            if dlgHwnd
                break
            Sleep(30)
        }

        if dlgHwnd
            WinWaitActive("ahk_id " dlgHwnd, , 2)

        Sleep(150)  ; กันกรณี control ภายในยัง render ไม่เสร็จแม้หน้าต่าง active แล้ว

        ; เป้าหมายจริงที่ใช้ส่ง Alt+U เสมอ: foreground window ณ ตอนนี้ ไม่ใช่ผลจาก diff โดยตรง
        sendTarget := WinExist("A")

        if !sendTarget {
            MsgBox("เปิดหน้าต่าง Print ไม่สำเร็จ (ไม่พบหน้าต่างเป้าหมายเลย)")
            return
        }

        ; หา control ที่ keyboard focus อยู่จริงภายใน target window เพราะ WM_SYSCHAR จากการกด
        ; จริงจะมาพร้อม hwnd ของ control ที่ focus อยู่ ไม่ใช่ตัวหน้าต่างเองเสมอไป
        focusedCtrl := ""
        try
            focusedCtrl := ControlGetFocus("ahk_id " sendTarget)

        focusedHwnd := 0
        if focusedCtrl {
            try
                focusedHwnd := ControlGetHwnd(focusedCtrl, "ahk_id " sendTarget)
        }

        PostMessage(0x106, 0x55, 0, , sendTarget)

        if (focusedHwnd && focusedHwnd != sendTarget) {
            Sleep(30)
            PostMessage(0x106, 0x55, 0, , focusedHwnd)
        }

        ; หยุดอยู่ตรงนี้ตามที่ผู้ใช้ต้องการ - ห้ามกด Enter/คลิกปุ่ม Print ให้อัตโนมัติเด็ดขาด ผู้ใช้จะ
        ; กดยืนยันพิมพ์เองที่หน้าต่าง Print โดยตรง จึงไม่มี toast "พิมพ์แล้ว" ตรงนี้ด้วย เพราะยังไม่ได้
        ; พิมพ์จริง ๆ (รอผู้ใช้กด Print/Enter เองก่อน)
    } finally {
        Send("{LCtrl up}{RCtrl up}{LShift up}{RShift up}{LAlt up}{RAlt up}")
    }
}

; =========================================================
; HOTKEYS
; =========================================================
#HotIf WinActive("ahk_group AcrobatApps")

SC002:: HandleSC002Press()

SC019:: {
    global SC019_Count, SC019_PressSeq, g_SC019_PrintArmed

    SC019_Count += 1
    SC019_PressSeq += 1
    mySeq := SC019_PressSeq

    if (SC019_Count >= 3) {
        SC019_Count := 0
        g_SC019_PrintArmed := !g_SC019_PrintArmed  ; สลับ ON/OFF ทุกครั้งที่กดครบ 3 (ไม่ใช่ตั้ง true เสมอแบบเดิม)
        ShowToast(g_SC019_PrintArmed ? "印刷機能：ON" : "印刷機能：OFF")
        return
    }

    SetTimer(SC019_Timeout.Bind(mySeq), -SC019_WINDOW_MS)
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