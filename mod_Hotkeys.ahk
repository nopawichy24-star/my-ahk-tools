; mod_Hotkeys.ahk

Hotkeys_Init() {
    ; ตอนนี้ยังไม่มีอะไรต้อง init
    ; แต่ถ้าอนาคตอยากเพิ่ม config ก็ใส่ในนี้ได้
}

;----------------------------------------
; Ins: Toggle Chrome (show / hide)
;----------------------------------------
Ins:: {
    chrome := "ahk_exe chrome.exe"

    if !WinExist(chrome) {
        Run "chrome.exe"
        return
    }

    hwnd := WinExist(chrome)
    state := WinGetMinMax("ahk_id " hwnd)

    if (state = -1) {
        WinRestore "ahk_id " hwnd
        WinActivate "ahk_id " hwnd
    } else {
        WinMinimize "ahk_id " hwnd
    }
}

; === Page Up ===
PgUp::WinMaximize("A")

; === Page Down ===
PgDn::WinRestore("A")

; === F1–F? ===
F1::Send("^x")
F2::Send("^c")
F3::Send("^v")
F4::Send("^z")
; F5 = Save แต่ต้องกด 2 ครั้งติดกัน (ภายใน 400ms) ถึงจะ save จริง กันกดโดนโดยไม่ตั้งใจ
F5PressCount := 0
F5:: {
    global F5PressCount

    F5PressCount++

    if (F5PressCount >= 2) {
        F5PressCount := 0
        Send("^s")
    } else {
        SetTimer(() => F5PressCount := 0, -400)
    }
}
; F6 = คำสั่งเดิม (Win+Shift+S)
; F6 กด 2 ครั้งติดกันเร็ว ๆ = ยกเลิกคำสั่งเดิม แล้วเข้าโหมด OCR แทน
;
; ปรับความเร็วของดีเลย์ก่อนกดครั้งเดียวจะทำงานจริง (300ms -> 150ms) ตามที่ขอ - เทียบกับปุ่มอื่น
; ในโปรเจกต์ที่มี 1 ครั้ง/2 ครั้งในปุ่มเดียวกัน แบ่งเป็น 2 กลุ่มตามกลไก:
;   - กลุ่มที่ "ยิงทันทีตอนกดครั้งที่ 2" (เหมือน F6 นี้เอง): F10 ใช้ 350ms
;   - กลุ่มที่ต้องรอดูให้ครบก่อนเสมอเพราะแยกแยะได้มากกว่า 2 ระดับ (deferred count+timeout ทั้งหมด
;     ไม่ใช่แค่ครั้งเดียว): SC019/SC070 ใช้ 400ms, SC002 ใช้ 650ms, J/M (text expander) ใช้ 100ms
;     (ปรับให้เร็วสุดเพราะเป็นตัวอักษรที่พิมพ์บ่อยมากทุกวัน ไม่เหมือน F6 ที่กดเฉพาะตอนตั้งใจ)
; F6 อยู่ในกลุ่มแรก (ยิงทันทีตอนกด 2 ครั้ง ไม่ต้องรอ) ดีเลย์ 300ms เดิมจึงกระทบแค่ตอนกดครั้งเดียว
; เท่านั้น (ตอนตั้งใจใช้ Win+Shift+S ปกติ ไม่ได้ต้องการ OCR) ลดเหลือ 150ms ให้กดครั้งเดียวขึ้นเร็ว
; ขึ้นชัดเจน ยังเหลือเวลาพอสำหรับกดครั้งที่ 2 ตามมาทันสำหรับการ double-tap ที่ตั้งใจกดเร็ว ๆ
; (ต่ำกว่านี้เสี่ยงกดครั้งที่ 2 ไม่ทันสำหรับคนกดไม่ไวมาก)
global F6_Pending := false
F6_DoublePressMs := 150

F6:: {
    global F6_Pending

    if (F6_Pending) {
        ; กดครั้งที่ 2 ทันเวลา -> ยกเลิกคำสั่งเดิมที่รออยู่ แล้วเข้าโหมด OCR
        F6_Pending := false
        SetTimer(F6_RunOriginal, 0)
        F6_StartOCR()
        return
    }

    ; กดครั้งแรก -> รอดูว่าจะมีครั้งที่ 2 ตามมาไหม ก่อนค่อยทำคำสั่งเดิม
    F6_Pending := true
    SetTimer(F6_RunOriginal, -F6_DoublePressMs)
}

F6_RunOriginal() {
    global F6_Pending
    F6_Pending := false
    Send("#+s")
}

