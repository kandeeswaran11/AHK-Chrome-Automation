; ================================================
; Chrome CDP GUI - Final Version
; vt,mt,tnkat,vk,jsr,vtt
; ================================================
#Requires AutoHotkey v2
#SingleInstance Force
#Include JXON.ahk
#Include WebSocket_Chrome.ahk

; =========================
; Global Variables
; =========================
global cdp := ""
global myGui := ""
global tabTitleInput := ""
global connectBtn := ""
global connectionStatus := ""
global jsInput := ""
global outputBox := ""
global statusBar := ""
global runBtn := ""
global asyncBtn := ""
global verifyBtn := ""
global saveCSVBtn := ""

; =========================
; Initialize GUI
; =========================
CreateGUI()

; =========================
; GUI Creation
; =========================
CreateGUI() {
    global myGui, tabTitleInput, connectBtn, connectionStatus, jsInput, outputBox, statusBar, runBtn, asyncBtn, verifyBtn, saveCSVBtn
    
    myGui := Gui("+Resize +AlwaysOnTop", "Chrome CDP JS Runner")
    myGui.SetFont("s10", "Segoe UI")
    
    ; ── Connection Section ──
    myGui.AddText("x10 y10", "Chrome Tab Title (partial match):")
    tabTitleInput := myGui.AddEdit("x10 y30 w500 h25 vTabTitleInput", "")
    tabTitleInput.SetFont("s10")
    
    connectBtn := myGui.AddButton("x520 y30 w120 h25", "Connect (F9)")
    connectBtn.OnEvent("Click", (*) => ConnectToChrome())
    
    verifyBtn := myGui.AddButton("x650 y30 w120 h25", "Verify (F8)")
    verifyBtn.OnEvent("Click", (*) => VerifyConnection())
    
    ; Connection status display
    myGui.SetFont("s9 bold", "Segoe UI")
    connectionStatus := myGui.AddText("x10 y60 w760 h25 cRed", "● Not Connected")
    myGui.SetFont("s10 norm", "Segoe UI")
    
    myGui.AddText("x10 y90 w760 h2 +0x10")  ; Separator
    
    ; ── JavaScript Section ──
    myGui.AddText("x10 y100", "JavaScript Code:")
    jsInput := myGui.AddEdit("x10 y120 w760 h160 vJSInput WantTab")
    
    runBtn := myGui.AddButton("x10 y290 w100 h30 Disabled", "Run (F10)")
    runBtn.OnEvent("Click", (*) => RunJS())
    
    clearBtn := myGui.AddButton("x120 y290 w100 h30", "Clear")
    clearBtn.OnEvent("Click", (*) => ClearOutput())
    
    asyncBtn := myGui.AddButton("x230 y290 w100 h30 Disabled", "Run Async")
    asyncBtn.OnEvent("Click", (*) => RunJSAsync())
    
    saveCSVBtn := myGui.AddButton("x340 y290 w120 h30", "Save as CSV")
    saveCSVBtn.OnEvent("Click", (*) => SaveLastOutputAsCSV())
    
    myGui.AddText("x10 y330", "Output:")
    outputBox := myGui.AddEdit("x10 y350 w760 h220 vOutputBox ReadOnly")
    
    statusBar := myGui.AddStatusBar()
    statusBar.SetText("Not Connected - Enter tab title and click Connect")
    
    myGui.OnEvent("Close", (*) => ExitApp())
    myGui.Show("w780 h610")
}

