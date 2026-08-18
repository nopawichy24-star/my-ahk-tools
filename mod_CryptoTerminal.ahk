; mod_CryptoTerminal.ahk
#Requires AutoHotkey v2.0

; ============================================================
; KHAO CRYPTO TERMINAL V2
; AHK v2 / single-file module
; Trigger:
;   - Triple tap Q quickly
;   - Ctrl + Alt + T
; ============================================================

; ----------------------------
; GLOBAL STATE
; ----------------------------
global CT := Map()

CT["tapCount"]           := 0
CT["lastTap"]            := 0
CT["tapWindow"]          := 420

CT["panelShown"]         := false
CT["widgetShown"]        := false
CT["alertsEnabled"]      := false

CT["refreshMs"] := 2000
CT["cacheMs"]   := 8000
CT["alertMs"]   := 10000

CT["panelGui"]           := 0
CT["widgetGui"]          := 0
CT["toolsGui"]           := 0
CT["advancedGui"]        := 0
CT["proGui"]             := 0
CT["coinListGui"]        := 0
CT["alertsGui"]          := 0
CT["whaleGui"]           := 0
CT["liqGui"]             := 0

CT["widgetHwnd"]         := 0
CT["widgetWidth"]        := 180
CT["widgetX"]            := ""
CT["widgetY"]            := ""

CT["lastData"]           := Map()
CT["history"]            := Map()
CT["alertRules"]         := []

CT["iniPath"]            := A_ScriptDir "\CryptoTerminal.ini"

; widget controls
CT["ctrl"]               := Map()

; ----------------------------
; PUBLIC INIT
; ----------------------------
CryptoTerminal_Init() {
    Hotkey("^!t", CT_OpenPanel)
    OnMessage(0x201, CT_DragWidget) ; WM_LBUTTONDOWN
}

; ----------------------------
; HOTKEY: Triple tap Q
; ----------------------------
~q::
{
    global CT
    now := A_TickCount

    if (now - CT["lastTap"] <= CT["tapWindow"])
        CT["tapCount"] += 1
    else
        CT["tapCount"] := 1

    CT["lastTap"] := now

    if (CT["tapCount"] >= 3) {
        CT["tapCount"] := 0
        CT_OpenPanel()
    }
}

; ============================================================
; PANEL
; ============================================================
CT_OpenPanel(*) {
    global CT

    if (CT["panelShown"]) {
        try CT["panelGui"].Destroy()
        CT["panelShown"] := false
        return
    }

    g := Gui("+AlwaysOnTop +ToolWindow", "KHAO TERMINAL")
    CT_ApplyTheme(g, 10)

    g.MarginX := 14
    g.MarginY := 12

    g.AddText("w170 Center", "╭─ 📊 KHAO TERMINAL ─╮")
    g.AddText("w170 Center", "เลือกสิ่งที่ต้องการเปิด")
    g.AddText("w170 Center", "╰──────────────────╯")
    g.AddText("w170", "")

    b1 := g.AddButton("w170 h30", "📊 Market Widget")
    b2 := g.AddButton("w170 h30", "📈 Crypto Tools")
    b3 := g.AddButton("w170 h30", "🧠 Advanced Crypto")
    b4 := g.AddButton("w170 h30", "🐋 Pro Market Data")
    b5 := g.AddButton("w170 h30", CT["alertsEnabled"] ? "🔔 Price Alerts (ON)" : "🔔 Price Alerts (OFF)")
    b6 := g.AddButton("w170 h30", "❌ Close")

    b1.OnEvent("Click", (*) => CT_ToggleWidget())
    b2.OnEvent("Click", (*) => CT_OpenCryptoTools())
    b3.OnEvent("Click", (*) => CT_OpenAdvanced())
    b4.OnEvent("Click", (*) => CT_OpenPro())
    b5.OnEvent("Click", (*) => CT_ToggleAlerts(b5))
    b6.OnEvent("Click", (*) => CT_ClosePanel())

    g.OnEvent("Close", (*) => CT_ClosePanel())
    g.OnEvent("Escape", (*) => CT_ClosePanel())

    g.Show("AutoSize")
    CT["panelGui"] := g
    CT["panelShown"] := true
}

