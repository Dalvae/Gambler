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

antiAFKInterval := 120000
lastMoveTime := 0

global isActive := false
global isActionInProgress := false
global lastActionTime := 0
global lastRollDiceTime := 0
global rollDiceCooldown := 5000 

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
    global isActive
    isActive := !isActive
    if (isActive)
    {
        SetTimer(CheckColorAndPerformAction, 1000)
        ShowTooltip("Script activated", 3000)
    }
    else
    {
        SetTimer(CheckColorAndPerformAction, 0)
        ShowTooltip("Script deactivated", 3000)
    }
}


CheckColorAndPerformAction() {
    global isActive, isActionInProgress, wowid1, lastActionTime, lastRollDiceTime, rollDiceCooldown
    
    if (!isActive || isActionInProgress || !WinActive("ahk_id " wowid1))
        return

    isActionInProgress := true

    try {
        ; Adjust coordinates based on current resolution
        adjColor := AdjustCoordinates(ColorX, ColorY)
        adjClick := AdjustCoordinates(ClickX, ClickY)
        adjDenyTradeButton := AdjustCoordinates(DenyTradeButtonX, DenyTradeButtonY)
        adjTradeButton := AdjustCoordinates(TradeButtonX, TradeButtonY)
        adjActive := AdjustCoordinates(ActiveCordsX, ActiveCordsY)
        adjRollDice := AdjustCoordinates(RollDiceCordsX, RollDiceCordsY)
        adjTradeWindow := AdjustCoordinates(TradeWindowColorX, TradeWindowColorY)

        ; Check for warning color accept Warning after trade accept (highest priority)
        ActualColor := PixelGetColor(adjColor.x, adjColor.y, "RGB")

        currentTime := A_TickCount
        if (currentTime - lastActionTime < 3000) {
            return
        }
        if IsColorSimilar(ActualColor, ColorWarning, 15) {
            PerformAction(adjClick.x, adjClick.y, "AcceptWarning")
        }
        ; Check for red color Deny Trades (second priority)
        else {
            DenyTradeColor := PixelGetColor(adjTradeWindow.x, adjTradeWindow.y, "RGB")
            if IsColorSimilar(DenyTradeColor, NoTradeWindowColor, 20) {
                PerformAction(adjDenyTradeButton.x, adjDenyTradeButton.y, "DenyTrade")
            }
            ; Check for green color Accept trades(third priority)
            else {
                TradeWindowActualColor := PixelGetColor(adjTradeWindow.x, adjTradeWindow.y, "RGB")
                if IsColorSimilar(TradeWindowActualColor, TradeWindowColor, 20) {             
                    PerformAction(adjTradeButton.x, adjTradeButton.y, "AcceptTrade")
                }
                ; Check for Active Gamble purple color (fourth priority) to Roll the dice
                else {
                    ActiveGambleColor := PixelGetColor(adjActive.x, adjActive.y, "RGB")
                    if IsColorSimilar(ActiveGambleColor, ColorActiveGamble, 20) {
                        PerformAction(adjRollDice.x, adjRollDice.y, "RollDice")
                        lastRollDiceTime := currentTime
                    }
                    ; Anti-AFK movement (lowest priority)
                    else {
                        PerformAntiAFK()
                    } 
                }
            }
        }
    }
    catch as err {
        ShowTooltip("Error: " . err.Message, 5000)
    }
    finally {
        isActionInProgress := false
    }
}

PerformAction(x, y, action := "") {
    switch action {
        case "RollDice":
            ShowTooltip("Rolling Dice")
            MouseMove(x, y)
            Sleep(Random(100, 300))
            Click()
            lastActionTime := A_TickCount
            lastRollDiceTime := A_TickCount
        case "AcceptWarning":
            ShowTooltip("Accepting Warning")
            MouseMove(x, y)
            Sleep(Random(100, 300))
            Click()
            lastActionTime := A_TickCount
        case "DenyTrade":
            ShowTooltip("Denying Trade")
            MouseMove(x, y)
            Sleep(Random(100, 300))
            Click()
            lastActionTime := A_TickCount
        case "AcceptTrade":
            ShowTooltip("Accepting Trade")
            MouseMove(x, y)
            Sleep(Random(100, 300))
            Click()
            lastActionTime := A_TickCount
        default:
            MouseMove(x, y)
            Sleep(Random(100, 300))
            Click()
            lastActionTime := A_TickCount
    }
}

PerformAntiAFK() {
    global lastMoveTime, antiAFKInterval
    currentTime := A_TickCount
    if (currentTime - lastMoveTime > antiAFKInterval) {
        randomAction := Random(1, 4)
        
        MovementAction(key1, key2) {
            movementDuration := Random(100, 300)
            Send("{" . key1 . " down}")
            Sleep(movementDuration)
            Send("{" . key1 . " up}")
            Sleep(Random(50, 150))  ; Short pause between movements
            Send("{" . key2 . " down}")
            Sleep(movementDuration)  ; Use the same duration for the reverse movement
            Send("{" . key2 . " up}")
        }

        Switch randomAction {
            Case 1: MovementAction("W", "S")
            Case 2: MovementAction("A", "D")
            Case 3: MovementAction("S", "W")
            Case 4: MovementAction("D", "A")
        }

        Sleep(Random(50, 150))  ; Short pause before jumping
        Send("{Space}")  ; Jump after movement
        lastMoveTime := currentTime
        ShowTooltip("Anti-AFK Movement")
    }
}


#HotIf