; ===============================
; F6 double-press: OCR พื้นที่ที่ลากเลือกบนจอ (ญี่ปุ่น/อังกฤษ)
; แคปเจอร์เองในหน่วยความจำ (OCR.FromRect) ไม่แตะ Clipboard เลยระหว่างจับภาพ
; -> ไม่มีรูปภาพหลงเหลือใน Clipboard/Clipboard History เลย (ต่างจากกด F6 ครั้งเดียวที่ยังเก็บภาพเหมือนเดิม)
;
; หมายเหตุเรื่องหลายจอ/DPI ไม่เท่ากัน:
; - shield และกรอบไกด์แยกเป็น "1 หน้าต่างต่อ 1 จอจริง" เสมอ (ไม่มีหน้าต่างไหนคาบเกี่ยว 2 จอ)
;   กัน Windows auto-scale หน้าต่างผิดตอนคาบเกี่ยวจอที่ DPI/scale ไม่เท่ากัน รองรับพิกัดติดลบ
;   ได้เองอยู่แล้วเพราะใช้เลขจริงเทียบ Max/Min ตลอด ไม่มีจุดไหน assume จอหลักอยู่ที่ (0,0)
; - เดิมเคยลองวาดกรอบด้วย XOR ตรงบน screen DC (GetDC(0)) แต่พบว่าพอลากยาว/ข้ามรอยต่อจอ
;   กรอบเพี้ยนเป็นทาง ๆ ได้ เพราะ DWM (compositor) วาดทับพื้นที่นั้นแทรกระหว่างที่กรอบยังค้างอยู่
; - เดิมเคยลองหน้าต่างกรอบแบบ layered+transparent (WinSetTransparent) แต่กลับกลายเป็นบั๊ก
;   ใหม่: ลืมเรียก WinSetTransparent ตอนสร้างบางจุด ทำให้กรอบมองไม่เห็นเป็นพัก ๆ - จริง ๆ
;   กรอบนี้ไม่จำเป็นต้องโปร่งใสเลย แค่ "กลวงตรงกลาง" ด้วย SetWindowRgn ก็พอ เลยตัด
;   layered/transparency ออกทั้งหมด ให้เป็นหน้าต่างสีเทาธรรมดา ลดจุดที่จะบั๊กได้
; - shield (ดักคลิก มองไม่เห็น) ยังคงโปร่งใสเหมือนเดิม แต่แยกเป็นคนละชุด Gui object
;   กับกรอบ (frames) อย่างชัดเจน ไม่ปนกัน
; ===============================
global F6_OCRBusy := false