CT_ClosePanel() {
    global CT
    try CT["panelGui"].Destroy()
    CT["panelShown"] := false
}

; ============================================================
; WIDGET
; ============================================================
CT_ToggleWidget() {
    global CT
    if (CT["widgetShown"])
        CT_StopWidget()
    else
        CT_StartWidget()
}

CT_StartWidget() {
    global CT

    if (CT["widgetShown"])
        return

    g := Gui("+AlwaysOnTop -Caption +ToolWindow", "MARKET")
    g.BackColor := "1E1E1E"
    g.SetFont("s9 cFFFFFF", "Segoe UI")
    g.MarginX := 10
    g.MarginY := 8

    CT["ctrl"] := Map()

    CT["ctrl"]["title"] := g.AddText("w170 Center", "╭─ 📊 MARKET ─────────────╮")

    CT["ctrl"]["btc"]      := g.AddText("w170", "🟠 BTC  loading...")
    CT["ctrl"]["btcSpark"] := g.AddText("w170 cAFAFAF", "▁▁▁▁▁")

    CT["ctrl"]["eth"]      := g.AddText("w170", "🔵 ETH  loading...")
    CT["ctrl"]["ethSpark"] := g.AddText("w170 cAFAFAF", "▁▁▁▁▁")

    CT["ctrl"]["sol"]      := g.AddText("w170", "🟣 SOL  loading...")
    CT["ctrl"]["solSpark"] := g.AddText("w170 cAFAFAF", "▁▁▁▁▁")

    g.AddText("w170", "")

    CT["ctrl"]["gold"] := g.AddText("w170", "🥇 GOLD  loading...")
    CT["ctrl"]["jpy"]  := g.AddText("w170", "💴 JPY/THB  loading...")
    CT["ctrl"]["usd"]  := g.AddText("w170", "💵 USD/JPY  loading...")
    CT["ctrl"]["mcap"] := g.AddText("w170", "💰 TOTAL MCAP  loading...")

    g.AddText("w170", "")

    b1 := g.AddButton("w170 h26", "📈 Open Tools")
    b2 := g.AddButton("w170 h26", "🔔 Alerts")
    b3 := g.AddButton("w170 h26", "❌ Close Widget")

    b1.OnEvent("Click", (*) => CT_OpenCryptoTools())
    b2.OnEvent("Click", (*) => CT_OpenAlertsManager())
    b3.OnEvent("Click", (*) => CT_StopWidget())

    CT["ctrl"]["footer"] := g.AddText("w170 Center", "╰───────────────────────╯")

    WinSetTransparent(238, g)

    pos := CT_GetSavedWidgetPos()
    x := pos.Has("x") ? pos["x"] : ""
    y := pos.Has("y") ? pos["y"] : ""

    if (x = "" || y = "") {
        MonitorGetWorkArea(1, &left, &top, &right, &bottom)

        widgetWidth := CT["widgetWidth"]

        x := right - widgetWidth - 40
        y := top + 40
    }

    g.Show("x" x " y" y " w" CT["widgetWidth"] " NoActivate")
    OnMessage(0x201, CT_WidgetDrag)
    CT["widgetGui"] := g
    CT["widgetShown"] := true
    CT["widgetHwnd"] := g.Hwnd

    g.OnEvent("Close", (*) => CT_StopWidget())
    g.OnEvent("Escape", (*) => CT_StopWidget())

    CT_UpdateWidget()
    SetTimer(CT_UpdateWidget, CT["refreshMs"])
}

