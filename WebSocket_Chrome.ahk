; ================================================
; WebSocket_Chrome.ahk - Chrome CDP Library
; vt,mt,tnkat,vk,jsr,vtt
; Usage:
;   #Include WebSocket_Chrome.ahk
;   cdp := WebSocket_Chrome()
;   cdp.Send("Runtime.enable")
;   result := cdp.Eval("document.title")
; ================================================
#Requires AutoHotkey v2

class WebSocket_Chrome {

    ; ================================================
    ; Constructor - auto connects to Chrome
    ; ================================================
    __New(port := 9222, tabIndex := 1, tabTitle := "") {
        this.port      := port
        this.msgId     := 0
        this.responses := Map()
        this.sock      := ""
        this.connected := false

        wsUrl := this.GetChromeWSUrl(port, tabIndex, tabTitle)
        if !wsUrl
            throw Error("No Chrome debug tab found.`nStart Chrome with:`nchrome.exe --remote-debugging-port=" port)

        this.wsUrl := wsUrl
        this.sock  := _CDPSocket()
        this.sock.Connect("127.0.0.1", port)
        this.Handshake(wsUrl)
        this.connected := true
    }

    ; ================================================
    ; Get Chrome WebSocket URL
    ; port      - debug port (default 9222)
    ; tabIndex  - which tab to connect to (default 1)
    ; tabTitle  - connect to tab matching this title
    ; ================================================
    GetChromeWSUrl(port := 9222, tabIndex := 1, tabTitle := "") {
        try {
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.Open("GET", "http://127.0.0.1:" port "/json", false)
            http.Send()
            response := http.ResponseText

            ; Manual JSON parse for tab list
            tabs := this.ParseTabList(response)

            ; Filter by title if provided
            if tabTitle != "" {
                for tab in tabs {
                    if InStr(tab["title"], tabTitle)
                        return tab["wsUrl"]
                }
                throw Error("No tab found with title: " tabTitle)
            }

            ; Return by index
            idx := 0
            for tab in tabs {
                idx++
                if idx = tabIndex
                    return tab["wsUrl"]
            }

        } catch as err {
            throw Error("GetChromeWSUrl failed: " err.Message)
        }
        return ""
    }

    ; ================================================
    ; Parse tab list JSON manually
    ; ================================================
    ParseTabList(json) {
        tabs := []
        pos  := 1

        loop {
            ; Find webSocketDebuggerUrl
            wsPos := InStr(json, "webSocketDebuggerUrl", true, pos)
            if !wsPos
                break

            ; Extract wsUrl value
            q1 := InStr(json, '"', true, wsPos + 22)
            q2 := InStr(json, '"', true, q1 + 1)
            wsUrl := SubStr(json, q1 + 1, q2 - q1 - 1)

            ; Extract title value
            title := ""
            tPos  := InStr(json, '"title"', true, pos)
            if tPos {
                tq1   := InStr(json, '"', true, tPos + 8)
                tq2   := InStr(json, '"', true, tq1 + 1)
                title := SubStr(json, tq1 + 1, tq2 - tq1 - 1)
            }

            tabs.Push(Map("wsUrl", wsUrl, "title", title))
            pos := q2 + 1
        }

        return tabs
    }

    ; ================================================
    ; WebSocket Handshake
    ; ================================================
    Handshake(wsUrl) {
        ; Parse path from URL
        if !RegExMatch(wsUrl, "ws://[^/]+(/.+)", &m)
            throw Error("Cannot parse path from: " wsUrl)
        path := m[1]

        ; Parse host:port
        if !RegExMatch(wsUrl, "ws://([^:/]+):(\d+)", &m)
            throw Error("Cannot parse host from: " wsUrl)
        host := m[1]
        port := m[2]

        req  := "GET " path " HTTP/1.1`r`n"
        req .= "Host: " host ":" port "`r`n"
        req .= "Upgrade: websocket`r`n"
        req .= "Connection: Upgrade`r`n"
        req .= "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==`r`n"
        req .= "Sec-WebSocket-Version: 13`r`n"
        req .= "`r`n"

        this.sock.SendRaw(req)
        Sleep 300

        rawBuf := this.sock.RecvRaw(4096)
        if !rawBuf || !InStr(Type(rawBuf), "Buffer")
            throw Error("No handshake response received!")

        resp := StrGet(rawBuf, rawBuf.Size, "UTF-8")
        if !InStr(resp, "101")
            throw Error("Handshake failed!`n" resp)
    }

