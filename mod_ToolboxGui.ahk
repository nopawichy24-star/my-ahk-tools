; mod_ToolboxGui.ahk

global isGuiVisible := false
global mainGui, guiHwnd

; section visibility flags
global browserVisible := false
global katoVisible := false
global extraFilesVisible := false

; เก็บ control ต่าง ๆ
global fileCheckboxes := []
global extraFileCheckboxes := []
global browserControls := []
global katoControls := []
global headerControls := []    ; หัวข้อที่ hover ได้
global currentHoverHeader := 0 ; หัวข้อที่กำลัง hover

; ---------- URL ----------
global KATO_Intranet_URL := "http://172.16.0.221:84/katoworks/"
global GroupSession_URL  := "https://a3a090.ik.local/gsession/common/cmn001.do"
global Concur_URL        := "https://www.concursolutions.com/"
global Kato_HP_URL       := "https://www.kato-works.co.jp/"

; ---------- FILE LIST ----------
global fileEntries := [

    {label: "📊 販売管理部", path: "C:\Users\U004797\Desktop\販売管理"},
    {label: "🖨️ スキャン", path: "\\B0c127\スキャン"},
    {label: "👤 個人", path: "C:\Users\U004797\Desktop\カウ.lnk"},
    {label: "🧚 Fairy", path: "C:\Users\U004797\Desktop\Desktop\fairy.ik.local - ショートカット.lnk"},
    {label: "📋 仕様", path: "\\a1a012\$営業公開\○国内営業本部\販売管理部\移行データ2025\☆仕様価格表"},
    {label: "🔢 コード", path: "\\a1a012\$販管部公開\☆取引先マスタ\☆取引先マスタDATA(参照用).xlsx"},
    {label: "🤝 成約Excel", path: "C:\Users\U004797\Desktop\販売管理\成約"}
]

global extraFileEntries := [
    {label: "📦 支店送付済_出荷依頼書", path: "\\a1a012\$営業公開\○国内営業本部\販売管理部\個人用フォルダ\カウ\出荷依頼書\CR成約報告書、出荷依頼書.lnk"},
    {label: "📮 ポスト", path: "C:\Users\U004797\Desktop\ノッパウィット.lnk"},
    {label: "📑 成約Excel原本", path: "\\a1a012\$営業公開\○国内営業本部\販売管理部"},
    {label: "🔧 Product Support", path: "C:\Users\U004797\Desktop\PS"},
    {label: "🗑️ ごみ箱", path: "shell:RecycleBinFolder"},
    {label: "⚙️ AutoHotkey Scripts", path: "C:\Users\U004797\Documents\AutoHotkey"}
]

; control globals
global titleTxt, lineTop
global filesLabel
global btnOpenFiles
global hdrMore, btnOpenExtra
global sepFilesBrowser
global hdrBrowser
global sepBrowserKato
global hdrKato

