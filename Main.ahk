; Main.ahk
#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================
; INCLUDE MODULES
; ============================================
#Include "secret.ahk"   ; ต้องมาก่อน
#Include "Lib\OCR.ahk"  ; ใช้โดย mod_Hotkeys.ahk (F6 double-press OCR)
#Include "mod_HotkeyTiming.ahk"  ; รวมค่าดีเลย์ 1/2/3 ครั้งของทุกปุ่มไว้ที่เดียว

#Include "mod_ToolboxGui.ahk"
#Include "mod_CheckIn.ahk"
#Include "mod_Hotkeys.ahk"
#Include "mod_MouseEnhance.ahk"
#Include "mod_DoubleTapLaunch.ahk"
#Include "mod_KhaoReminderGui.ahk"
#Include "mod_AcrobatAVPopupHotkeys.ahk"
#Include "mod_CryptoTerminal.ahk"
#Include "mod_TextExpander.ahk"

; ============================================
; INITIALIZE MODULES
; ============================================
Toolbox_Init()          ; สร้าง & แสดง KHAO TOOLBOX GUI
CheckIn_Init()          ; ตั้ง Timer + Auto Check-in + Brutal Auto Enter
Hotkeys_Init()          ; (ตอนนี้ยังว่าง ๆ แต่เผื่ออนาคต)
MouseEnhance_Init()     ; ตั้งค่าฟังก์ชันเมาส์ (ตอนนี้ไม่มีอะไรใน Init)
DoubleTap_Init()        ; ตั้งค่า double-tap launcher (ตอนนี้ไม่มีอะไรใน Init)
KhaoRem_Init()          ; เตรียม khao reminder GUI (กด CapsLock เพื่อเปิด)
