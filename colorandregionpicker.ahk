#Requires AutoHotkey v2.0

    ; Hotkey to save mouse position
    F3::
    {
        MouseGetPos(&mouseX, &mouseY)
        
        ; Ajustar las coordenadas a números pares
        If (Mod(mouseX, 2) != 0) {
            mouseX := mouseX + 1
        }
        If (Mod(mouseY, 2) != 0) {
            mouseY := mouseY + 1
        }
        
        mouseColor := PixelGetColor(mouseX, mouseY, "RGB")
        FileAppend("Mouse position: X" (mouseX/2) " Y" (mouseY/2) "`nColor at this position: " mouseColor "`n", "mouse.txt")
        ToolTip("Mouse information saved in mouse.txt")
        SetTimer(() => ToolTip(), -3000)  ; Hide the ToolTip after 3 seconds
    }