CT_WidgetDrag(wParam, lParam, msg, hwnd)
{
    static WM_NCLBUTTONDOWN := 0xA1
    static HTCAPTION := 2

    PostMessage(WM_NCLBUTTONDOWN, HTCAPTION,,, "A")
}

CT_StopWidget() {
    global CT

    SetTimer(CT_UpdateWidget, 0)

    if (CT["widgetShown"]) {
        CT_SaveWidgetPos()
        try CT["widgetGui"].Destroy()
    }

    CT["widgetShown"] := false
    CT["widgetHwnd"] := 0
}

CT_DragWidget(wParam, lParam, msg, hwnd) {
    global CT
    if (!CT["widgetShown"])
        return

    if (hwnd != CT["widgetHwnd"])
        return

    ; drag only widget window
    PostMessage(0xA1, 2,,, "ahk_id " hwnd) ; WM_NCLBUTTONDOWN / HTCAPTION
}

CT_SaveWidgetPos() {
    global CT
    if (!CT["widgetShown"])
        return

    try {
        WinGetPos(&x, &y, &w, &h, CT["widgetGui"])
        IniWrite(x, CT["iniPath"], "Widget", "X")
        IniWrite(y, CT["iniPath"], "Widget", "Y")
    }
}

CT_GetSavedWidgetPos() {
    global CT
    m := Map()

    try {
        x := IniRead(CT["iniPath"], "Widget", "X", "")
        y := IniRead(CT["iniPath"], "Widget", "Y", "")
        if (x != "")
            m["x"] := Integer(x)
        if (y != "")
            m["y"] := Integer(y)
    }

    return m
}

CT_GetPrimaryWorkArea() {
    idx := MonitorGetPrimary()
    MonitorGetWorkArea(idx, &l, &t, &r, &b)
    return Map("left", l, "top", t, "right", r, "bottom", b)
}

; ============================================================
; UPDATE + RENDER
; ============================================================
CT_UpdateWidget(*) {
    global CT

    if (!CT["widgetShown"])
        return

    data := CT_GetMarketData()

    CT_RenderLine("btc",  "🟠 BTC",     data["btc"],     0, "USD")
    CT_RenderLine("eth",  "🔵 ETH",     data["eth"],     0, "USD")
    CT_RenderLine("sol",  "🟣 SOL",     data["sol"],     0, "USD")
    CT_RenderLine("gold", "🥇 GOLD",    data["gold"],    2, "USD")
    CT_RenderLine("jpy",  "💴 JPY/THB", data["jpythb"],  4, "")
    CT_RenderLine("usd",  "💵 USD/JPY", data["usdjpy"],  2, "")

    sparkBTC := CT_UpdateHistoryAndSpark("btc", data["btc"])
    sparkETH := CT_UpdateHistoryAndSpark("eth", data["eth"])
    sparkSOL := CT_UpdateHistoryAndSpark("sol", data["sol"])

    CT["ctrl"]["btcSpark"].Text := "   " sparkBTC
    CT["ctrl"]["ethSpark"].Text := "   " sparkETH
    CT["ctrl"]["solSpark"].Text := "   " sparkSOL

    CT["ctrl"]["mcap"].Text := "💰 TOTAL MCAP  " CT_FormatTrillions(data["total_mcap"])

    ; update title timestamp subtly
    CT["ctrl"]["title"].Text := "╭─ 📊 MARKET  " FormatTime(, "HH:mm:ss") " ───────────╮"
}

