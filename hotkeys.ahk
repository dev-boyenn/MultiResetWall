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
  ; ::ToggleThin()

  ; ==== SCROLL BACKGROUND RESETTING ====
  ; *WheelUp::BgScrollBackward() ; Scrolls backward one
  ; *WheelDown::BgScrollForward() ; Scrolls forward one, resetting the highest instance that just left the view
  ; *F21::BgLock() ; Locks the middle instance
  ; ==== GRID BACKGROUND RESETTING ====
  ; For Grid background resetting, set index to position in grid. add true if you want it to also reset all other grid instances
  ; ::LockInstanceByGridIndex(1,true)
  ; ::ResetGridInstances()
}
return

#If WinActive("Fullscreen Projector") || WinActive("Full-screen Projector")
{
  *E::ResetHoveredInstance() ; Resets the instance currently mouse hovered over, even when locked
  *R::SwitchToHoveredInstance() ; Plays instance
  *T::ResetGridInstances()
  +LButton::LockHoveredInstance()

  Tab:: ; Strongly recommended when using instance moving
  +Tab::
    ResetGridInstances()
    PlayNextLock()
  return

  *F::FocusResetHoveredInstance()
}