F6_StartOCR() {
    global F6_OCRBusy

    ; กันเรียกซ้อน ถ้ากด F6 double-press อีกรอบระหว่างที่ยังลากเลือกพื้นที่ค้างอยู่
    if F6_OCRBusy
        return
    F6_OCRBusy := true

    ; ต้องการ per-monitor DPI awareness แบบ "จริง" เฉพาะช่วงสร้าง/ขยับกรอบ F6 เท่านั้น (กันกรอบ
    ; เพี้ยนบนจอที่สเกลต่างจากจอหลัก) - ตั้งแบบ scope เฉพาะฟังก์ชันนี้ (SetThreadDpiAwarenessContext
    ; คืนค่า context เดิมกลับมาให้เลย) แล้วคืนค่าเดิมใน finally เสมอ เพราะถ้าตั้งไว้แบบ global
    ; ทั้งสคริปต์ (เคยทำมาก่อน) จะทำให้ A_ScreenDPI ที่ mod_AcrobatAVPopupHotkeys.ahk ใช้คำนวณ
    ; offset ปุ่มคลิก Acrobat (SHIFT_PX_UP) ตอนโหลดสคริปต์เปลี่ยนค่าไปจากที่ผู้ใช้ปรับเทียบไว้
    prevDpiCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

    CoordMode("Mouse", "Screen")
    CoordMode("ToolTip", "Screen")

    monitors := []
    shields := []
    frames := []
    frameVisible := []

    try {
        Loop MonitorGetCount() {
            MonitorGet(A_Index, &mL, &mT, &mR, &mB)
            monitors.Push({l: mL, t: mT, r: mR, b: mB})
        }

        ; shield: 1 หน้าต่างต่อจอ ดักคลิก/ลากทั้งหมดไว้เอง ไม่ให้หลุดไปโดนหน้าต่างเบื้องหลัง
        ; (มองไม่เห็น แต่ยังรับคลิกอยู่ - ไม่ใช่ click-through) ใช้ layered+transparent ตามเดิม
        for m in monitors {
            sg := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08080000")
            sg.BackColor := "000000"
            sg.Show("x" m.l " y" m.t " w" (m.r - m.l) " h" (m.b - m.t) " NoActivate")
            WinSetTransparent(1, sg)
            shields.Push(sg)
        }

        ; frame: หน้าต่างกรอบไกด์สีเทาธรรมดา 1 อันต่อจอ (ไม่ใช้ layered/transparency เลย
        ; ไม่จำเป็นสำหรับกรอบกลวง - ลดจุดที่จะพลาดจนกรอบมองไม่เห็น) NOACTIVATE เฉย ๆ กันแย่ง focus
        for m in monitors {
            fw := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
            fw.BackColor := "808080"
            fw.Show("x0 y0 w1 h1 NoActivate")
            fw.Hide()
            frames.Push(fw)
            frameVisible.Push(false)
        }

        ; รอผู้ใช้เริ่มลากเมาส์ (สูงสุด 8 วิ, กด Esc ยกเลิกได้)
        ToolTip("ลากเลือกพื้นที่ที่ต้องการ OCR (Esc = ยกเลิก)")
        waitStart := A_TickCount
        started := false
        while (A_TickCount - waitStart < 8000) {
            if GetKeyState("Escape", "P")
                break
            if GetKeyState("LButton", "P") {
                started := true
                break
            }
            Sleep(10)
        }
        ToolTip()

        if !started {
            TrayTip("OCR", "ยกเลิก (ไม่มีการลากเลือก)", 2)
            return
        }

        MouseGetPos(&x1, &y1)

        hasFrame := false
        lastX := 0, lastY := 0, lastW := 0, lastH := 0

        cancelled := false
        while GetKeyState("LButton", "P") {
            if GetKeyState("Escape", "P") {
                cancelled := true
                break
            }
            MouseGetPos(&cx, &cy)
            x := Min(x1, cx), y := Min(y1, cy)
            w := Max(Abs(cx - x1), 2), h := Max(Abs(cy - y1), 2)

            if (!hasFrame || x != lastX || y != lastY || w != lastW || h != lastH) {
                F6_UpdateFrames(monitors, frames, frameVisible, x, y, w, h, 2)
                hasFrame := true
                lastX := x, lastY := y, lastW := w, lastH := h
            }
            Sleep(8)
        }

        MouseGetPos(&x2, &y2)

        ; ปล่อยเมาส์/ยกเลิกแล้ว - ซ่อนกรอบทุกจอทันที (ใช้ .Hide() จริง ไม่ใช่ Show("Hide"))
        for fw in frames
            fw.Hide()

        if (cancelled) {
            TrayTip("OCR", "ยกเลิกแล้ว", 2)
            return
        }

        x := Min(x1, x2), y := Min(y1, y2)
        w := Abs(x2 - x1), h := Abs(y2 - y1)

        if (w < 6 || h < 6) {
            TrayTip("OCR", "พื้นที่ที่เลือกเล็กเกินไป ลองใหม่อีกครั้ง", 2)
            return
        }

        ; กันพื้นที่หลุดขอบจอรวม (เผื่อกรณีขอบจอสุดของหลายจอไม่เท่ากัน)
        vLeft := SysGet(76), vTop := SysGet(77)
        vRight := vLeft + SysGet(78), vBottom := vTop + SysGet(79)
        x := Max(x, vLeft), y := Max(y, vTop)
        w := Min(w, vRight - x), h := Min(h, vBottom - y)

        ; ปิด shield/frame ทั้งหมดก่อน capture กันมันติดไปในภาพ
        for sg in shields
            sg.Destroy()
        shields := []
        for fw in frames
            fw.Destroy()
        frames := []

        Sleep(100)

        result := OCR.FromRect(x, y, w, h, {lang: "ja-JP", scale: 2})

        try
            text := F6_BuildOcrText(result)
        catch
            text := result.Text  ; เผื่อโครงสร้างผลลัพธ์ไม่ตรงที่คาด ให้ fallback ไปใช้ของ library ตรง ๆ

        text := Trim(text)

        if (text = "") {
            TrayTip("OCR", "ไม่พบข้อความในพื้นที่ที่เลือก", 3)
            return
        }

        A_Clipboard := text
        TrayTip("OCR เสร็จแล้ว", "ข้อความอยู่ใน Clipboard แล้ว กด Ctrl+V เพื่อวางเอง", 2)

    } catch as e {
        MsgBox("OCR ไม่สำเร็จ: " e.Message)
    } finally {
        ; คืน DPI awareness context กลับเป็นของเดิมเสมอ ไม่ว่า F6 จะจบแบบไหน (สำเร็จ/ยกเลิก/error)
        ; กันไม่ให้ค่าที่ตั้งไว้ระหว่างวาดกรอบหลุดรอดไปกระทบโค้ดส่วนอื่นของสคริปต์ที่รันทีหลัง
        DllCall("SetThreadDpiAwarenessContext", "ptr", prevDpiCtx, "ptr")
        ToolTip()
        for sg in shields
            sg.Destroy()
        for fw in frames
            fw.Destroy()
        F6_OCRBusy := false
    }
}