CT_RenderLine(key, label, value, decimals := 0, currency := "") {
    global CT

    ctrlKey := key
    prevMap := CT["lastData"]
prevVal := prevMap.Has(key) ? prevMap[key] : value

; ensure openPrice map exists
if !CT.Has("openPrice")
    CT["openPrice"] := Map()

; set open price once
if !CT["openPrice"].Has(key)
    CT["openPrice"][key] := value

open := CT["openPrice"][key]

    percent := 0
    if (open != 0)
        percent := ((value - open) / open) * 100

    pctText := (percent >= 0)
        ? " +" Round(percent,2) "%"
        : " " Round(percent,2) "%"

    ; ---------- PRICE DIRECTION ----------
    arrow := "⚪—"
    color := "FFFFFF"

    if (value > prevVal) {
        arrow := "🟢▲"
        color := "7CFC90"
    } else if (value < prevVal) {
        arrow := "🔴▼"
        color := "FF8A8A"
    }

    prevMap[key] := value

    formatted := CT_FormatNumber(value, decimals)

    line := (currency = "USD")
        ? label "  $" formatted "  " pctText "  " arrow
        : label "  " formatted "  " pctText "  " arrow

    if CT["ctrl"].Has(ctrlKey) && IsObject(CT["ctrl"][ctrlKey]) {

        ctrl := CT["ctrl"][ctrlKey]

        ctrl.Text := line

        ; ---------- COLOR BASED ON DAILY % ----------
        if (percent > 0)
            CT_FlashControl(ctrl, "7CFC90")
        else if (percent < 0)
            CT_FlashControl(ctrl, "FF8A8A")
    }
}

CT_FlashControl(ctrl, color) {
    try ctrl.Opt("c" color)
    SetTimer(CT_ResetControlColor.Bind(ctrl), -700)
}

CT_ResetControlColor(ctrl) {
    try ctrl.Opt("cFFFFFF")
}

CT_Sparkline(arr) {

    bars := ["▁","▂","▃","▄","▅","▆","▇","█"]

    if (arr.Length = 0)
        return "▁▁▁▁▁▁▁▁▁▁▁"

    min := arr[1]
    max := arr[1]

    for v in arr {
        if v < min
            min := v
        if v > max
            max := v
    }

    range := max - min

    ; ป้องกันกราฟหายเมื่อค่าซ้ำ
    if (range = 0)
        return "▅▅▅▅▅"

    out := ""

    for v in arr {

        idx := Floor(((v - min) / range) * 7) + 1

        if (idx < 1)
            idx := 1
        if (idx > 8)
            idx := 8

        out .= bars[idx]
    }

    return out
}

; ============================================================
; HISTORY + SPARK
; ============================================================
CT_UpdateHistoryAndSpark(key, value) {
    global CT

    if !CT["history"].Has(key)
        CT["history"][key] := []

    hist := CT["history"][key]
    hist.Push(value)

    ; เก็บย้อนหลังสูงสุด 11 จุด เพื่อให้ตรงกับ sparkline ที่แสดง
    while (hist.Length > 11)
        hist.RemoveAt(1)

    return CT_Sparkline(hist)
}

; ============================================================
; DATA FETCH
; ============================================================

CT_GetMarketData() {

    data := Map()

    try {

        btcJson := CT_HTTP("https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT")
        ethJson := CT_HTTP("https://api.binance.com/api/v3/ticker/price?symbol=ETHUSDT")
        solJson := CT_HTTP("https://api.binance.com/api/v3/ticker/price?symbol=SOLUSDT")

        globalJson := CT_HTTP("https://api.coingecko.com/api/v3/global")
        fx := CT_HTTP("https://api.frankfurter.dev/v1/latest?base=USD&symbols=JPY,THB")
        gold := CT_HTTP("https://api.gold-api.com/price/XAU")

        btc := CT_JsonPrice(btcJson)
        eth := CT_JsonPrice(ethJson)
        sol := CT_JsonPrice(solJson)

        usdJpy := CT_JsonSimpleNumber(fx, "JPY")
        usdThb := CT_JsonSimpleNumber(fx, "THB")
        jpyThb := (usdJpy != 0) ? (usdThb / usdJpy) : 0

        goldPrice := CT_JsonSimpleNumber(gold, "price")
        totalMcap := CT_JsonGlobalMarketCap(globalJson)

        data["btc"] := btc
        data["eth"] := eth
        data["sol"] := sol
        data["gold"] := goldPrice
        data["jpythb"] := jpyThb
        data["usdjpy"] := usdJpy
        data["total_mcap"] := totalMcap

    } catch {

        data["btc"] := 0
        data["eth"] := 0
        data["sol"] := 0
        data["gold"] := 0
        data["jpythb"] := 0
        data["usdjpy"] := 0
        data["total_mcap"] := 0

    }

    return data
}