; =========================
; Verify Connection
; =========================
VerifyConnection() {
    global cdp, connectionStatus, statusBar
    
    if !cdp {
        connectionStatus.SetFont("s9 bold cRed")
        connectionStatus.Value := "● Not Connected"
        MsgBox "Not connected to any Chrome tab!`n`nClick 'Connect' first.", "Not Connected"
        return
    }
    
    statusBar.SetText("Verifying connection...")
    
    try {
        title := cdp.GetTitle()
        url := cdp.GetURL()
        
        cdp.ActivateTab()
        Sleep 300
        
        connectionStatus.SetFont("s9 bold cGreen")
        connectionStatus.Value := "● Connected to: " title
        
        statusBar.SetText("✓ Connection verified")
        
        info := "=== CONNECTION VERIFIED ===`n"
        info .= "Title: " title "`n"
        info .= "URL: " url "`n"
        info .= "Status: Active`n"
        info .= "========================`n`n"
        
        AppendOutput(info)
        
        MsgBox "Connected to:`n`nTitle: " title "`n`nURL: " url, "Connection OK", "T3"
        
    } catch as err {
        connectionStatus.SetFont("s9 bold cRed")
        connectionStatus.Value := "● Connection Lost"
        
        statusBar.SetText("✗ Connection lost")
        
        MsgBox "Connection lost!`n`nError: " err.Message "`n`nPlease reconnect.", "Connection Error"
        
        runBtn.Enabled := false
        asyncBtn.Enabled := false
    }
}

; =========================
; Connect to Chrome
; =========================
ConnectToChrome() {
    global cdp, tabTitleInput, statusBar, connectBtn, runBtn, asyncBtn, connectionStatus
    
    tabTitle := tabTitleInput.Value
    
    statusBar.SetText("Connecting to Chrome...")
    connectBtn.Enabled := false
    
    try {
        if tabTitle = ""
            cdp := WebSocket_Chrome(9222, 1)
        else
            cdp := WebSocket_Chrome(9222, 1, tabTitle)
        
        cdp.EnableAll()
        cdp.ActivateTab()
        Sleep 300
        
        actualTitle := cdp.GetTitle()
        actualURL := cdp.GetURL()
        
        runBtn.Enabled := true
        asyncBtn.Enabled := true
        connectBtn.Text := "Reconnect (F9)"
        
        connectionStatus.SetFont("s9 bold cGreen")
        connectionStatus.Value := "● Connected to: " actualTitle
        
        statusBar.SetText("✓ Connected to: " actualTitle)
        
        AppendOutput("=== CONNECTED ===`nTitle: " actualTitle "`nURL: " actualURL "`n`n")
        
        MsgBox "Connected successfully!`n`nTitle: " actualTitle "`n`nURL: " actualURL, "Success", "T2"
        
    } catch as err {
        connectBtn.Enabled := true
        connectionStatus.SetFont("s9 bold cRed")
        connectionStatus.Value := "● Connection Failed"
        statusBar.SetText("✗ Connection Failed")
        
        errorMsg := "Failed to connect to Chrome!`n`n"
        
        if InStr(err.Message, "No Chrome debug tab") {
            errorMsg .= "Make sure Chrome is running with:`nchrome.exe --remote-debugging-port=9222`n`n"
        } else if InStr(err.Message, "No tab found") {
            errorMsg .= "No tab found with title: '" tabTitle "'`n`n"
            errorMsg .= "Available tabs:`n"
            
            try {
                http := ComObject("WinHttp.WinHttpRequest.5.1")
                http.Open("GET", "http://127.0.0.1:9222/json", false)
                http.Send()
                response := http.ResponseText
                tabs := Jxon_Load(&response)
                
                index := 0
                for tab in tabs {
                    index++
                    errorMsg .= index ". " tab["title"] "`n"
                    if index >= 5
                        break
                }
            }
        }
        
        errorMsg .= "`nError: " err.Message
        MsgBox errorMsg, "Connection Error"
    }
    
    connectBtn.Enabled := true
}

; =========================
; Append text and auto-scroll
; =========================
AppendOutput(text) {
    global outputBox
    outputBox.Value .= text
    saved := A_Clipboard
    A_Clipboard := ""
    ControlFocus(outputBox)
    Send "^{End}"
    A_Clipboard := saved
}

; =========================
; Clear output
; =========================
ClearOutput() {
    global outputBox, statusBar
    outputBox.Value := ""
    statusBar.SetText("Cleared")
}

