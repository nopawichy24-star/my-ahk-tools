; mod_KhaoReminderGui.ahk

global khaoGui := 0
global isKhaoVisible := false

global workRows     := []
global personalRows := []

KhaoRem_Init() {
    ; ยังไม่สร้าง GUI ทันที รอให้กด CapsLock ก่อน
}

InitKhaoGui() {
    global khaoGui, workRows, personalRows

    if IsObject(khaoGui)
        return

    khaoGui := Gui("+AlwaysOnTop -Resize +ToolWindow", "khao")
    khaoGui.BackColor := "0x20232A"
    khaoGui.SetFont("s8", "Segoe UI")

    khaoTitleTxt := khaoGui.AddText("xm cWhite Center w170", "⏰ khao")
    khaoTitleTxt.SetFont("s9 Bold")

    khaoGui.AddText("xm w170 cGray", "──────────────")

    workIcon  := khaoGui.AddText("xm cWhite", "📁")
    workLabel := khaoGui.AddText("x+4 yp w120 h16 cWhite", "ทำงาน")
    workLabel.SetFont("Bold")

    Loop 4 {
        cb  := khaoGui.AddCheckbox("xm y+4 cWhite", "")
        edt := khaoGui.AddEdit("x+5 yp w145 cWhite Background0x20232A")

        workRows.Push({cb: cb, edit: edt})
        cb.OnEvent("Click", WorkCheckboxClicked)
    }

    khaoGui.AddText("xm y+6 w170 cGray", "──────────────")

    personalIcon  := khaoGui.AddText("xm cWhite", "🏠")
    personalLabel := khaoGui.AddText("x+4 yp w120 h16 cWhite", "ส่วนตัว")
    personalLabel.SetFont("Bold")

    Loop 4 {
        cb2  := khaoGui.AddCheckbox("xm y+4 cWhite", "")
        edt2 := khaoGui.AddEdit("x+5 yp w145 cWhite Background0x20232A")

        personalRows.Push({cb: cb2, edit: edt2})
        cb2.OnEvent("Click", PersonalCheckboxClicked)
    }

    khaoGui.OnEvent("Close", (*) => HideKhaoGui())
}

ShowKhaoGui() {
    global khaoGui, isKhaoVisible

    if !IsObject(khaoGui)
        InitKhaoGui()

    khaoGui.Show("AutoSize")
    isKhaoVisible := true
}

HideKhaoGui() {
    global khaoGui, isKhaoVisible

    if !IsObject(khaoGui)
        return

    khaoGui.Hide()
    isKhaoVisible := false
}

ToggleKhaoGui() {
    global isKhaoVisible

    if !isKhaoVisible && !IsObject(khaoGui) {
        InitKhaoGui()
        ShowKhaoGui()
        return
    }

    if (isKhaoVisible)
        HideKhaoGui()
    else
        ShowKhaoGui()
}

CapsLock::ToggleKhaoGui()

WorkCheckboxClicked(ctrl, *) {
    global workRows
    if !ctrl.Value
        return

    for _, row in workRows {
        if (row.cb = ctrl) {
            row.edit.Text := ""
            ctrl.Value := 0
            row.edit.Focus()
            break
        }
    }
}

PersonalCheckboxClicked(ctrl, *) {
    global personalRows
    if !ctrl.Value
        return

    for _, row in personalRows {
        if (row.cb = ctrl) {
            row.edit.Text := ""
            ctrl.Value := 0
            row.edit.Focus()
            break
        }
    }
}
