# AHK Chrome Automation

A powerful AutoHotkey v2 **tool** and **library** for automating Chrome browser using Chrome DevTools Protocol (CDP). Execute JavaScript, extract data, fill forms, and automate web tasks. Includes both a **standalone GUI application** and a **library for custom scripts**.

## ✨ Features

- 🎯 **Easy Connection** - Connect to any Chrome tab by title
- ⚡ **JavaScript Execution** - Run sync and async JavaScript directly
- 🔄 **Real-time Control** - Fill forms, click buttons, extract data
- 💾 **CSV Export** - Save extracted data as CSV files
- 🎨 **User-Friendly GUI** - Simple interface with output preview
- 🔌 **Library Integration** - Use in your own AHK scripts
- 🔗 **Pure WebSocket** - Direct CDP communication,
- 🚀 **Fast & Lightweight** - Native Windows automation
- ✅ **Framework Support** - Works with React, Angular, Vue apps

## 🎯 Use Cases

- Web scraping and data extraction
- Form automation (Ticket Booking sites, Bill of Material Extraction, Purchase Request and etc.)
- Testing and QA automation
- Repetitive task automation
- Browser interaction scripting
- Data collection and analysis
- Custom hotkey-based automation

## 🚀 Two Ways to Use

### 1️⃣ Standalone GUI Application

Perfect for quick tasks and testing:

1. Launch Chrome in debug mode: `chrome.exe --remote-debugging-port=9222`
2. Run `ChromeCDP_GUI_Final.ahk`
3. Enter tab title (e.g., "Google", "github")
4. Click Connect (F9)
5. Write JavaScript and execute (F10)

### 2️⃣ Library Integration (For Custom Scripts)

Integrate the library into your own AutoHotkey scripts:
```ahk
#Include JXON.ahk
#Include WebSocket_Chrome.ahk

; Example 1: Simple automation with hotkey
F9:: {
    }

## 📚 Library API Reference

### Connection
```ahk
cdp := WebSocket_Chrome(port := 9222, tabIndex := 1, tabTitle := "")
cdp.EnableAll()                    ; Enable all CDP domains
cdp.ActivateTab()                  ; Bring tab to front
cdp.VerifyConnection()             ; Check if still connected
```

### JavaScript Execution
```ahk
cdp.Eval(jsCode, timeout := 5000)           ; Sync JavaScript
cdp.EvalAsync(jsCode, timeout := 15000)     ; Async JavaScript (await support)
cdp.RunJS(filepath, timeout := 30000)       ; Run JS from file (auto-detects async)
```

## 💡 Real-World Examples

### Web Scraping with Hotkey
```ahk
#Include WebSocket_Chrome.ahk

F9:: {
    cdp := WebSocket_Chrome(9222, 1, "Amazon")
    cdp.EnableAll()
    
    js := "
    (
        [...document.querySelectorAll('.product-item')]
            .map(el => ({
                name: el.querySelector('.product-title').textContent,
                price: el.querySelector('.product-price').textContent
            }))
    )"
    
    result := cdp.Eval(js)
    FileAppend(result, "products.json", "UTF-8")
    MsgBox("Scraped products saved!")
}
```


### Periodic Data Collection
```ahk
SetTimer CollectData, 300000  ; Every 5 minutes

CollectData() {
    cdp := WebSocket_Chrome(9222, 1, "Dashboard")
    cdp.EnableAll()
    
    data := cdp.Eval("document.querySelector('#stats').textContent")
    
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    FileAppend(timestamp " - " data "`n", "log.txt", "UTF-8")
}
```

### Multi-Tab Automation


## 🛠️ Installation

### For GUI Application
1. Download all files to a folder
2. Ensure you have:
   - `ChromeCDP_GUI_Final.ahk` (GUI)
   - `WebSocket_Chrome.ahk` (Library)
   - `JXON.ahk` ([Download here](https://github.com/TheArkive/JXON_ahk2))
3. Run `ChromeCDP_GUI_Final.ahk`

### For Custom Scripts
1. Copy `WebSocket_Chrome.ahk` and `JXON.ahk` to your script folder
2. Include them in your script:
```ahk
   #Include JXON.ahk
   #Include WebSocket_Chrome.ahk
```
3. Start automating!

## 📋 Prerequisites

- **AutoHotkey v2** - [Download](https://www.autohotkey.com/v2/)
- **Chrome Browser**
- **Windows OS**

## 🚦 Quick Start (Library)
```ahk
#Requires AutoHotkey v2
#Include JXON.ahk
#Include WebSocket_Chrome.ahk

; Launch Chrome in debug mode first:
; chrome.exe --remote-debugging-port=9222

F9:: {
    ; Connect to Chrome tab
    cdp := WebSocket_Chrome(9222, 1, "Google")
    cdp.EnableAll()
    
    ; Execute JavaScript
    result := cdp.Eval("document.title")
    MsgBox("Page title: " result)
}
```

## 💻 GUI Features

- **F8** - Verify connection
- **F9** - Connect to Chrome tab
- **F10** - Run JavaScript (Sync)
- **Ctrl+F10** - Run JavaScript (Async)
- **Ctrl+S** - Save output as CSV
- **Ctrl+L** - Clear output
- **Ctrl+Q** - Quit

## 📝 Example JavaScript Files

**extract_links.js:**
```javascript
(() => {
    let links = [...document.querySelectorAll('a')]
        .filter(a => a.href && a.textContent.trim() !== "")
        .map(a => {
            let text = a.textContent.trim().replace(/"/g, '""');
            return `"${text}","${a.href}"`;
        });
    return "Text,URL\n" + links.join("\n");
})();
```

**fill_form.js:**
```javascript
(async function() {
    const sleep = (ms) => new Promise(r => setTimeout(r, ms));
    
    document.querySelector('#username').value = 'myuser';
    await sleep(500);
    
    document.querySelector('#password').value = 'mypass';
    await sleep(500);
    
    document.querySelector('#submit').click();
    return 'Form submitted!';
})();
```

## 🎓 Use Cases

### ✅ Perfect For:
- Developers automating browser tasks
- QA testers running repetitive tests
- Data analysts scraping web data
- Power users automating workflows
- Anyone tired of manual browser tasks

### ❌ Not Suitable For:
- Large-scale distributed scraping
- Situations requiring IP rotation
- Headless browser requirements (use Puppeteer/Playwright)
- Cross-platform automation (Windows only)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License.

## 🙏 Credits

- **Chrome DevTools Protocol** - [CDP Documentation](https://chromedevtools.github.io/devtools-protocol/)
- **JXON.ahk** - [TheArkive](https://github.com/TheArkive/JXON_ahk2)
- **AutoHotkey v2** - [Official Site](https://www.autohotkey.com/)

## ⭐ Show Your Support

If this tool helped you, please ⭐ star this repository!

---

**Made with ❤️ using AutoHotkey v2**
