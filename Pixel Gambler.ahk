; Get the ID of the World of Warcraft window
wowid1 := WinGetID("World of Warcraft")

#HotIf WinActive("ahk_id " wowid1)

; Add tooltip function
ShowTooltip(message, duration := 2000) {
    ToolTip(message)
    SetTimer(() => ToolTip(), -duration)
}

IsColorSimilar(color1, color2, tolerance := 10) {
    r1 := (color1 >> 16) & 0xFF
    g1 := (color1 >> 8) & 0xFF
    b1 := color1 & 0xFF
    r2 := (color2 >> 16) & 0xFF
    g2 := (color2 >> 8) & 0xFF
    b2 := color2 & 0xFF

    return (Abs(r1 - r2) <= tolerance) && (Abs(g1 - g2) <= tolerance) && (Abs(b1 - b2) <= tolerance)
}

; Configuration variables
ColorX := 729
ColorY := 237          
ClickX := 845
ClickY := 268
ColorWarning := 0xDB9C15

TradeWindowColorX := 478
TradeWindowColorY := 430
TradeWindowColor := 0x10DA12
NoTradeWindowColor := 0xDD0F12
TradeButtonX := 286
TradeButtonY := 685
DenyTradeButtonX := 444
DenyTradeButtonY := 161

ColorActiveGamble := 0xCC00CC
ActiveCordsX := 1410
ActiveCordsY := 430
RollDiceCordsX := 1470
RollDiceCordsY := 575

antiAFKInterval := 300000
lastMoveTime := 0

AdjustCoordinates(x, y) {
    originalWidth := 1920
    originalHeight := 1080
    screenWidth := A_ScreenWidth
    screenHeight := A_ScreenHeight
    adjX := x * (screenWidth / originalWidth)
    adjY := y * (screenHeight / originalHeight)
    return {x: adjX, y: adjY}
}

F3::
{
    static isActive := false
    if (isActive := !isActive)
    {
        SetTimer(CheckColorAndPerformAction, 1000)
        ToolTip("Script activated")
        SetTimer(() => ToolTip(), -3000)
    }
    else
    {
        SetTimer(CheckColorAndPerformAction, 0)
        ToolTip("Script deactivated")
        SetTimer(() => ToolTip(), -3000)
    }
}

CheckColorAndPerformAction() {
    ; Adjust coordinates based on current resolution
    adjColor := AdjustCoordinates(ColorX, ColorY)
    adjClick := AdjustCoordinates(ClickX, ClickY)
    adjDenyTradeButton := AdjustCoordinates(DenyTradeButtonX, DenyTradeButtonY)
    adjTradeButton := AdjustCoordinates(TradeButtonX, TradeButtonY)
    adjActive := AdjustCoordinates(ActiveCordsX, ActiveCordsY)
    adjRollDice := AdjustCoordinates(RollDiceCordsX, RollDiceCordsY)
    adjTradeWindow := AdjustCoordinates(TradeWindowColorX, TradeWindowColorY)

    ; Check for warning color (highest priority)
    ActualColor := PixelGetColor(adjColor.x, adjColor.y, "RGB")
    if IsColorSimilar(ActualColor, ColorWarning, 15) {
        PerformAction(adjClick.x, adjClick.y)
        ShowTooltip("Acepting Warning")
    }
    ; Check for red color (second priority)
    else {
        
        DenyTradeColor := PixelGetColor(adjTradeWindow.x, adjTradeWindow.y, "RGB")
        if IsColorSimilar(DenyTradeColor, NoTradeWindowColor, 20) {
            PerformAction(adjDenyTradeButton.x, adjDenyTradeButton.y)
            ShowTooltip("Denaying Trade")
        }
        ; Check for green color (third priority)
        else {
            TradeWindowActualColor := PixelGetColor(adjTradeWindow.x, adjTradeWindow.y, "RGB")
            if IsColorSimilar(TradeWindowActualColor, TradeWindowColor, 20) {             
                PerformAction(adjTradeButton.x, adjTradeButton.y)
                ShowTooltip("Acepting Trade")
            }
            ; Check for Active Gamble purple color (fourth priority) to Roll the dice
            else {
                ActiveGambleColor := PixelGetColor(adjActive.x, adjActive.y, "RGB")
                if IsColorSimilar(ActiveGambleColor, ColorActiveGamble, 15) {
                    PerformAction(adjRollDice.x, adjRollDice.y)
                    ShowTooltip("Rolling Dice")
                }
                ; Anti-AFK movement (lowest priority)
                else {
                    PerformAntiAFK()
                }
            }
        }
    }
}

PerformAction(x, y) {
    MouseMove(x, y)
    Sleep(Random(100, 300))  ; Reduced delay range
    Click
    ; Sleep(500)  ; Added cooldown after action
}

PerformAntiAFK() {
    global lastMoveTime, antiAFKInterval
    currentTime := A_TickCount
    if (currentTime - lastMoveTime > antiAFKInterval) {
        Send("{Left down}")
        Sleep(10)
        Send("{Left up}")
        Sleep(500)
        Send("{Right down}")
        Sleep(10)
        Send("{Right up}")
        lastMoveTime := currentTime
    }
}

SetTimer(CheckColorAndPerformAction, 1000)  ; Changed to 1000ms interval

#HotIf