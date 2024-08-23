    ; Get the ID of the World of Warcraft window
    wowid1 := WinGetID("World of Warcraft")

    #HotIf WinActive("ahk_id " wowid1)

    ; Global variables declaration
    global isActive := false
    global isActionInProgress := false
    global lastActionTime := 0
    global lastRollDiceTime := 0
    global rollDiceCooldown := 5000 
    global lastMoveTime := 0
    global antiAFKInterval := 120000


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
    TradeWindowColor := 0x00FF00
    NoTradeWindowColor := 0xFF0000
    TradeButtonX := 286
    TradeButtonY := 685
    DenyTradeButtonX := 444
    DenyTradeButtonY := 161

    ColorActiveGamble := 0xCC00CC
    ActiveCordsX := 1410
    ActiveCordsY := 430
    RollDiceCordsX := 1470
    RollDiceCordsY := 575



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
            SetTimer(PerformAntiAFK, 0)  ; Stop anti-AFK timer
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
                            PerformAction(0, 0, "RollDice")  ; Coordinates are not used for RollDice anymore
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
        global lastActionTime, lastRollDiceTime, isActive
        
        if (!isActive)
            return
    
        switch action {
            case "RollDice":
                ShowTooltip("Rolling Dice")
                Sleep(Random(1500, 3000))  ; Random delay between 1 and 2 seconds
                Send("{6}")  ; Send the '6' key
                lastActionTime := A_TickCount
                lastRollDiceTime := A_TickCount
            case "AcceptWarning", "DenyTrade", "AcceptTrade":
                SmoothMouseMove(x, y)
                Sleep(Random(300, 700))
                if (!isActive)
                    return
                ShowTooltip(action)
                Click()
                lastActionTime := A_TickCount
            default:
                SmoothMouseMove(x, y)
                Sleep(Random(15, 35))
                if (!isActive)
                    return
                Click()
                lastActionTime := A_TickCount
        }
        
        Sleep(Random(15, 35))
    }

    SmoothMouseMove(targetX, targetY)
    {
        MouseGetPos(&startX, &startY)
        
        distance := Sqrt((targetX - startX) ** 2 + (targetY - startY) ** 2)
        
        if (distance < 20) {
            MouseMove(targetX, targetY, 0)
            return
        }
        
        steps := Max(Floor(distance / 20), 3) 
        
        controlX := startX + (targetX - startX) / 2 + Random(-10, 10)
        controlY := startY + (targetY - startY) / 2 + Random(-10, 10)
        
        Loop steps {
            if (!isActive)
                return
            t := A_Index / steps
            newX := Round((1-t)**2 * startX + 2*(1-t)*t * controlX + t**2 * targetX)
            newY := Round((1-t)**2 * startY + 2*(1-t)*t * controlY + t**2 * targetY)
            MouseMove(newX, newY, 0)
            if (A_Index < steps)
                Sleep(1)  
        }
        
        MouseMove(targetX, targetY, 0)
    }
    

    PerformAntiAFK() {
        global lastMoveTime, antiAFKInterval, isActive
        if (!isActive)
            return

        currentTime := A_TickCount
        if (currentTime - lastMoveTime > antiAFKInterval) {
            randomAction := Random(1, 4)
            
            MovementAction(key1, key2) {
                if (!isActive)
                    return
                movementDuration := Random(100, 300)
                Send("{" . key1 . " down}")
                Sleep(movementDuration)
                Send("{" . key1 . " up}")
                Sleep(Random(50, 150))
                Send("{" . key2 . " down}")
                Sleep(movementDuration) 
                Send("{" . key2 . " up}")
            }

            Switch randomAction {
                Case 1: MovementAction("W", "S")
                Case 2: MovementAction("A", "D")
                Case 3: MovementAction("S", "W")
                Case 4: MovementAction("D", "A")
            }

            if (isActive) {
                Sleep(Random(50, 150))  
                Send("{Space}")  
                lastMoveTime := currentTime
                ShowTooltip("Anti-AFK Movement")
            }
        }
    }

    #HotIf