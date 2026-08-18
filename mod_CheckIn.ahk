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
; AppsKey = เปิดไฟล์ผังที่นั่ง (座席表)
;----------------------------------------
AppsKey:: {

    path := "C:\Users\U004797\Desktop\販売管理\連絡\本社3F 座席表 260806.pdf"

    if FileExist(path)
        Run(path)
    else
        MsgBox("หาไฟล์ไม่เจอ:`n" path)
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