; ต่อข้อความ OCR เองจาก Lines/Words แทนการใช้ result.Text ตรง ๆ
; เพราะ result.Text ของ library เว้นวรรคระหว่างทุกคำเท่ากันหมด ทำให้ภาษาญี่ปุ่น/คำที่ควร
; ติดกันถูกแยกออกจากกันเป็นระยะ ๆ ผิดธรรมชาติ ฟังก์ชันนี้เว้นวรรคเฉพาะตอนที่ระยะห่างจริง ๆ
; ระหว่างคำ (ตามพิกัด x) กว้างกว่าเกณฑ์เทียบกับความสูงตัวอักษรเท่านั้น
F6_BuildOcrText(result) {
    outLines := []

    for line in result.Lines {
        text := ""
        prevRight := 0
        prevH := 0

        for i, w in line.Words {
            if (i > 1) {
                gap := w.x - prevRight
                if (gap > prevH * 0.35)
                    text .= " "
            }
            text .= w.Text
            prevRight := w.x + w.w
            prevH := w.h
        }

        outLines.Push(text)
    }

    out := ""
    for i, t in outLines
        out .= (i = 1 ? "" : "`n") t

    return out
}

; อัปเดตกรอบไกด์ทุกจอให้ตรงกับ selection (X,Y,W,H เป็นพิกัดจอรวม) แบ่งเป็นท่อนตามจอ
; แต่ละท่อน "กลวงตรงกลาง" (เส้นขอบหนา T พิกเซล) และ clip ให้อยู่ในจอนั้นจอเดียวเท่านั้น
F6_UpdateFrames(monitors, frames, frameVisible, X, Y, W, H, T) {
    innerX1 := X + T, innerY1 := Y + T
    innerX2 := X + W - T, innerY2 := Y + H - T
    hasInner := (innerX2 > innerX1 && innerY2 > innerY1)

    for i, m in monitors {
        ox1 := Max(X, m.l), oy1 := Max(Y, m.t)
        ox2 := Min(X + W, m.r), oy2 := Min(Y + H, m.b)

        if (ox2 <= ox1 || oy2 <= oy1) {
            ; selection ออกจากจอนี้แล้ว (ไม่มีส่วนทับเหลืออยู่เลย) - ซ่อนกรอบของจอนี้
            if frameVisible[i] {
                frames[i].Hide()
                frameVisible[i] := false
            }
            continue
        }

        localW := ox2 - ox1, localH := oy2 - oy1
        outerRgn := DllCall("CreateRectRgn", "int", 0, "int", 0, "int", localW, "int", localH, "ptr")

        if hasInner {
            ix1 := Max(innerX1, ox1), iy1 := Max(innerY1, oy1)
            ix2 := Min(innerX2, ox2), iy2 := Min(innerY2, oy2)

            if (ix2 > ix1 && iy2 > iy1) {
                innerRgn := DllCall("CreateRectRgn", "int", ix1 - ox1, "int", iy1 - oy1, "int", ix2 - ox1, "int", iy2 - oy1, "ptr")
                DllCall("CombineRgn", "ptr", outerRgn, "ptr", outerRgn, "ptr", innerRgn, "int", 4)  ; RGN_DIFF
                DllCall("DeleteObject", "ptr", innerRgn)
            }
        }

        WinMove(ox1, oy1, localW, localH, frames[i])
        DllCall("SetWindowRgn", "ptr", frames[i].Hwnd, "ptr", outerRgn, "int", true)

        if !frameVisible[i] {
            frames[i].Show("NoActivate")
            frameVisible[i] := true
        }
    }
}
F7::Send "{Delete}"
F8::WinClose("A")
F9::Send("# ")
; F10 = คำสั่งเดิม (Lock Workstation)
; F10 กด 2 ครั้งติดกันเร็ว ๆ = ยกเลิกคำสั่งเดิม แล้วตั้งค่า Registry disablecad = 1 แทน
global F10_Pending := false
F10_DoublePressMs := 350