Toolbox_Init() {
    global mainGui, isGuiVisible
    global titleTxt, lineTop, filesLabel, btnOpenFiles
    global hdrMore, btnOpenExtra, sepFilesBrowser
    global hdrBrowser, sepBrowserKato, hdrKato
    global fileCheckboxes, extraFileCheckboxes
    global browserControls, katoControls, headerControls
    global guiHwnd

    mainGui := Gui("+AlwaysOnTop -Resize +ToolWindow", "KHAO TOOLBOX")
    mainGui.BackColor := "0x20232A"
    mainGui.SetFont("s8 cWhite", "Segoe UI")

    ; ----- TITLE -----
    titleTxt := mainGui.AddText("xm Center w170", "🧰 KHAO TOOLBOX")
    titleTxt.SetFont("s9 Bold")
    lineTop := mainGui.AddText("xm w170 cGray", "──────────────")

    ; ----- FILES -----
    filesLabel := mainGui.AddText("xm", "🗂️ Files")

    for entry in fileEntries {
        cb := mainGui.AddCheckbox("xm w170", entry.label)
        fileCheckboxes.Push(cb)
    }

    btnOpenFiles := mainGui.AddButton("xm w170", "📂 Open Selected")
    btnOpenFiles.OnEvent("Click", OpenSelectedFilesMain)

    ; ----- MORE FILES SECTION -----
    hdrMore := mainGui.AddText("xm w170", "📂 More")
    hdrMore.SetFont("Bold cWhite")
    hdrMore.OnEvent("Click", ToggleExtraFilesSection)
    headerControls.Push(hdrMore)

    for entry in extraFileEntries {
        cb := mainGui.AddCheckbox("xm w170", entry.label)
        cb.Visible := false
        extraFileCheckboxes.Push(cb)
    }

    btnOpenExtra := mainGui.AddButton("xm w170", "📂 Open More Files")
    btnOpenExtra.Visible := false
    btnOpenExtra.OnEvent("Click", OpenSelectedFilesExtra)

    sepFilesBrowser := mainGui.AddText("xm w170 cGray", "──────────────")

    ; ----- BROWSER SECTION -----
    hdrBrowser := mainGui.AddText("xm w170", "🌍 Browser")
    hdrBrowser.SetFont("Bold cWhite")
    hdrBrowser.OnEvent("Click", ToggleBrowserSection)
    headerControls.Push(hdrBrowser)

    btnChrome := mainGui.AddButton("xm w170", "🌍 Chrome")
    btnChrome.OnEvent("Click", OpenChrome)
    browserControls.Push(btnChrome)

    btnIncog := mainGui.AddButton("xm w170", "🕶️ Incognito")
    btnIncog.OnEvent("Click", OpenChromeIncognito)
    browserControls.Push(btnIncog)

    btnEdge := mainGui.AddButton("xm w170", "🌐 Edge")
    btnEdge.OnEvent("Click", OpenEdgeBlank)
    browserControls.Push(btnEdge)

    for ctrl in browserControls
        ctrl.Visible := false

    sepBrowserKato := mainGui.AddText("xm w170 cGray", "──────────────")

    ; ----- KATO SECTION -----
    hdrKato := mainGui.AddText("xm w170", "🏗 KATO")
    hdrKato.SetFont("Bold cWhite")
    hdrKato.OnEvent("Click", ToggleKatoSection)
    headerControls.Push(hdrKato)

    btnKatoIntra := mainGui.AddButton("xm w170", "🏭 Intranet")
    btnKatoIntra.OnEvent("Click", OpenKatoIntra)
    katoControls.Push(btnKatoIntra)

    btnGroup := mainGui.AddButton("xm w170", "📂 GroupSession")
    btnGroup.OnEvent("Click", OpenGroupSession)
    katoControls.Push(btnGroup)

    btnConcur := mainGui.AddButton("xm w170", "💼 Concur")
    btnConcur.OnEvent("Click", OpenConcur)
    katoControls.Push(btnConcur)

    btnHP := mainGui.AddButton("xm w170", "🏢 KATO HP")
    btnHP.OnEvent("Click", OpenKatoHP)
    katoControls.Push(btnHP)

    for ctrl in katoControls
        ctrl.Visible := false

    ; HOVER EFFECT หัวข้อ
    OnMessage(0x200, HoverCheck)

    ; drag window
    guiHwnd := mainGui.Hwnd
    OnMessage(0x201, WM_LBUTTONDOWN)

    Relayout()
    ShowGui()
}

; ============================================
; HOVER EFFECT เฉพาะหัวข้อ (More / Browser / KATO)
; ============================================

HoverCheck(wParam, lParam, msg, hwnd) {
    global headerControls, currentHoverHeader

    MouseGetPos(, , , &ctrlHwnd, 2)

    if !ctrlHwnd {
        if currentHoverHeader {
            currentHoverHeader.SetFont("Bold cWhite")
            currentHoverHeader := 0
        }
        return
    }

    for hdr in headerControls {
        if (hdr.Hwnd = ctrlHwnd) {
            if (currentHoverHeader && currentHoverHeader != hdr)
                currentHoverHeader.SetFont("Bold cWhite")

            if (currentHoverHeader != hdr) {
                hdr.SetFont("Bold c00BFFF")
                currentHoverHeader := hdr
            }
            return
        }
    }

    if currentHoverHeader {
        currentHoverHeader.SetFont("Bold cWhite")
        currentHoverHeader := 0
    }
}

; ============================================
; SECTION TOGGLES
; ============================================

ToggleExtraFilesSection(*) {
    global extraFilesVisible, extraFileCheckboxes, btnOpenExtra
    extraFilesVisible := !extraFilesVisible
    for cb in extraFileCheckboxes
        cb.Visible := extraFilesVisible
    btnOpenExtra.Visible := extraFilesVisible
    Relayout()
}

ToggleBrowserSection(*) {
    global browserVisible, browserControls
    browserVisible := !browserVisible
    for ctrl in browserControls
        ctrl.Visible := browserVisible
    Relayout()
}

ToggleKatoSection(*) {
    global katoVisible, katoControls
    katoVisible := !katoVisible
    for ctrl in katoControls
        ctrl.Visible := katoVisible
    Relayout()
}

; ============================================
; FILE OPEN FUNCTIONS
; ============================================

OpenSelectedFilesMain(*) {
    global fileEntries, fileCheckboxes
    OpenSelectedFilesGeneric(fileEntries, fileCheckboxes)
}

OpenSelectedFilesExtra(*) {
    global extraFileEntries, extraFileCheckboxes
    OpenSelectedFilesGeneric(extraFileEntries, extraFileCheckboxes)
}

OpenSelectedFilesGeneric(entries, checks) {
    anyOpened := false
    for i, cb in checks {
        if cb.Value {
            path := entries[i].path

            if InStr(path, "shell:") {
                Run(path)
                anyOpened := true
                continue
            }

            if FileExist(path) {
                Run(path)
                anyOpened := true
            } else {
                MsgBox("หาไฟล์ไม่เจอ:`n" path, "KHAO TOOLBOX", 48)
            }
        }
    }
    if !anyOpened
        MsgBox("กรุณาติ๊กเลือกไฟล์อย่างน้อย 1 ไฟล์", "KHAO TOOLBOX", 48)
}