    ; ================================================
    ; Send CDP method
    ; method - CDP method name e.g. "Runtime.enable"
    ; params - Map of parameters (optional)
    ; ================================================
    Send(method, params := "") {
        this.msgId++
        id := this.msgId

        if params = ""
            json := '{"id":' id ',"method":"' method '"}'
        else
            json := '{"id":' id ',"method":"' method '","params":' this.MapToJson(params) '}'

        this.sock.SendFrame(json)
        return id
    }

    ; ================================================
    ; Evaluate JavaScript - returns result value
    ; jsCode  - JavaScript to execute
    ; timeout - ms to wait for response (default 5000)
    ; ================================================
    Eval(jsCode, timeout := 5000) {
        this.msgId++
        id := this.msgId

        ; Build JSON manually - ensures true is boolean not string
        json := '{"id":' id ',"method":"Runtime.evaluate","params":{"expression":'
              . this.JsonString(jsCode)
              . ',"returnByValue":true}}'

        this.sock.SendFrame(json)

        deadline := A_TickCount + timeout
        loop {
            this.DrainFrames()

            if this.responses.Has(id) {
                data := this.responses[id]
                this.responses.Delete(id)
                return this.ExtractValue(data)
            }

            if A_TickCount > deadline
                return "TIMEOUT"

            Sleep 30
        }
    }

    ; ================================================
    ; Activate this tab (bring to front in Chrome)
    ; ================================================
    ActivateTab() {
        targetId := this.GetTargetId()
        if !targetId
            return false
        
        ; Use HTTP endpoint to activate
        try {
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.Open("GET", "http://127.0.0.1:" this.port "/json/activate/" targetId, false)
            http.Send()
            return true
        } catch {
            return false
        }
    }

    ; ================================================
    ; Get target ID from WebSocket URL
    ; ================================================
    GetTargetId() {
        if RegExMatch(this.wsUrl, "/devtools/page/([A-F0-9\-]+)", &m)
            return m[1]
        return ""
    }

    ; ================================================
    ; Run JavaScript from file (auto-detects sync/async)
    ; filepath - path to .js file
    ; timeout  - ms to wait (default 30000)
    ; ================================================
    RunJS(filepath, timeout := 30000) {
        if !FileExist(filepath)
            throw Error("File not found: " filepath)
        
        js := FileRead(filepath)
        
        ; Auto-detect if async (contains await)
        if InStr(js, "await ") {
            ; Wrap in async IIFE if not already wrapped
            if !InStr(js, "(async") && !InStr(js, "async function")
                js := "(async function() { " js " })()"
            return this.EvalAsync(js, timeout)
        } else {
            return this.Eval(js, timeout)
        }
    }

    ; ================================================
    ; Evaluate Async JavaScript (await/Promise support)
    ; Use this for async functions, sleep, await calls
    ; jsCode  - JavaScript to execute (must return a Promise)
    ; timeout - ms to wait for response (default 15000)
    ; ================================================
    EvalAsync(jsCode, timeout := 15000) {
        this.msgId++
        id := this.msgId

        ; awaitPromise:true tells CDP to wait for Promise to resolve
        json := '{"id":' id ',"method":"Runtime.evaluate","params":{"expression":'
              . this.JsonString(jsCode)
              . ',"returnByValue":true,"awaitPromise":true}}'

        this.sock.SendFrame(json)

        deadline := A_TickCount + timeout
        loop {
            this.DrainFrames()

            if this.responses.Has(id) {
                data := this.responses[id]
                this.responses.Delete(id)
                return this.ExtractValue(data)
            }

            if A_TickCount > deadline
                return "TIMEOUT"

            Sleep 30
        }
    }