F10:: {
    global F10_Pending

    if (F10_Pending) {
        ; กดครั้งที่ 2 ทันเวลา -> ยกเลิกคำสั่งเดิมที่รออยู่ แล้วไปแก้ Registry แทน
        F10_Pending := false
        SetTimer(F10_RunOriginal, 0)
        F10_SetDisableCad()
        return
    }

    ; กดครั้งแรก -> รอดูว่าจะมีครั้งที่ 2 ตามมาไหม ก่อนค่อยทำคำสั่งเดิม
    F10_Pending := true
    SetTimer(F10_RunOriginal, -F10_DoublePressMs)
}

F10_RunOriginal() {
    global F10_Pending
    F10_Pending := false
    DllCall("LockWorkStation")
}

; ===============================
; F10 double-press: ตั้งค่า Registry HKLM...\Policies\System!disablecad = 1
; ต้องใช้สิทธิ์ Administrator (HKLM) จึงรัน reg.exe แบบ RunAs แยกโปรเซส
; เพื่อไม่ต้องรันทั้งสคริปต์เป็น Admin (ถ้ารันทั้งสคริปต์เป็น Admin จะเข้าไปยุ่งกับ
; หน้าต่างที่ไม่ใช่ Admin ของโปรแกรมอื่น เช่น Excel/Chrome ไม่ได้ เพราะโดน UIPI บล็อก)
; ทุกครั้งที่ double-press จะมี prompt UAC ขึ้นมาให้กดยืนยัน 1 ครั้ง
; ===============================
F10_SetDisableCad() {
    cmd := A_ComSpec ' /c reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v disablecad /t REG_DWORD /d 1 /f'

    try {
        exitCode := RunWait("*RunAs " cmd, , "Hide")

        if (exitCode = 0)
            TrayTip("Registry", "ตั้งค่า disablecad = 1 สำเร็จ", 2)
        else
            MsgBox("แก้ Registry ไม่สำเร็จ (exit code " exitCode ")")
    } catch as e {
        MsgBox("แก้ Registry ไม่สำเร็จ (อาจถูกยกเลิก UAC หรือไม่มีสิทธิ์ Administrator)`n`n" e.Message)
    }
}

F11:: {
    static lastWin := 0

    if (lastWin = 0) {
        hwnd := WinExist("A")
        if !hwnd
            return

        lastWin := hwnd
        WinMinimize "ahk_id " hwnd
        return
    }

    if WinExist("ahk_id " lastWin) {
        WinRestore  "ahk_id " lastWin
        WinActivate "ahk_id " lastWin
    }
    lastWin := 0
}

; ===== Globals =====
CloseActive := false
CloseRemain := 0
CloseGui := 0

; ===== Hotkey =====
F12:: {
    global CloseActive, CloseRemain, CloseGui

    ; กดซ้ำระหว่างนับ = ยกเลิก
    if (CloseActive) {
        CloseCancel()
        return
    }

    ; เริ่มทันที
    CloseActive := true
    CloseRemain := 5

    ; GUI แจ้งเตือน
    CloseGui := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", "Close All Programs")
    CloseGui.SetFont("s11")
    CloseGui.AddText("w380", "⚠️ จะปิดทุกโปรแกรมใน 5 วินาที")
    CloseGui.AddText("w380", "กด Cancel หรือกด F12 ซ้ำเพื่อยกเลิก")
    btn := CloseGui.AddButton("w120 Default", "Cancel")
    btn.OnEvent("Click", (*) => CloseCancel())
    CloseGui.OnEvent("Close", (*) => CloseCancel())
    CloseGui.Show("AutoSize Center")

    ; เริ่มนับถอยหลัง
    SetTimer(CloseTick, 1000)
    CloseTick()
}

; ===== Countdown =====
CloseTick() {
    global CloseActive, CloseRemain, CloseGui

    if (!CloseActive) {
        SetTimer(CloseTick, 0)
        return
    }

    ; อัปเดตข้อความ
    if (CloseGui)
        CloseGui["Static1"].Text := "⚠️ จะปิดทุกโปรแกรมใน " CloseRemain " วินาที"

    CloseRemain -= 1

    ; หมดเวลา → ปิดทุกโปรแกรม
    if (CloseRemain < 0) {
        SetTimer(CloseTick, 0)
        CloseActive := false
        if (CloseGui) {
            try CloseGui.Destroy()
            CloseGui := 0
        }
        CloseAllPrograms()
    }
}