CT_JsonPrice(json)
{
    m := []
    if RegExMatch(json, '"price":"([0-9\.]+)"', &m)
        return m[1] + 0
    return 0
}

CT_HTTP(url) {
    http := ComObject("WinHttp.WinHttpRequest.5.1")
    http.Open("GET", url, true)
    http.SetRequestHeader("User-Agent", "Mozilla/5.0")
    http.Send()
    http.WaitForResponse(10)
    return http.ResponseText
}

CT_JsonNestedNumber(json, rootKey, subKey) {
    pat := '"' rootKey '".*?"' subKey '":\s*(-?[0-9]+(?:\.[0-9]+)?)'
    m := []
    if RegExMatch(json, pat, &m)
        return m[1] + 0
    return 0
}

CT_JsonSimpleNumber(json, key) {
    pat := '"' key '":\s*(-?[0-9]+(?:\.[0-9]+)?)'
    m := []
    if RegExMatch(json, pat, &m)
        return m[1] + 0
    return 0
}

CT_JsonGlobalMarketCap(json) {
    pat := '"total_market_cap"\s*:\s*\{.*?"usd"\s*:\s*([0-9]+(?:\.[0-9]+)?)'
    m := []
    if RegExMatch(json, pat, &m)
        return m[1] + 0
    return 0
}

CT_FormatNumber(n, decimals := 0)
{
    if !IsNumber(n)
        return n

    if (decimals = 0)
        return Round(n)

    if (decimals = 2)
        return Round(n, 2)

    if (decimals = 4)
        return Round(n, 4)

    return n
}

CT_FormatTrillions(n) {
    if (n >= 1000000000000)
        return Round(n / 1000000000000, 2) "T"
    if (n >= 1000000000)
        return Round(n / 1000000000, 2) "B"
    return CT_FormatNumber(n, 0)
}

; ============================================================
; CRYPTO TOOLS
; ============================================================
CT_OpenCryptoTools() {
    global CT

    try CT["toolsGui"].Destroy()

    g := Gui("+AlwaysOnTop +ToolWindow", "📈 Crypto Tools")
    CT_ApplyTheme(g, 10)
    g.MarginX := 12
    g.MarginY := 10

    g.AddText("w170 Center", "📈 Crypto Tools")
    g.AddText("w170", "")

    g.AddButton("w170 h26", "📈 TradingView BTC").OnEvent("Click", (*) => Run("https://www.tradingview.com/chart/?symbol=BINANCE:BTCUSDT"))
    g.AddButton("w170 h26", "📈 TradingView ETH").OnEvent("Click", (*) => Run("https://www.tradingview.com/chart/?symbol=BINANCE:ETHUSDT"))
    g.AddButton("w170 h26", "📈 TradingView SOL").OnEvent("Click", (*) => Run("https://www.tradingview.com/chart/?symbol=BINANCE:SOLUSDT"))
    g.AddButton("w170 h26", "🥇 TradingView GOLD").OnEvent("Click", (*) => Run("https://www.tradingview.com/chart/?symbol=TVC:GOLD"))

    g.AddText("w170", "")
    g.AddButton("w170 h26", "🔎 Coin Search").OnEvent("Click", (*) => CT_CoinSearch())
    g.AddButton("w170 h26", "📋 Coin List (20)").OnEvent("Click", (*) => CT_OpenCoinList())
    g.AddButton("w170 h26", "📊 Refresh Widget Now").OnEvent("Click", (*) => CT_UpdateWidget())

    g.AddText("w170", "")
    g.AddButton("w170 h26", "❌ Close").OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize")
    CT["toolsGui"] := g
}

