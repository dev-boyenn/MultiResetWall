; v1.0
RAlt::Suspend ; Pause all macros
^LAlt:: ; Reload if macro locks up
  Reload
return
#If WinActive("Minecraft") && (WinActive("ahk_exe javaw.exe") || WinActive("ahk_exe java.exe"))
{
  *U:: ExitWorld() ; Reset
  *CapsLock:: TinderMotion(True) ; Bg left swipe (reset)
  *+CapsLock:: TinderMotion(False) ; Bg right swipe (keep)

  ; Utility (Remove semicolon ';' and set a hotkey)
  ; ::WideHardo()
  ; ::OpenToLAN()
  ; ::GoToNether()
  ; ::OpenToLANAndGoToNether()
  ; ::CheckFourQuadrants("fortress")
  ; ::CheckFourQuadrants("bastion_remnant")
  ; ::CheckFor("buried_treasure")
}
return

#If WinActive("Fullscreen Projector") || WinActive("Full-screen Projector")
{
  *E Up::
    hoveredIndex:=GetHoveredInstanceIndex()
    inst := inMemoryInstances[hoveredIndex]

    if (!inst.IsLocked()){
      SwapWithOldest(hoveredIndex)
    } else {
      MoveLast(hoveredIndex)
    }
    inst.Reset()
    NotifyObs()
    return
;  *E::GetHoveredInstance().Reset(False) ; drag reset to ignore locked instances
;  *R::SwitchInstance(MousePosToInstNumber())
;  *F::FocusReset(MousePosToInstNumber())
  *T::ResetAll()
  LButton::
    hoveredIndex:=GetHoveredInstanceIndex()
    inst := inMemoryInstances[hoveredIndex]
    if (inst.IsLocked()){
      return
    }
    SwapWithFirstPassive(hoveredIndex)
    inst.Lock() ; lock an instance so the above "blanket reset" functions don't reset it
    NotifyObs()
    return
  RButton::
    hoveredIndex:=GetHoveredInstanceIndex()
    inst := inMemoryInstances[hoveredIndex]

    if (!inst.IsLocked()){
      SwapWithOldest(hoveredIndex)
    } else {
      MoveLast(hoveredIndex)
    }
    inst.Reset()
    NotifyObs()
    return
  ; Optional (Remove semicolon ';' and set a hotkey)
  Tab::
  +Tab::
    ResetAll()
    PlayNextLock()
    return
  ; Reset keys (1-9)
*1::
  ResetInstance(1)
return
*2::
  ResetInstance(2)
return
*3::
  ResetInstance(3)
return
*4::
  ResetInstance(4)
return
*5::
  ResetInstance(5)
return
*6::
  ResetInstance(6)
return
*7::
  ResetInstance(7)
return
*8::
  ResetInstance(8)
return
*9::
  ResetInstance(9)
return

; Switch to instance keys (Shift + 1-9)
*+1::
  SwitchInstance(1)
return
*+2::
  SwitchInstance(2)
return
*+3::
  SwitchInstance(3)
return
*+4::
  SwitchInstance(4)
return
*+5::
  SwitchInstance(5)
return
*+6::
  SwitchInstance(6)
return
*+7::
  SwitchInstance(7)
return
*+8::
  SwitchInstance(8)
return
*+9::
  SwitchInstance(9)
return
}