; ===== Cancel =====
CloseCancel() {
    global CloseActive, CloseRemain, CloseGui

    CloseActive := false
    CloseRemain := 0
    SetTimer(CloseTick, 0)

    if (CloseGui) {
        try CloseGui.Destroy()
        CloseGui := 0
    }

    TrayTip("ยกเลิกแล้ว", "ไม่ได้ปิดโปรแกรมใดๆ", 2)
    SoundBeep(600, 120)
}

; ===== Logic ปิดโปรแกรม (ของคุณ) =====
CloseAllPrograms() {
    idList := WinGetList()
    for hwnd in idList {
        try {
            exe := WinGetProcessName(hwnd)
            cls := WinGetClass(hwnd)

            if cls ~= "i)Progman|WorkerW|Shell_TrayWnd|MultitaskingViewFrame"
                continue
            if exe ~= "i)AutoHotkey.*\.exe"
                continue

            if (exe = "explorer.exe") {
                if cls ~= "i)CabinetWClass|ExploreWClass"
                    WinClose(hwnd)
                continue
            }

            if !WinClose(hwnd) {
                pid := WinGetPID(hwnd)
                ProcessClose(pid)
            }
        }
    }

    SoundBeep(1000, 150)
    TrayTip("🧹 ปิดทุกโปรแกรมแล้ว", "รวมถึงหน้าต่างโฟลเดอร์ทั้งหมด", 3)
}
ShutdownActive := false
ShutdownRemain := 0
ShutdownGui := 0

Pause:: {
    global ShutdownActive, ShutdownRemain, ShutdownGui

    ; ถ้ากำลังนับอยู่ กดซ้ำ = ยกเลิก
    if (ShutdownActive) {
        ShutdownCancel()
        return
    }

    ; เริ่มนับทันทีตั้งแต่กดปุ่ม (ให้ Windows ทำ countdown จริง)
    ShutdownActive := true
    ShutdownRemain := 5
    Run(A_ComSpec ' /c shutdown /s /t 5 /c "AutoHotkey: Shutting down in 5 seconds. Press Cancel or Pause to abort."', , "Hide")

    ; สร้างหน้าต่างยกเลิก
    ShutdownGui := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", "Shutdown Countdown")
    ShutdownGui.SetFont("s11")
    txt := ShutdownGui.AddText("w360", "⏳ จะปิดเครื่องใน 5 วินาที")
    ShutdownGui.AddText("w360", "กดปุ่ม Cancel เพื่อยกเลิก (หรือกด Pause ซ้ำ)")
    btn := ShutdownGui.AddButton("w120 Default", "Cancel")
    btn.OnEvent("Click", (*) => ShutdownCancel())

    ShutdownGui.OnEvent("Close", (*) => ShutdownCancel()) ; ปิดหน้าต่าง = ยกเลิก
    ShutdownGui.Show("AutoSize Center")

    ; อัปเดตข้อความนับถอยหลังทุก 1 วิ
    SetTimer(ShutdownTick, 1000)
    ShutdownTick()  ; อัปเดตทันที
}

ShutdownTick() {
    global ShutdownActive, ShutdownRemain, ShutdownGui

    if (!ShutdownActive) {
        SetTimer(ShutdownTick, 0)
        return
    }

    if (ShutdownGui) {
        ; อัปเดตบรรทัดแรกของ GUI (control ตัวแรก)
        ShutdownGui["Static1"].Text := "⏳ จะปิดเครื่องใน " ShutdownRemain " วินาที"
    }

    ShutdownRemain -= 1

    ; ครบเวลาแล้ว ปล่อยให้ Windows shutdown เอง
    if (ShutdownRemain < 0) {
        ShutdownActive := false
        SetTimer(ShutdownTick, 0)
        if (ShutdownGui) {
            try ShutdownGui.Destroy()
            ShutdownGui := 0
        }
    }
}

ShutdownCancel() {
    global ShutdownActive, ShutdownRemain, ShutdownGui

    Run(A_ComSpec ' /c shutdown /a', , "Hide") ; ยกเลิก shutdown ของ Windows
    ShutdownActive := false
    ShutdownRemain := 0
    SetTimer(ShutdownTick, 0)

    if (ShutdownGui) {
        try ShutdownGui.Destroy()
        ShutdownGui := 0
    }

    TrayTip("ยกเลิกแล้ว", "ยกเลิกการปิดเครื่อง", 2)
    SoundBeep(600, 120)
}