; =========================
; Run JavaScript (Sync)
; =========================
RunJS() {
    global cdp, jsInput, statusBar
    
    if !cdp {
        MsgBox "Please connect to Chrome first!", "Error"
        return
    }
    
    js := jsInput.Value
    if !js {
        MsgBox "Please enter JavaScript code!", "Error"
        return
    }
    
    statusBar.SetText("Running JS...")
    
    try {
        cdp.ActivateTab()
        Sleep 200
        
        result := cdp.Eval(js, 10000)
        
        timestamp := FormatTime(, "HH:mm:ss")
        AppendOutput("[" timestamp "] Result:`n" result "`n`n")
        
        statusBar.SetText("✓ Executed successfully")
    } catch as err {
        AppendOutput("[ERROR] " err.Message "`n`n")
        statusBar.SetText("✗ Error occurred")
    }
}

; =========================
; Run JavaScript (Async)
; =========================
RunJSAsync() {
    global cdp, jsInput, statusBar
    
    if !cdp {
        MsgBox "Please connect to Chrome first!", "Error"
        return
    }
    
    js := jsInput.Value
    if !js {
        MsgBox "Please enter JavaScript code!", "Error"
        return
    }
    
    statusBar.SetText("Running Async JS...")
    
    try {
        cdp.ActivateTab()
        Sleep 200
        
        if !InStr(js, "async") && InStr(js, "await") {
            js := "(async function() { " js " })()"
        }
        
        result := cdp.EvalAsync(js, 30000)
        
        timestamp := FormatTime(, "HH:mm:ss")
        AppendOutput("[" timestamp "] Async Result:`n" result "`n`n")
        
        statusBar.SetText("✓ Async executed successfully")
    } catch as err {
        AppendOutput("[ERROR] " err.Message "`n`n")
        statusBar.SetText("✗ Error occurred")
    }
}

; =========================
; Save Output as CSV
; =========================
SaveLastOutputAsCSV() {
    global outputBox, statusBar
    
    content := outputBox.Value
    
    if !content {
        MsgBox "No output to save!", "Error"
        return
    }
    
    ; Extract last result
    lines := StrSplit(content, "`n")
    lastResult := ""
    startIndex := 0
    
    ; Find last "Result:" line
    loop lines.Length {
        i := lines.Length - A_Index + 1
        line := lines[i]
        
        if InStr(line, "] Result:") || InStr(line, "] Async Result:") {
            startIndex := i + 1
            break
        }
    }
    
    if startIndex = 0 {
        MsgBox "No result found in output!`n`nRun JavaScript first (F10).", "Error"
        return
    }
    
    ; Collect lines until next timestamp
    loop {
        idx := startIndex + A_Index - 1
        if idx > lines.Length
            break
        
        line := lines[idx]
        
        if (A_Index > 1 && (InStr(line, "[") || InStr(line, "---") || InStr(line, "===")))
            break
        
        if line != ""
            lastResult .= line "`n"
    }
    
    lastResult := RTrim(lastResult, "`n")
    
    if !lastResult {
        MsgBox "No valid result to save!", "Error"
        return
    }
    
    ; Ask for filename
    timestamp := FormatTime(, "yyyyMMdd_HHmmss")
    defaultName := "export_" timestamp ".csv"
    
    filename := InputBox("Enter filename:", "Save CSV", "w300 h100", defaultName)
    
    if filename.Result = "Cancel"
        return
    
    filename := filename.Value
    
    if !InStr(filename, ".csv")
        filename .= ".csv"
    
    try {
        FileDelete(filename)
    }
    
    try {
        FileAppend(lastResult, filename, "UTF-8-RAW")
        
        rowCount := StrSplit(lastResult, "`n").Length - 1
        
        statusBar.SetText("✓ Saved to " filename)
        
        AppendOutput("=== CSV SAVED ===`nFile: " filename "`nRows: " rowCount "`n`n")
        
        MsgBox "Saved successfully!`n`nFile: " filename "`nRows: " rowCount "`n`nLocation: " A_ScriptDir, "Success", "T3"
        
        Run 'explorer.exe /select,"' A_ScriptDir "\" filename '"'
        
    } catch as err {
        MsgBox "Failed to save file!`n`nError: " err.Message, "Error"
        statusBar.SetText("✗ Save failed")
    }
}

; =========================
; Hotkeys
; =========================
F8:: VerifyConnection()
F9:: ConnectToChrome()
F10:: RunJS()
^F10:: RunJSAsync()
^s:: SaveLastOutputAsCSV()
^l:: ClearOutput()
^q:: ExitApp
