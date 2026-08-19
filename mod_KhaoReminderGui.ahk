; mod_KhaoReminderGui.ahk
;
; KHAO Reminder — เช็คลิสต์ + ตั้งเวลาเตือนจริง
; กด CapsLock เปิด/ปิด | ติ๊กช่อง = ทำเสร็จแล้ว | คลิกขวารายการ = ลบ
; บันทึกลงไฟล์อัตโนมัติทุกครั้งที่เพิ่ม/ติ๊ก/ลบ ไม่หายตอนปิดสคริปต์

global khaoGui := 0
global isKhaoVisible := false

global khaoItems := []          ; [{id, cat("work"/"personal"), text, due("" หรือ YYYYMMDDHHMISS), done, notified}]
global khaoNextId := 1
global khaoShowDone := false
global khaoFilePath := A_ScriptDir "\KhaoReminder.txt"

global khaoLV := 0
global khaoCatDD := 0
global khaoTextEdit := 0
global khaoDueChk := 0
global khaoDuePicker := 0
global khaoShowDoneBtn := 0

; ----------------------------
; INIT (ทำงานตั้งแต่เปิดสคริปต์ แม้ยังไม่เปิดหน้าต่าง เพื่อให้ตั้งเวลาเตือนทำงานได้จริง)
; ----------------------------
KhaoRem_Init() {
    KhaoRem_LoadItems()
    SetTimer(KhaoRem_CheckDueItems, 30000)  ; เช็ครายการที่ถึงเวลาเตือนทุก 30 วิ
}

; ============================================================
; PERSISTENCE (บันทึก/โหลดไฟล์)
; ============================================================
KhaoRem_LoadItems() {
    global khaoItems, khaoNextId, khaoFilePath

    khaoItems := []
    khaoNextId := 1

    if !FileExist(khaoFilePath)
        return

    try {
        content := FileRead(khaoFilePath, "UTF-8")
    } catch {
        return
    }

    for line in StrSplit(content, "`n", "`r") {
        if (Trim(line) = "")
            continue

        parts := StrSplit(line, "`t")
        if (parts.Length < 6)
            continue

        item := Map(
            "id", Integer(parts[1]),
            "cat", parts[2],
            "text", parts[3],
            "due", parts[4],
            "done", parts[5] = "1",
            "notified", parts[6] = "1"
        )
        khaoItems.Push(item)

        if (item["id"] >= khaoNextId)
            khaoNextId := item["id"] + 1
    }
}

KhaoRem_SaveItems() {
    global khaoItems, khaoFilePath

    lines := []
    for item in khaoItems
        lines.Push(item["id"] "`t" item["cat"] "`t" item["text"] "`t" item["due"] "`t" (item["done"] ? "1" : "0") "`t" (item["notified"] ? "1" : "0"))

    try {
        f := FileOpen(khaoFilePath, "w", "UTF-8")
        f.Write(KhaoRem_Join(lines, "`n"))
        f.Close()
    } catch as e {
        MsgBox("บันทึกรายการไม่สำเร็จ: " e.Message, "KHAO Reminder", 48)
    }
}

KhaoRem_Join(arr, sep) {
    out := ""
    for i, v in arr
        out .= (i = 1 ? "" : sep) v
    return out
}

; ============================================================
; ตั้งเวลาเตือนจริง (เช็คทุก 30 วิ ไม่ว่าหน้าต่างจะเปิดอยู่หรือไม่)
; ============================================================
KhaoRem_CheckDueItems() {
    global khaoItems

    now := A_Now
    changed := false

    for item in khaoItems {
        if (item["done"] || item["notified"] || item["due"] = "")
            continue

        if (item["due"] <= now) {
            KhaoRem_Notify(item)
            item["notified"] := true
            changed := true
        }
    }

    if changed {
        KhaoRem_SaveItems()
        if (isKhaoVisible)
            KhaoRem_RefreshList()
    }
}

KhaoRem_Notify(item) {
    catLabel := item["cat"] = "work" ? "งาน" : "ส่วนตัว"
    SoundBeep(1000, 200)
    MsgBox("⏰ ถึงเวลาแล้ว!`n`n[" catLabel "] " item["text"], "KHAO Reminder", 64)
}