; ปุ่ม Print Screen = Ctrl + A
SC137::Send("^a")

; ===============================
; SC070: เปิดไฟล์รายชื่อฝ่ายขาย (営業(ひら)) ตอนกด 1 ครั้ง
; กด 2 ครั้งติดกันเร็ว ๆ = สลับไป Excel เปิด filter ของคอลัมน์ J
; กด 3 ครั้งติดกันเร็ว ๆ = เหมือนกด 2 ครั้งทุกอย่าง แต่ใช้คอลัมน์ D แทน J
;
; เดิม (ตอนรองรับแค่ 1/2 ครั้ง) กด 2 ครั้งจะสั่งงานทันทีที่ตรวจพบการกดครั้งที่ 2 เลย ไม่ต้องรอ
; timeout - แต่พอต้องแยกแยะ "กด 2 ครั้งแล้วจบ" ออกจาก "กด 2 ครั้งแล้วจะมีครั้งที่ 3 ตามมาอีก"
; จำเป็นต้องรอดูให้ครบก่อนเสมอ (ไม่มีทางรู้ล่วงหน้าตอนกดครั้งที่ 2 ว่าจะมีครั้งที่ 3 ตามมาไหม)
; จึงเปลี่ยนมาใช้ deferred state machine แบบเดียวกับ SC002/SC019 ใน mod_AcrobatAVPopupHotkeys.ahk:
; นับจำนวนครั้งกด แล้วรอ SC070_DoublePressMs ทุกครั้งก่อนค่อยตัดสินใจว่าเป็น 1/2/3 ครั้ง -
; ผลคือกด 2 ครั้งจะมีดีเลย์เพิ่มขึ้นเล็กน้อยก่อนเปิด filter (จากเดิมที่ทำทันที) ซึ่งเป็นผลข้างเคียง
; ที่จำเป็นจากการเพิ่มการแยกแยะ 3 ครั้ง (trade-off เดียวกับที่ SC002 เคยยอมรับมาแล้ว) ส่วน logic
; การเปิด filter ของคอลัมน์ J เองไม่มีการแก้ไขใด ๆ เลย (ดู SC070_RunFilterOnColumn ด้านล่าง)
; ===============================
global SC070_Count := 0
global SC070_PressSeq := 0
SC070_DoublePressMs := 400

SC070:: {
    global SC070_Count, SC070_PressSeq

    SC070_Count += 1
    SC070_PressSeq += 1
    mySeq := SC070_PressSeq

    SetTimer(SC070_Timeout.Bind(mySeq), -SC070_DoublePressMs)
}

SC070_Timeout(mySeq) {
    global SC070_Count, SC070_PressSeq

    if (mySeq != SC070_PressSeq)
        return  ; มีการกดครั้งใหม่มาแทนที่ก่อนหมดเวลา ปล่อยให้ timer ของครั้งใหม่จัดการแทน

    n := SC070_Count
    SC070_Count := 0

    if (n = 1) {
        SC070_RunSingle()
    } else if (n = 2) {
        SC070_RunDouble()
    } else if (n >= 3) {
        SC070_RunTriple()
    }
}

SC070_RunSingle() {
    path := "C:\Users\U004797\Desktop\販売管理\連絡\営業(ひら).pdf"

    if !FileExist(path) {
        MsgBox("หาไฟล์ไม่เจอ:`n" path)
        return
    }

    ; ใช้ Acrobat.exe ตรง ๆ แทน Edge (เร็วกว่า - ไม่ต้องรอเปิดเบราว์เซอร์) ผ่าน helper
    ; ตัวเดียวกับ AppsKey ใน mod_CheckIn.ahk (OpenPdfInAcrobat) กันโค้ดซ้ำ
    OpenPdfInAcrobat(path)
}