CT_CoinSearch() {
    ib := InputBox("พิมพ์สัญลักษณ์ เช่น BTC, ETH, SOL, ARB", "🔎 Coin Search", "w360 h130")
    if (ib.Result != "OK")
        return

    sym := Trim(StrUpper(ib.Value))
    if (sym = "")
        return

    Run("https://www.tradingview.com/chart/?symbol=BINANCE:" sym "USDT")
}

CT_OpenCoinList() {
    global CT

    try CT["coinListGui"].Destroy()

    coins := [
        "BTC","ETH","SOL","BNB","XRP","ADA","DOGE","AVAX","DOT","MATIC"
      , "LINK","TRX","LTC","BCH","ATOM","UNI","ETC","FIL","APT","ARB"
    ]

    g := Gui("+AlwaysOnTop +ToolWindow", "📋 Coin List")
    CT_ApplyTheme(g, 10)
    g.MarginX := 10
    g.MarginY := 10

    g.AddText("w170 Center", "📋 Coin List (20)")
    g.AddText("w170", "")

    rowCount := 0
    for _, sym in coins {
        btn := g.AddButton("w150 h28", "📈 " sym)
        btn.OnEvent("Click", CT_OpenCoinChart.Bind(sym))

        rowCount += 1
        if (Mod(rowCount, 2) = 1)
            g.AddText("x+6 yp", "")
        else
            g.AddText("xs", "")
    }

    g.AddText("w170", "")
    g.AddButton("w170 h26", "❌ Close").OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize")
    CT["coinListGui"] := g
}

CT_OpenCoinChart(sym, *) {
    Run("https://www.tradingview.com/chart/?symbol=BINANCE:" sym "USDT")
}

; ============================================================
; ADVANCED
; ============================================================
CT_OpenAdvanced() {
    global CT

    try CT["advancedGui"].Destroy()

    g := Gui("+AlwaysOnTop +ToolWindow", "🧠 Advanced Crypto")
    CT_ApplyTheme(g, 10)
    g.MarginX := 12
    g.MarginY := 10

    g.AddText("w170 Center", "🧠 Advanced Crypto")
    g.AddText("w170", "")

    g.AddButton("w170 h26", "📈 BTC Fear & Greed").OnEvent("Click", (*) => Run("https://alternative.me/crypto/fear-and-greed-index/"))
    g.AddButton("w170 h26", "📊 Funding Rate").OnEvent("Click", (*) => Run("https://www.coinglass.com/FundingRate"))
    g.AddButton("w170 h26", "🧠 Crypto News Feed").OnEvent("Click", (*) => Run("https://cryptopanic.com/"))
    g.AddButton("w170 h26", "🔔 Manage Price Alerts").OnEvent("Click", (*) => CT_OpenAlertsManager())

    g.AddText("w170", "")
    g.AddButton("w170 h26", "❌ Close").OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize")
    CT["advancedGui"] := g
}

; ============================================================
; PRO MARKET
; ============================================================
CT_OpenPro() {
    global CT

    try CT["proGui"].Destroy()

    g := Gui("+AlwaysOnTop +ToolWindow", "🐋 Pro Market Data")
    CT_ApplyTheme(g, 10)
    g.MarginX := 12
    g.MarginY := 10

    g.AddText("w170 Center", "🐋 Pro Market Data")
    g.AddText("w170", "")

    g.AddButton("w170 h26", "💰 Total Crypto Market Cap").OnEvent("Click", (*) => CT_ShowMarketCapPopup())
    g.AddButton("w170 h26", "🐋 Whale Alert Popup").OnEvent("Click", (*) => CT_OpenWhalePopup())
    g.AddButton("w170 h26", "📉 Liquidation Tracker").OnEvent("Click", (*) => CT_OpenLiquidationPopup())
    g.AddButton("w170 h26", "📊 BTC Dominance Chart").OnEvent("Click", (*) => Run("https://www.tradingview.com/chart/?symbol=CRYPTOCAP:BTC.D"))
    g.AddButton("w170 h50", "📊 Orderbook Snapshot (BTCUSDT)").OnEvent("Click", (*) => Run("https://www.coinglass.com/OrderBook"))

    g.AddText("w170", "")
    g.AddButton("w170 h26", "❌ Close").OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize")
    CT["proGui"] := g
}

