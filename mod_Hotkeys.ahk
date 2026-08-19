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
global F6_Pending := false
F6_DoublePressMs := 300

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
; ผลลัพธ์เก็บใน Clipboard เฉย ๆ ไม่ paste ให้อัตโนมัติ
; ===============================
F6_StartOCR() {
    static ScreenSnipperProcessName := "ScreenClippingHost.exe"

    savedClip := ClipboardAll()
    A_Clipboard := ""  ; เคลียร์ไว้ก่อน เพื่อรู้ว่าผู้ใช้ลากเลือกเสร็จแล้วหรือยัง

    RunWait("ms-screenclip:")  ; เปิดโหมดลากเลือกพื้นที่ของ Windows (ไม่ใช่โปรแกรม OCR)

    WinWaitActive("ahk_exe " ScreenSnipperProcessName, , 2)
    Loop {
        DllCall("user32.dll\GetCursorPos", "int64P", &pt64 := 0)
        try {
            hWnd := DllCall("GetAncestor", "Ptr", DllCall("user32.dll\WindowFromPoint", "int64", pt64, "ptr"), "UInt", 2, "ptr")
            if WinGetProcessName(hWnd) != ScreenSnipperProcessName
                break
        } catch {
            break
        }
        Sleep(50)
    }

    if !ClipWait(1, 1) {
        A_Clipboard := savedClip  ; ผู้ใช้กด Esc ไม่ได้ลากเลือกอะไร -> คืนคลิปบอร์ดเดิม
        return
    }

    Sleep(100)

    if !DllCall("IsClipboardFormatAvailable", "uint", 2) {  ; 2 = CF_BITMAP
        A_Clipboard := savedClip
        return
    }

    DllCall("OpenClipboard", "ptr", A_ScriptHwnd)
    hData := DllCall("GetClipboardData", "uint", 2, "ptr")
    hBitmap := DllCall("User32.dll\CopyImage", "UPtr", hData, "UInt", 0, "Int", 0, "Int", 0, "UInt", 0x2000, "Ptr")
    DllCall("CloseClipboard")

    try {
        result := OCR.FromBitmap(hBitmap, {lang: "ja-JP", scale: 2})
        A_Clipboard := Trim(result.Text)
        TrayTip("OCR เสร็จแล้ว", "ข้อความอยู่ใน Clipboard แล้ว กด Ctrl+V เพื่อวางเอง", 2)
    } catch as e {
        A_Clipboard := savedClip
        MsgBox("OCR ไม่สำเร็จ: " e.Message)
    }
}
F7::Send "{Delete}"
F8::WinClose("A")
F9::Send("# ")
F10::DllCall("LockWorkStation")

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
; SC070: เปิดไฟล์รายชื่อฝ่ายขาย (営業(ひら))
; ===============================
SC070:: {
    path := "C:\Users\U004797\Desktop\販売管理\連絡\営業(ひら).pdf"

    if FileExist(path)
        Run(path)
    else
        MsgBox("หาไฟล์ไม่เจอ:`n" path)
}