    ; ================================================
    ; Fill input field (handles React/Vue/Angular)
    ; selector - CSS selector
    ; value    - value to set
    ; ================================================
    FillInput(selector, value) {
        js := '
        (
            (function() {
                var el = document.querySelector("' selector '");
                if (!el) return "not found: ' selector '";
                var setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
                setter.call(el, "' value '");
                el.dispatchEvent(new Event("input",  {bubbles: true}));
                el.dispatchEvent(new Event("change", {bubbles: true}));
                el.dispatchEvent(new Event("keyup",  {bubbles: true}));
                el.focus();
                return "filled";
            })()
        )'
        return this.Eval(js)
    }

    ; ================================================
    ; Click element by CSS selector
    ; selector - CSS selector
    ; ================================================
    Click(selector) {
        js := '
        (
            (function() {
                var el = document.querySelector("' selector '");
                if (!el) return "not found: ' selector '";
                el.click();
                return "clicked";
            })()
        )'
        return this.Eval(js)
    }

    ; ================================================
    ; Select dropdown option by value
    ; selector - CSS selector
    ; value    - option value to select
    ; ================================================
    SelectOption(selector, value) {
        js := '
        (
            (function() {
                var el = document.querySelector("' selector '");
                if (!el) return "not found: ' selector '";
                el.value = "' value '";
                el.dispatchEvent(new Event("change", {bubbles: true}));
                return "selected";
            })()
        )'
        return this.Eval(js)
    }

    ; ================================================
    ; Get element text
    ; selector - CSS selector
    ; ================================================
    GetText(selector) {
        js := '
        (
            (function() {
                var el = document.querySelector("' selector '");
                if (!el) return "not found: ' selector '";
                return el.innerText || el.value || el.textContent;
            })()
        )'
        return this.Eval(js)
    }

    ; ================================================
    ; Get element attribute
    ; selector  - CSS selector
    ; attribute - attribute name e.g. "href", "src"
    ; ================================================
    GetAttr(selector, attribute) {
        js := '
        (
            (function() {
                var el = document.querySelector("' selector '");
                if (!el) return "not found: ' selector '";
                return el.getAttribute("' attribute '") || "";
            })()
        )'
        return this.Eval(js)
    }

    ; ================================================
    ; Wait for element to appear (polls every 500ms)
    ; selector - CSS selector
    ; timeout  - ms to wait (default 10000)
    ; ================================================
    WaitForElement(selector, timeout := 10000) {
        deadline := A_TickCount + timeout
        loop {
            result := this.Eval('document.querySelector("' selector '") ? "found" : "not found"')
            if result = "found"
                return true
            if A_TickCount > deadline
                return false
            Sleep 500
        }
    }

    ; ================================================
    ; Navigate to URL
    ; url     - full URL to navigate to
    ; waitMs  - ms to wait after navigation (default 2000)
    ; ================================================
    Navigate(url, waitMs := 2000) {
        this.Eval('window.location.href = "' url '"')
        Sleep waitMs
    }

    ; ================================================
    ; Scroll page
    ; x - horizontal scroll (default 0)
    ; y - vertical scroll
    ; ================================================
    ScrollTo(x := 0, y := 0) {
        this.Eval('window.scrollTo(' x ', ' y ')')
    }

    ScrollBy(x := 0, y := 500) {
        this.Eval('window.scrollBy(' x ', ' y ')')
    }

    ScrollToBottom() {
        this.Eval('window.scrollTo(0, document.body.scrollHeight)')
    }

    ScrollToTop() {
        this.Eval('window.scrollTo(0, 0)')
    }

    ; ================================================
    ; Get page info
    ; ================================================
    GetTitle() {
        return this.Eval("document.title")
    }

    GetURL() {
        return this.Eval("document.URL")
    }

    GetHTML() {
        return this.Eval("document.documentElement.outerHTML")
    }

    GetBodyText() {
        return this.Eval("document.body.innerText")
    }