CT_ShowMarketCapPopup() {
    data := CT_GetMarketData()
    MsgBox("💰 Total Crypto Market Cap`n`n" CT_FormatTrillions(data["total_mcap"]), "Market Cap")
}

CT_OpenWhalePopup() {
    global CT

    try CT["whaleGui"].Destroy()

    g := Gui("+AlwaysOnTop +ToolWindow", "🐋 Whale Alert")
    CT_ApplyTheme(g, 10)
    g.MarginX := 12
    g.MarginY := 10

    g.AddText("w170 Center", "🐋 Whale Alert Popup")
    g.AddText("w170", "เปิดเครื่องมือ whale tracking ที่ใช้บ่อย")
    g.AddText("w170", "")

    g.AddButton("w170 h26", "🐋 Whale Alert").OnEvent("Click", (*) => Run("https://whale-alert.io/"))
    g.AddButton("w170 h26", "🛰 Arkham Intel").OnEvent("Click", (*) => Run("https://platform.arkhamintelligence.com/"))
    g.AddButton("w170 h26", "⛓ Mempool").OnEvent("Click", (*) => Run("https://mempool.space/"))
    g.AddButton("w170 h26", "❌ Close").OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize")
    CT["whaleGui"] := g

    TrayTip("🐋 Whale Alert", "Whale tools opened from popup.", 2)
}

CT_OpenLiquidationPopup() {
    global CT

    try CT["liqGui"].Destroy()

    g := Gui("+AlwaysOnTop +ToolWindow", "📉 Liquidation Tracker")
    CT_ApplyTheme(g, 10)
    g.MarginX := 12
    g.MarginY := 10

    g.AddText("w170 Center", "📉 Liquidation Tracker")
    g.AddText("w170", "เปิดหน้าติดตาม liquidation / heatmap")
    g.AddText("w170", "")

    g.AddButton("w170 h26", "📉 CoinGlass Liquidation").OnEvent("Click", (*) => Run("https://www.coinglass.com/LiquidationData"))
    g.AddButton("w170 h26", "🔥 CoinGlass Heatmap").OnEvent("Click", (*) => Run("https://www.coinglass.com/pro/futures/LiquidationHeatMap"))
    g.AddButton("w170 h26", "📚 Binance Depth / Order Book").OnEvent("Click", (*) => Run("https://developers.binance.com/docs/derivatives/usds-margined-futures/market-data/websocket-api"))
    g.AddButton("w170 h26", "❌ Close").OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize")
    CT["liqGui"] := g

    TrayTip("📉 Liquidation Tracker", "Liquidation tools opened from popup.", 2)
}

; ============================================================
; ALERTS
; ============================================================
CT_ToggleAlerts(btnCtrl := 0) {
    global CT

    CT["alertsEnabled"] := !CT["alertsEnabled"]

    if (CT["alertsEnabled"]) {
        SetTimer(CT_CheckAlerts, CT["alertMs"])
        TrayTip("🔔 Price Alerts", "Alerts ON", 2)
    } else {
        SetTimer(CT_CheckAlerts, 0)
        TrayTip("🔕 Price Alerts", "Alerts OFF", 2)
    }

    if IsObject(btnCtrl)
        btnCtrl.Text := CT["alertsEnabled"] ? "🔔 Price Alerts (ON)" : "🔔 Price Alerts (OFF)"
}