; Double-press SC070: ไม่เปิด PDF - สลับไป Excel แล้วเปิด filter dropdown ของคอลัมน์ J
; พร้อม focus ช่อง search ของ filter ให้พิมพ์ได้ทันที (logic เดิม ไม่ได้แก้ไขอะไรเลย)
;
; วิธีที่ใช้: เลือก cell หัวตารางของคอลัมน์ J ด้วย COM (Range.Select) แล้วส่ง Alt+Down ซึ่งเป็น
; keyboard shortcut มาตรฐานของ Excel เองสำหรับ "เปิด filter dropdown ของคอลัมน์ที่ active cell
; อยู่" - Excel รุ่นใหม่ (365/2019+) จะ focus ช่อง search ของ dropdown ให้อัตโนมัติอยู่แล้วเมื่อ
; เปิดผ่านคีย์ลัดนี้ ไม่ต้องเสี่ยงใช้ UI Automation เดินหา element เอง (จะพังง่ายเมื่อ Excel
; อัปเดตเวอร์ชัน) และไม่ต้องอ้างพิกัดเมาส์ fix ตำแหน่งเลย - เลือก cell ผ่าน COM ได้แม่นยำเสมอ
; ไม่ว่าหน้าต่าง Excel จะอยู่ตำแหน่ง/ขนาดไหน
SC070_RunDouble() {
    SC070_RunFilterOnColumn("J", 10)  ; คอลัมน์ J = ลำดับที่ 10 (A=1, B=2, ...)
}

; Triple-press SC070: ทำงานเหมือนกด 2 ครั้งทุกอย่าง (เปิด filter dropdown + focus ช่อง search
; + Tab 4 ครั้ง) เพียงแต่ใช้คอลัมน์ D แทน J - reuse logic เดียวกันทั้งหมดผ่าน
; SC070_RunFilterOnColumn เปลี่ยนแค่คอลัมน์เป้าหมาย
SC070_RunTriple() {
    SC070_RunFilterOnColumn("D", 4)  ; คอลัมน์ D = ลำดับที่ 4 (A=1, B=2, ...)
}

; core logic ที่ SC070_RunDouble/SC070_RunTriple เรียกใช้ร่วมกัน รับตัวอักษรคอลัมน์ (ใช้กับ
; Range เช่น "J"/"D") และลำดับคอลัมน์ (ใช้เช็คขอบเขตตาราง AutoFilter เช่น 10/4) เป็นพารามิเตอร์
; เนื้อหาขั้นตอนทั้งหมดเหมือนกับ SC070_RunDouble เดิมทุกประการ ไม่มีการเปลี่ยน logic ใด ๆ เลย
; แค่ดึงมาไว้เป็นฟังก์ชันกลางเพื่อใช้ซ้ำกับคอลัมน์ D ตามที่ร้องขอ
SC070_RunFilterOnColumn(colLetter, colIndex) {
    if !WinExist("ahk_exe EXCEL.EXE") {
        MsgBox("ไม่พบ Excel ที่กำลังเปิดอยู่")
        return
    }

    WinActivate("ahk_exe EXCEL.EXE")
    if !WinWaitActive("ahk_exe EXCEL.EXE", , 3) {
        MsgBox("สลับไปหน้าต่าง Excel ไม่สำเร็จ")
        return
    }

    try {
        xl := ComObjActive("Excel.Application")
    } catch {
        MsgBox("เชื่อมต่อ Excel ผ่าน COM ไม่สำเร็จ")
        return
    }

    try {
        afRange := xl.ActiveSheet.AutoFilter.Range
    } catch {
        MsgBox("ชีตที่ใช้งานอยู่ใน Excel ไม่มี AutoFilter เปิดอยู่")
        return
    }

    headerRow := afRange.Row
    afStartCol := afRange.Column
    afEndCol := afStartCol + afRange.Columns.Count - 1

    if (colIndex < afStartCol || colIndex > afEndCol) {
        MsgBox("คอลัมน์ " colLetter " ไม่อยู่ในขอบเขตของตาราง AutoFilter ปัจจุบัน")
        return
    }

    try
        xl.ActiveSheet.Range(colLetter headerRow).Select()
    catch {
        MsgBox("เลือก cell หัวตารางคอลัมน์ " colLetter " ไม่สำเร็จ")
        return
    }

    Sleep(150)
    Send("!{Down}")

    ; รอให้ dropdown เปิดจริงก่อนสั้น ๆ แล้วกด Tab 4 ครั้งรัว ๆ ต่อ (ผู้ใช้ระบุว่าต้องการ Tab เร็ว ๆ
    ; เพื่อกรอกข้อมูลได้ทันทีหลัง dropdown เปิด) - ถ้าไม่รอเลย บางครั้ง Tab อาจถูกส่งไปก่อนที่
    ; dropdown จะ render/รับ focus เสร็จจริง ทำให้ Tab หลุดไปโดน worksheet grid แทน
    Sleep(150)
    Send("{Tab 4}")
}