; ============================================================
; GUI
; ============================================================
InitKhaoGui() {
    global khaoGui, khaoLV, khaoCatDD, khaoTextEdit, khaoDueChk, khaoDuePicker, khaoShowDoneBtn

    if IsObject(khaoGui)
        return

    khaoGui := Gui("+AlwaysOnTop +ToolWindow", "⏰ KHAO Reminder")
    khaoGui.BackColor := "0x20232A"
    khaoGui.SetFont("s9 cWhite", "Segoe UI")
    khaoGui.MarginX := 10
    khaoGui.MarginY := 10

    khaoGui.AddText("xm w420 cGray", "กด CapsLock เปิด/ปิด  |  ติ๊กช่อง = ทำเสร็จแล้ว  |  คลิกขวารายการ = ลบ")

    khaoLV := khaoGui.AddListView("xm y+8 w420 h220 Checked Grid", ["ประเภท", "รายการ", "เตือนเมื่อ", "สถานะ", "id"])
    khaoLV.ModifyCol(1, 70)
    khaoLV.ModifyCol(2, 190)
    khaoLV.ModifyCol(3, 100)
    khaoLV.ModifyCol(4, 40)
    khaoLV.ModifyCol(5, 0)  ; ซ่อนคอลัมน์ id ไว้ใช้ภายใน
    khaoLV.OnEvent("ItemCheck", KhaoRem_OnItemCheck)
    khaoLV.OnEvent("ContextMenu", KhaoRem_OnContextMenu)

    khaoGui.AddText("xm y+10", "หมวด:")
    khaoCatDD := khaoGui.AddDropDownList("x+5 yp-3 w100 Choose1", ["งาน", "ส่วนตัว"])

    khaoGui.AddText("xm y+8", "รายการ:")
    khaoTextEdit := khaoGui.AddEdit("x+5 yp-3 w305")

    khaoDueChk := khaoGui.AddCheckbox("xm y+10", "ตั้งเวลาเตือน")
    khaoDueChk.OnEvent("Click", KhaoRem_ToggleDuePicker)
    khaoDuePicker := khaoGui.AddDateTime("x+10 yp-3 w240 Choose" A_Now, "yyyy-MM-dd HH:mm")
    khaoDuePicker.Enabled := false

    btnAdd := khaoGui.AddButton("xm y+12 w130 h28", "➕ เพิ่มรายการ")
    btnAdd.OnEvent("Click", KhaoRem_AddItem)

    khaoShowDoneBtn := khaoGui.AddButton("x+10 yp w160 h28", "👁 แสดงรายการที่เสร็จ")
    khaoShowDoneBtn.OnEvent("Click", KhaoRem_ToggleShowDone)

    btnClose := khaoGui.AddButton("x+10 yp w80 h28", "❌ ปิด")
    btnClose.OnEvent("Click", (*) => HideKhaoGui())

    khaoGui.OnEvent("Close", (*) => HideKhaoGui())

    KhaoRem_RefreshList()
}

KhaoRem_RefreshList() {
    global khaoLV, khaoItems, khaoShowDone

    if !IsObject(khaoLV)
        return

    khaoLV.Delete()

    for item in khaoItems {
        if (item["done"] && !khaoShowDone)
            continue

        catLabel := item["cat"] = "work" ? "📁 งาน" : "🏠 ส่วนตัว"
        dueLabel := KhaoRem_FormatDue(item["due"])
        statusLabel := item["done"] ? "✅" : ""

        khaoLV.Add(item["done"] ? "Check" : "", catLabel, item["text"], dueLabel, statusLabel, item["id"])
    }
}

KhaoRem_FormatDue(due) {
    if (due = "")
        return "-"
    try
        return FormatTime(due, "dd/MM HH:mm")
    catch
        return "-"
}

; ----------------------------
; เพิ่มรายการ
; ----------------------------
KhaoRem_AddItem(*) {
    global khaoItems, khaoNextId, khaoCatDD, khaoTextEdit, khaoDueChk, khaoDuePicker

    text := Trim(khaoTextEdit.Value)
    if (text = "") {
        MsgBox("กรุณาพิมพ์รายการก่อน", "KHAO Reminder", 48)
        return
    }

    cat := khaoCatDD.Text = "งาน" ? "work" : "personal"
    due := khaoDueChk.Value ? khaoDuePicker.Value : ""

    item := Map("id", khaoNextId, "cat", cat, "text", text, "due", due, "done", false, "notified", false)
    khaoItems.Push(item)
    khaoNextId += 1

    khaoTextEdit.Value := ""
    khaoDueChk.Value := 0
    khaoDuePicker.Enabled := false

    KhaoRem_SaveItems()
    KhaoRem_RefreshList()
    khaoTextEdit.Focus()
}

KhaoRem_ToggleDuePicker(ctrl, *) {
    global khaoDuePicker
    khaoDuePicker.Enabled := ctrl.Value
}

; ----------------------------
; ติ๊ก = ทำเสร็จแล้ว / เอาติ๊กออก = ยังไม่เสร็จ
; ----------------------------
KhaoRem_OnItemCheck(LV, RowNumber, Checked) {
    global khaoItems

    id := Integer(LV.GetText(RowNumber, 5))

    for item in khaoItems {
        if (item["id"] = id) {
            item["done"] := Checked
            break
        }
    }

    KhaoRem_SaveItems()
    KhaoRem_RefreshList()
}

; ----------------------------
; คลิกขวา = ลบรายการ
; ----------------------------
KhaoRem_OnContextMenu(LV, RowNumber, IsRightClick, X, Y) {
    if (RowNumber = 0)
        return

    id := Integer(LV.GetText(RowNumber, 5))

    menu := Menu()
    menu.Add("🗑 ลบรายการนี้", (*) => KhaoRem_DeleteItem(id))
    menu.Show(X, Y)
}

KhaoRem_DeleteItem(id) {
    global khaoItems

    for i, item in khaoItems {
        if (item["id"] = id) {
            khaoItems.RemoveAt(i)
            break
        }
    }

    KhaoRem_SaveItems()
    KhaoRem_RefreshList()
}

; ----------------------------
; แสดง/ซ่อนรายการที่ทำเสร็จแล้ว
; ----------------------------
KhaoRem_ToggleShowDone(*) {
    global khaoShowDone, khaoShowDoneBtn

    khaoShowDone := !khaoShowDone
    khaoShowDoneBtn.Text := khaoShowDone ? "🙈 ซ่อนรายการที่เสร็จ" : "👁 แสดงรายการที่เสร็จ"
    KhaoRem_RefreshList()
}

; ============================================================
; SHOW / HIDE / TOGGLE
; ============================================================
ShowKhaoGui() {
    global khaoGui, isKhaoVisible

    if !IsObject(khaoGui)
        InitKhaoGui()

    KhaoRem_RefreshList()
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