    ; ================================================
    ; Enable CDP domains
    ; ================================================
    EnableRuntime() {
        id := this.Send("Runtime.enable")
        Sleep 200
        this.DrainFrames()
    }

    EnablePage() {
        id := this.Send("Page.enable")
        Sleep 200
        this.DrainFrames()
    }

    EnableDOM() {
        id := this.Send("DOM.enable")
        Sleep 200
        this.DrainFrames()
    }

    ; Enable all domains at once
    EnableAll() {
        this.Send("Runtime.enable")
        this.Send("Page.enable")
        this.Send("DOM.enable")
        Sleep 500
        this.DrainFrames()
    }

    ; ================================================
    ; Take screenshot - returns base64 PNG string
    ; ================================================
    Screenshot() {
        this.Send("Page.enable")
        Sleep 200

        this.msgId++
        id := this.msgId
        json := '{"id":' id ',"method":"Page.captureScreenshot","params":{"format":"png"}}'
        this.sock.SendFrame(json)

        deadline := A_TickCount + 10000
        loop {
            this.DrainFrames()
            if this.responses.Has(id) {
                data := this.responses[id]
                this.responses.Delete(id)
                if data.Has("result") && data["result"].Has("data")
                    return data["result"]["data"]
                return ""
            }
            if A_TickCount > deadline
                return "TIMEOUT"
            Sleep 30
        }
    }

    ; ================================================
    ; Save screenshot to file
    ; filepath - full path e.g. "C:\screenshot.png"
    ; ================================================
    SaveScreenshot(filepath) {
        b64 := this.Screenshot()
        if b64 = "" || b64 = "TIMEOUT"
            return false

        ; Decode base64 to file
        CRYPT_STRING_BASE64 := 0x00000001
        DllCall("Crypt32\CryptStringToBinary",
            "Str",  b64,
            "UInt", 0,
            "UInt", CRYPT_STRING_BASE64,
            "Ptr",  0,
            "UInt*", &size := 0,
            "Ptr",  0,
            "Ptr",  0)

        buf := Buffer(size)
        DllCall("Crypt32\CryptStringToBinary",
            "Str",  b64,
            "UInt", 0,
            "UInt", CRYPT_STRING_BASE64,
            "Ptr",  buf,
            "UInt*", &size,
            "Ptr",  0,
            "Ptr",  0)

        f := FileOpen(filepath, "w")
        f.RawWrite(buf, size)
        f.Close()
        return true
    }

    ; ================================================
    ; Drain all available WebSocket frames
    ; ================================================
    DrainFrames() {
        loop 100 {
            raw := this.sock.RecvRaw(65536, true)
            if !raw || !InStr(Type(raw), "Buffer") || raw.Size < 2
                break

            offset := 0
            loop {
                if offset >= raw.Size
                    break

                frameLen := this.GetFrameLen(raw, offset)
                if frameLen <= 0 || offset + frameLen > raw.Size
                    break

                frameBuf := Buffer(frameLen, 0)
                DllCall("RtlMoveMemory",
                    "Ptr",  frameBuf,
                    "Ptr",  raw.Ptr + offset,
                    "UInt", frameLen)

                payload := this.ParseFrame(frameBuf)
                if payload {
                    try {
                        msg := Jxon_Load(&payload)
                        if msg.Has("id")
                            this.responses[msg["id"]] := msg
                    } catch {
                        ; Skip malformed JSON
                    }
                }

                offset += frameLen
            }
        }
    }

    ; ================================================
    ; Internal - Get total WebSocket frame length
    ; ================================================
    GetFrameLen(buf, offset := 0) {
        if buf.Size < offset + 2
            return 0

        b1      := NumGet(buf, offset + 1, "UChar")
        masked  := (b1 & 0x80) >> 7
        payLen  := b1 & 0x7F
        hdrSize := 2

        if payLen = 126 {
            if buf.Size < offset + 4
                return 0
            payLen  := (NumGet(buf, offset + 2, "UChar") << 8)
                     |  NumGet(buf, offset + 3, "UChar")
            hdrSize := 4
        } else if payLen = 127 {
            hdrSize := 10
            payLen  := 0
            loop 8
                payLen := (payLen << 8) | NumGet(buf, offset + 1 + A_Index, "UChar")
        }

        if masked
            hdrSize += 4

        return hdrSize + payLen
    }