CT_OpenAlertsManager() {
    global CT

    try CT["alertsGui"].Destroy()

    g := Gui("+AlwaysOnTop +ToolWindow", "🔔 Price Alerts")
    CT_ApplyTheme(g, 10)
    g.MarginX := 12
    g.MarginY := 10

    g.AddText("w170 Center", "🔔 Price Alerts")
    g.AddText("w170", "ตัวอย่าง: BTC > 70000")
    g.AddText("w170", "ตัวอย่าง: ETH < 3500")
    g.AddText("w170", "")

    rulesText := "Current rules:`n"
    if (CT["alertRules"].Length = 0) {
        rulesText .= "- none -"
    } else {
        for idx, rule in CT["alertRules"]
            rulesText .= idx ". " rule["sym"] " " rule["op"] " " rule["price"] "`n"
    }

    g.AddEdit("w170 r8 ReadOnly", rulesText)
    g.AddText("w170", "")

    g.AddButton("w170 h26", "➕ Add Rule").OnEvent("Click", (*) => CT_AddAlertRule())
    g.AddButton("w170 h26", CT["alertsEnabled"] ? "🔕 Turn Alerts OFF" : "🔔 Turn Alerts ON").OnEvent("Click", (*) => CT_ToggleAlerts())
    g.AddButton("w170 h26", "🧹 Clear All Rules").OnEvent("Click", (*) => CT_ClearAlertRules())
    g.AddButton("w170 h26", "❌ Close").OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize")
    CT["alertsGui"] := g
}

CT_AddAlertRule() {
    global CT

    ib := InputBox("ใส่กฎ เช่น BTC > 70000 หรือ ETH < 3200", "➕ Add Alert Rule", "w380 h130")
    if (ib.Result != "OK")
        return

    line := Trim(StrUpper(ib.Value))
    if (line = "")
        return

    m := []
    if !RegExMatch(line, "^\s*([A-Z0-9]+)\s*([<>])\s*([0-9]+(?:\.[0-9]+)?)\s*$", &m) {
        MsgBox("รูปแบบไม่ถูกต้อง`nตัวอย่าง: BTC > 70000", "Error")
        return
    }

    CT["alertRules"].Push(Map(
        "sym", m[1],
        "op", m[2],
        "price", m[3] + 0,
        "fired", false
    ))

    TrayTip("✅ Alert Added", m[1] " " m[2] " " m[3], 2)
}

CT_ClearAlertRules() {
    global CT
    CT["alertRules"] := []
    TrayTip("🧹 Alerts", "All rules cleared.", 2)
}

CT_CheckAlerts(*) {
    global CT

    if (!CT["alertsEnabled"])
        return
    if (CT["alertRules"].Length = 0)
        return

    data := CT_GetMarketData()
    prices := Map(
        "BTC", data["btc"],
        "ETH", data["eth"],
        "SOL", data["sol"]
    )

    for _, rule in CT["alertRules"] {
        sym := rule["sym"]
        if !prices.Has(sym)
            continue

        cur := prices[sym]
        target := rule["price"]
        op := rule["op"]

        hit := false
        if (op = ">" && cur > target)
            hit := true
        else if (op = "<" && cur < target)
            hit := true

        if (hit && !rule["fired"]) {
            rule["fired"] := true
            CT_AlertPopup(sym, op, target, cur)
        } else if (!hit && rule["fired"]) {
            rule["fired"] := false
        }
    }
}

CT_AlertPopup(sym, op, target, cur) {
    TrayTip("🔔 " sym " ALERT", sym " " op " " target "`nCurrent: " CT_FormatNumber(cur, 0), 4)
    SoundBeep(880, 140)
}

; ============================================================
; UI HELPER
; ============================================================
CT_ApplyTheme(g, fontSize := 10) {
    g.BackColor := "1E1E1E"
    g.SetFont("s" fontSize " cFFFFFF", "Segoe UI")
}