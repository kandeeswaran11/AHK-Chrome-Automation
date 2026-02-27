; ================================================
; Example usage of WebSocket_Chrome.ahk
; vt,mt,tnkat,vk,jsr,vtt
; Run This To Start Chrome in Debug Mode
; chrome.exe --remote-debugging-port=9222 --user-data-dir="C:\ChromeDebug"
; http://127.0.0.1:9222/json
; REQUIRED FILES in same folder:
;   - WebSocket_Chrome.ahk
;   - JXON.ahk
; ================================================
#Requires AutoHotkey v2
#Include JXON.ahk
#Include WebSocket_Chrome.ahk


f4::{
; Connect by title and activate in one go
cdp := WebSocket_Chrome(9222, 1, "github")
cdp.ActivateTab()  ; ✅ Brings tab to front
cdp.EnableAll() ; Only enable tab you'll run JavaScript on
cdp.Eval("alert('JSR')")
MsgBox cdp.Eval("document.title")

}

f16::{
MyAutomation()
}

MyAutomation()
{
cdp := WebSocket_Chrome(9222, 1, "New tab")
cdp.ActivateTab()  ; ✅ Brings tab to front
cdp.EnableAll() ; Only enable tab you'll run JavaScript on
;your code Here
}