    ; ================================================
    ; Internal - Parse WebSocket frame → JSON string
    ; ================================================
    ParseFrame(buf, offset := 0) {
        if buf.Size < offset + 2
            return ""

        b1      := NumGet(buf, offset + 1, "UChar")
        masked  := (b1 & 0x80) >> 7
        payLen  := b1 & 0x7F
        hdrSize := 2

        if payLen = 126 {
            if buf.Size < offset + 4
                return ""
            payLen  := (NumGet(buf, offset + 2, "UChar") << 8)
                     |  NumGet(buf, offset + 3, "UChar")
            hdrSize := 4
        } else if payLen = 127 {
            hdrSize := 10
            payLen  := 0
            loop 8
                payLen := (payLen << 8) | NumGet(buf, offset + 1 + A_Index, "UChar")
        }

        if masked
            hdrSize += 4

        if buf.Size < offset + hdrSize + payLen
            return ""

        return StrGet(buf.Ptr + offset + hdrSize, payLen, "UTF-8")
    }

    ; ================================================
    ; Internal - Extract value from CDP response
    ; ================================================
    ExtractValue(data) {
        if !data.Has("result")
            return ""

        res := data["result"]

        if res is Map && res.Count = 0
            return ""

        if res.Has("exceptionDetails") {
            ex := res["exceptionDetails"]
            return "JS Error: " ex["text"]
        }

        if !res.Has("result")
            return ""

        inner := res["result"]

        if inner.Has("value")
            return String(inner["value"])

        if inner.Has("description")
            return inner["description"]

        return ""
    }

    ; ================================================
    ; Internal - JSON helpers
    ; ================================================
    MapToJson(obj) {
        if !(obj is Map)
            return this.JsonValue(obj)

        out   := "{"
        first := true
        for k, v in obj {
            if !first
                out .= ","
            out   .= '"' k '":' this.JsonValue(v)
            first := false
        }
        return out "}"
    }

    JsonValue(v) {
        if v is Map
            return this.MapToJson(v)
        if v is Integer
            return String(v)
        if v is Float
            return String(v)
        if v = true  || v = "true"
            return "true"
        if v = false || v = "false"
            return "false"
        return this.JsonString(String(v))
    }

    JsonString(str) {
        str := StrReplace(str, "\",  "\\")
        str := StrReplace(str, '"',  '\"')
        str := StrReplace(str, "`n", "\n")
        str := StrReplace(str, "`r", "\r")
        str := StrReplace(str, "`t", "\t")
        return '"' str '"'
    }

    ; ================================================
    ; Close connection
    ; ================================================
    Close() {
        if this.sock
            this.sock.Close()
        this.connected := false
    }

    __Delete() {
        this.Close()
    }
}

; ================================================
; _CDPSocket - Internal socket class
; (prefixed with _ to avoid name conflicts)
; ================================================
class _CDPSocket {

    __New() {
        wsaData := Buffer(408, 0)
        if DllCall("ws2_32\WSAStartup", "UShort", 0x0202, "Ptr", wsaData) != 0
            throw Error("WSAStartup failed")

        this.ptr := DllCall("ws2_32\socket",
            "Int", 2,
            "Int", 1,
            "Int", 6,
            "Ptr")

        if this.ptr = -1
            throw Error("socket() failed")
    }

