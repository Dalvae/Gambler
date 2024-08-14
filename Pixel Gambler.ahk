; Get the ID of the World of Warcraft window
wowid1 := WinGetID("World of Warcraft")

#HotIf WinActive("ahk_id " wowid1)

IsColorSimilar(color1, color2, tolerance := 10) {
    r1 := (color1 >> 16) & 0xFF
    g1 := (color1 >> 8) & 0xFF
    b1 := color1 & 0xFF
    r2 := (color2 >> 16) & 0xFF
    g2 := (color2 >> 8) & 0xFF
    b2 := color2 & 0xFF

    return (Abs(r1 - r2) <= tolerance) && (Abs(g1 - g2) <= tolerance) && (Abs(b1 - b2) <= tolerance)
}

; For accepting a trade
ColorX := 729
ColorY := 237          
ClickX := 845
ClickY := 268
ColorWarning := 0xDB9C15   ; Warning color

; For checking if the trade window is open
TradeWindowColorX := 478
TradeWindowColorY := 430
TradeWindowColor := 0x10DA12  ; Green
NoTradeWindowColor := 0xDD0F12 ; Red
TradeButtonX := 286
TradeButtonY := 685
DenyTradeButtonX := 444
DenyTradeButtonY := 161

; For Active Gambler
ColorActiveGamble := 0xCC00CC ; Purple
ActiveCordsX := 1410
ActiveCordsY := 430 ; Coordinates of Active Gamble
RollDiceCordsX := 1470
RollDiceCordsY := 575 ; Where to click if the color is Active Gamble

; Variables for anti-AFK
antiAFKInterval := 300000  ; 5-minute interval for anti-AFK
lastMoveTime := 0

; Function to adjust coordinates based on screen resolution ratio
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
        SetTimer(() => ToolTip(), -3000)  ; Remove tooltip after 3 seconds
    }
    else
    {
        SetTimer(CheckColorAndPerformAction, 0)  ; Turn off the timer
        ToolTip("Script deactivated")
        SetTimer(() => ToolTip(), -3000)  ; Remove tooltip after 3 seconds
    }
}

CheckColorAndPerformAction() {
    global ColorX, ColorY, ColorWarning, ClickX, ClickY, lastMoveTime, antiAFKInterval, wowid1, ColorActiveGamble, ActiveCordsX, ActiveCordsY, RollDiceCordsX, RollDiceCordsY, TradeWindowColorX, TradeWindowColorY, TradeWindowColor, NoTradeWindowColor, TradeButtonX, TradeButtonY, DenyTradeButtonX, DenyTradeButtonY

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
        MouseMove(adjClick.x, adjClick.y)
        Sleep(Random(200, 1200))  
        Click
    }
    ; Check for red color (second priority)
    else {
        DenyTradeColor := PixelGetColor(adjTradeWindow.x, adjTradeWindow.y, "RGB")
        if isColorSimilar(DenyTradeColor, NoTradeWindowColor, 20){
            MouseMove(adjDenyTradeButton.x, adjDenyTradeButton.y)
            Sleep(Random(100, 700))
            Click
        }
        ; Check for green color (third priority)
        else {
            TradeWindowActualColor := PixelGetColor(adjTradeWindow.x, adjTradeWindow.y, "RGB")
            if IsColorSimilar(TradeWindowActualColor, TradeWindowColor, 20) {             
                    MouseMove(adjTradeButton.x, adjTradeButton.y)
                    Sleep(Random(100, 700))  
                    Click
            }
            ; Check for Active Gamble purple color (fourth priority) to Roll the dice
            else {
                ActiveGambleColor := PixelGetColor(adjActive.x, adjActive.y, "RGB")
                if IsColorSimilar(ActiveGambleColor, ColorActiveGamble, 15) {
                    RandomSleep := Random(100, 700)
                    MouseMove(adjRollDice.x, adjRollDice.y)
                    Sleep(RandomSleep)
                    Click
                    ToolTip("Rolled dice. Sleep: " RandomSleep " ms")
                    SetTimer(() => ToolTip(), -3000) 
                }
                ; Anti-AFK movement (lowest priority)
                else {
                    currentTime := A_TickCount
                    if (currentTime - lastMoveTime > antiAFKInterval) {
                        Send("{Left down}")
                        Sleep(10)
                        Send("{Left up}")
                        Sleep(1000)
                        Send("{Right down}")
                        Sleep(10)
                        Send("{Right up}")
                        lastMoveTime := currentTime
                    }
                }
            }
        }
    }
}

SetTimer(CheckColorAndPerformAction, 50)

#HotIf