; ============================================
; BROWSER / KATO URL FUNCTIONS
; ============================================

OpenChrome(*) {
    try {
        Run("chrome.exe")
    } catch {
        MsgBox("ไม่พบ Google Chrome", "KHAO TOOLBOX", 48)
    }
}

OpenChromeIncognito(*) {
    try {
        Run("chrome.exe --incognito")
    } catch {
        MsgBox("ไม่พบ Google Chrome", "KHAO TOOLBOX", 48)
    }
}

OpenEdgeBlank(*) {
    try {
        Run("msedge.exe")
    } catch {
        MsgBox("ไม่พบ Microsoft Edge", "KHAO TOOLBOX", 48)
    }
}

OpenInEdge(url) {
    try {
        Run('msedge.exe "' url '"')
    } catch {
        MsgBox("ไม่สามารถเปิด Edge ได้`n" url, "KHAO TOOLBOX", 48)
    }
}

OpenKatoIntra(*) {
    global KATO_Intranet_URL
    OpenInEdge(KATO_Intranet_URL)
}

OpenGroupSession(*) {
    global GroupSession_URL
    OpenInEdge(GroupSession_URL)
}

OpenConcur(*) {
    global Concur_URL
    OpenInEdge(Concur_URL)
}

OpenKatoHP(*) {
    global Kato_HP_URL
    OpenInEdge(Kato_HP_URL)
}

; ============================================
; LAYOUT (ให้ GUI หด/ขยายตาม section)
; ============================================

Relayout() {
    global titleTxt, lineTop, filesLabel, fileCheckboxes, btnOpenFiles
    global hdrMore, extraFileCheckboxes, btnOpenExtra
    global sepFilesBrowser, hdrBrowser, browserControls
    global sepBrowserKato, hdrKato, katoControls
    global extraFilesVisible, browserVisible, katoVisible
    global mainGui

    marginX := 0, tmpY := 0, tmpW := 0, tmpH := 0
    titleTxt.GetPos(&marginX, &tmpY, &tmpW, &tmpH)
    y := 5

    titleTxt.Move(marginX, y)
    y += tmpH + 4

    lineTop.GetPos(,,, &tmpH)
    lineTop.Move(marginX, y)
    y += tmpH + 6

    filesLabel.GetPos(,,, &tmpH)
    filesLabel.Move(marginX, y)
    y += tmpH + 2

    for cb in fileCheckboxes {
        cb.GetPos(,,, &tmpH)
        cb.Move(marginX, y)
        y += tmpH + 1
    }

    btnOpenFiles.GetPos(,,, &tmpH)
    btnOpenFiles.Move(marginX, y)
    y += tmpH + 4

    hdrMore.GetPos(,,, &tmpH)
    hdrMore.Move(marginX, y)
    y += tmpH + 2

    if extraFilesVisible {
        for cb in extraFileCheckboxes {
            cb.GetPos(,,, &tmpH)
            cb.Move(marginX, y)
            y += tmpH + 1
        }
        btnOpenExtra.GetPos(,,, &tmpH)
        btnOpenExtra.Move(marginX, y)
        y += tmpH + 6
    }

    sepFilesBrowser.GetPos(,,, &tmpH)
    sepFilesBrowser.Move(marginX, y)
    y += tmpH + 6

    hdrBrowser.GetPos(,,, &tmpH)
    hdrBrowser.Move(marginX, y)
    y += tmpH + 2

    if browserVisible {
        for ctrl in browserControls {
            ctrl.GetPos(,,, &tmpH)
            ctrl.Move(marginX, y)
            y += tmpH + 2
        }
        y += 2
    }

    sepBrowserKato.GetPos(,,, &tmpH)
    sepBrowserKato.Move(marginX, y)
    y += tmpH + 6

    hdrKato.GetPos(,,, &tmpH)
    hdrKato.Move(marginX, y)
    y += tmpH + 2

    if katoVisible {
        for ctrl in katoControls {
            ctrl.GetPos(,,, &tmpH)
            ctrl.Move(marginX, y)
            y += tmpH + 2
        }
    }

    mainGui.Show("AutoSize")
}

; ============================================
; SHOW / HIDE / HOTKEY / DRAG
; ============================================

ShowGui() {
    global mainGui, isGuiVisible
    mainGui.Show("x1590 y59")
    isGuiVisible := true
}

HideGui() {
    global mainGui, isGuiVisible
    mainGui.Hide()
    isGuiVisible := false
}

ToggleGui() {
    global isGuiVisible
    if isGuiVisible
        HideGui()
    else
        ShowGui()
}

Delete::ToggleGui()

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global guiHwnd
    if (hwnd == guiHwnd)
        PostMessage(0xA1, 2,,, "ahk_id " guiHwnd)
}