    Connect(host, port) {
        hostent := DllCall("ws2_32\gethostbyname", "AStr", host, "Ptr")
        if !hostent {
            err := DllCall("ws2_32\WSAGetLastError", "Int")
            throw Error("gethostbyname failed. WSA Error: " err)
        }

        addrList := NumGet(hostent + A_PtrSize * 3, "Ptr")
        addrPtr  := NumGet(addrList, "Ptr")
        ip       := NumGet(addrPtr, "UInt")

        sa := Buffer(16, 0)
        NumPut("UShort", 2, sa, 0)
        NumPut("UShort", DllCall("ws2_32\htons",
            "UShort", port, "UShort"), sa, 2)
        NumPut("UInt", ip, sa, 4)

        if DllCall("ws2_32\connect",
            "Ptr", this.ptr,
            "Ptr", sa,
            "Int", 16,
            "Int") = -1 {
            err := DllCall("ws2_32\WSAGetLastError", "Int")
            throw Error("connect() failed. WSA Error: " err "`n"
                . "10061 = Chrome not running`n"
                . "10060 = Timeout`n"
                . "11001 = Host not found")
        }
    }

    SendRaw(str) {
        buf := Buffer(StrPut(str, "UTF-8"), 0)
        StrPut(str, buf, "UTF-8")
        size := buf.Size - 1
        DllCall("ws2_32\send",
            "Ptr", this.ptr,
            "Ptr", buf,
            "Int", size,
            "Int", 0)
    }

    SendFrame(json) {
        payBuf := Buffer(StrPut(json, "UTF-8"), 0)
        StrPut(json, payBuf, "UTF-8")
        payLen := payBuf.Size - 1

        headerSize := 6
        if payLen >= 126 && payLen <= 65535
            headerSize += 2
        else if payLen > 65535
            headerSize += 8

        frame  := Buffer(headerSize + payLen, 0)
        offset := 0

        NumPut("UChar", 0x81, frame, offset)
        offset += 1

        if payLen < 126 {
            NumPut("UChar", 0x80 | payLen, frame, offset)
            offset += 1
        } else if payLen <= 65535 {
            NumPut("UChar", 0x80 | 126,           frame, offset)
            NumPut("UChar", (payLen >> 8) & 0xFF,  frame, offset + 1)
            NumPut("UChar",  payLen & 0xFF,         frame, offset + 2)
            offset += 3
        } else {
            NumPut("UChar", 0x80 | 127, frame, offset)
            loop 8
                NumPut("UChar", (payLen >> ((8 - A_Index) * 8)) & 0xFF,
                    frame, offset + A_Index)
            offset += 9
        }

        mask := []
        loop 4 {
            m := Random(0, 255)
            mask.Push(m)
            NumPut("UChar", m, frame, offset)
            offset += 1
        }

        loop payLen {
            i := A_Index - 1
            b := NumGet(payBuf, i, "UChar") ^ mask[Mod(i, 4) + 1]
            NumPut("UChar", b, frame, offset + i)
        }

        DllCall("ws2_32\send",
            "Ptr", this.ptr,
            "Ptr", frame,
            "Int", frame.Size,
            "Int", 0)
    }

    RecvRaw(maxLen := 65536, nonBlocking := false) {
        if nonBlocking {
            mode := Buffer(4, 0)
            NumPut("UInt", 1, mode)
            DllCall("ws2_32\ioctlsocket",
                "Ptr",  this.ptr,
                "UInt", 0x8004667E,
                "Ptr",  mode)
        }

        buf := Buffer(maxLen, 0)
        len := DllCall("ws2_32\recv",
            "Ptr", this.ptr,
            "Ptr", buf,
            "Int", maxLen,
            "Int", 0,
            "Int")

        if nonBlocking {
            mode := Buffer(4, 0)
            NumPut("UInt", 0, mode)
            DllCall("ws2_32\ioctlsocket",
                "Ptr",  this.ptr,
                "UInt", 0x8004667E,
                "Ptr",  mode)
        }

        if len <= 0
            return ""

        result := Buffer(len, 0)
        DllCall("RtlMoveMemory",
            "Ptr",  result,
            "Ptr",  buf,
            "UInt", len)
        return result
    }

    Close() {
        DllCall("ws2_32\closesocket", "Ptr", this.ptr)
        DllCall("ws2_32\WSACleanup")
    }

    __Delete() {
        this.Close()
    }
}
