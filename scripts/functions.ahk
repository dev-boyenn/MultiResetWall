; v1.0

; TEMP hotkey section for pre WallManager OOP approach to help with hotkeys
LockInstanceByGridIndex(gridIndex, resetRestOfGrid:=false){
    inst := inMemoryInstances[gridIndex]
    if (inst.IsLocked()){
      return
    }
    SwapWithFirstPassive(gridIndex)
    inst.Lock() ; lock an instance so the above "blanket reset" functions don't reset it
    NotifyObs()

    if (resetRestOfGrid){
      ResetGridInstances()
    }
    return
}

LockHoveredInstance(){
    hoveredIndex:=GetHoveredInstanceIndex()
    inst := inMemoryInstances[hoveredIndex]
    if (inst.IsLocked()){
      return
    }
    SwapWithFirstPassive(hoveredIndex)
    inst.Lock() ; lock an instance so the above "blanket reset" functions don't reset it
    NotifyObs()
    return
}

SwitchToHoveredInstance(){
  hoveredIndex:=GetHoveredInstanceIndex()
  inst := inMemoryInstances[hoveredIndex]
  SwitchInstance(inst.GetInstanceNum()) 
  if (inst.IsLocked()){
    return
  }
  SwapWithFirstPassive(hoveredIndex)
  inst.Lock() 
  NotifyObs()
}

ResetHoveredInstance(){
  hoveredIndex:=GetHoveredInstanceIndex()
    inst := inMemoryInstances[hoveredIndex]

    if (!inst.IsLocked()){
      SwapWithOldest(hoveredIndex)
    } else {
      if (GetGridUsageInstancecount() < GetWantedGridInstanceCount()) {
        Swap(inMemoryInstances, hoveredIndex,GetGridUsageInstancecount()+1)
      } else {
        MoveLast(hoveredIndex)
      }
    }
    inst.Reset()
    NotifyObs()
    return
}

FocusResetHoveredInstance() {
  SwitchToHoveredInstance()
  ResetGridInstances()
}

; Reset all instances
ResetGridInstances() {
  loop, % GetGridUsageInstancecount() {
    inst := inMemoryInstances[A_Index]
    inst.Reset(bypassLock)
    SwapWithOldest(A_Index)
  }
  NotifyObs()
}

; END temp hotkey section
SendLog(lvlText, msg, tickCount) {
  file := FileOpen("data/log.log", "a -rw")
  if (!IsObject(file)) {
    logQueue := Func("SendLog").Bind(lvlText, msg, tickCount)
    SetTimer, %logQueue%, -10
    return
  }
  file.Close()
  FileAppend, [%tickCount%] [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] [SYS-%lvlText%] %msg%`n, data/log.log
}

CountAttempts() {
  file := overallAttemptsFile
  FileRead, WorldNumber, %file%
  if (ErrorLevel)
    WorldNumber := resets
  else
    FileDelete, %file%
  WorldNumber += resets
  FileAppend, %WorldNumber%, %file%
  file := dailyAttemptsFile
  FileRead, WorldNumber, %file%
  if (ErrorLevel)
    WorldNumber := resets
  else
    FileDelete, %file%
  WorldNumber += resets
  FileAppend, %WorldNumber%, %file%
  resets := 0
}

FindBypassInstance() {
  activeNum := GetActiveInstanceNum()
  for i, inst in inMemoryInstances {
    if (FileExist(inst.GetIdleFile()) && inst.IsLocked() && inst.GetInstanceNum() != activeNum)
      return inst.GetInstanceNum()
  }
  
  return -1
}

TinderMotion(swipeLeft) {
  ; To reimplement / replace with smarter background resetting
  ; ; left = reset, right = keep
  ; if !tinder
  ;   return
  ; if swipeLeft
  ;   ResetInstance(currBg)
  ; else
  ;   LockInstance(currBg)
  ; newBg := GetFirstBgInstance(currBg)
  ; SendLog(LOG_LEVEL_INFO, Format("Tinder motion occurred with old instance {1} and new instance {2}", currBg, newBg), A_TickCount)
  ; currBg := newBg
}

GetFirstBgInstance(toSkip := -1, skip := false) {
  if !tinder
    return 0
  if skip
    return -1
  activeNum := GetActiveInstanceNum()
  for i, mcdir in McDirectories {
    hold := mcdir . "hold.tmp"
    if (i != activeNum && i != toSkip && !FileExist(hold) && !locked[i]) {
      FileDelete,data/bg.txt
      FileAppend,%i%,data/bg.txt
      return i
    }
  }
  needBgCheck := true
  return -1
}



RunHide(Command)
{
  dhw := A_DetectHiddenWindows
  DetectHiddenWindows, On
  Run, %ComSpec%,, Hide, cPid
  WinWait, ahk_pid %cPid%
  DetectHiddenWindows, %dhw%
  DllCall("AttachConsole", "uint", cPid)

  Shell := ComObjCreate("WScript.Shell")
  Exec := Shell.Exec(Command)
  Result := Exec.StdOut.ReadAll()

  DllCall("FreeConsole")
  Process, Close, %cPid%
  Return Result
}

GetMcDir(pid)
{
  command := Format("powershell.exe $x = Get-WmiObject Win32_Process -Filter \""ProcessId = {1}\""; $x.CommandLine", pid)
  rawOut := RunHide(command)
  if (InStr(rawOut, "--gameDir")) {
    strStart := RegExMatch(rawOut, "P)--gameDir (?:""(.+?)""|([^\s]+))", strLen, 1)
    mcdir := SubStr(rawOut, strStart+10, strLen-10) . "\"
    SendLog(LOG_LEVEL_INFO, Format("Got {1} from pid: {2}", mcdir, pid), A_TickCount)
    return mcdir
  } else {
    strStart := RegExMatch(rawOut, "P)(?:-Djava\.library\.path=(.+?) )|(?:\""-Djava\.library.path=(.+?)\"")", strLen, 1)
    if (SubStr(rawOut, strStart+20, 1) == "=") {
      strLen -= 1
      strStart += 1
    }
    mcdir := StrReplace(SubStr(rawOut, strStart+20, strLen-28) . ".minecraft\", "/", "\")
    SendLog(LOG_LEVEL_INFO, Format("Got {1} from pid: {2}", mcdir, pid), A_TickCount)
    return mcdir
  }
}

CheckOnePIDFromMcDir(proc, mcdir) {
  cmdLine := proc.Commandline
  if (RegExMatch(cmdLine, "-Djava\.library\.path=(?P<Dir>[^\""]+?)(?:\/|\\)natives", instDir)) {
    StringTrimRight, rawInstDir, mcdir, 1
    thisInstDir := SubStr(StrReplace(instDir, "/", "\"), 21, StrLen(instDir)-28) . "\.minecraft"
    if (rawInstDir == thisInstDir)
      return proc.ProcessId
  }
  return -1
}

GetPIDFromMcDir(mcdir) {
  for proc in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where ExecutablePath like ""%jdk%javaw.exe%""") {
    if ((pid := CheckOnePIDFromMcDir(proc, mcdir)) != -1) {
      SendLog(LOG_LEVEL_INFO, Format("Got PID: {1} from {2}", pid, mcdir), A_TickCount)
      return pid
    }
  }
  ; Broader search if some people use java.exe or some other edge cases
  for proc in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where ExecutablePath like ""%java%""") {
    if ((pid := CheckOnePIDFromMcDir(proc, mcdir)) != -1) {
      SendLog(LOG_LEVEL_INFO, Format("Got PID: {1} using boarder search from {2}", pid, mcdir), A_TickCount)
      return pid
    }
  }
  SendLog(LOG_LEVEL_ERROR, Format("Failed to get PID from {1}", mcdir), A_TickCount)
  return -1
}

GetInstanceTotal() {
  idx := 1
  WinGet, all, list
  Loop, %all%
  {
    WinGet, pid, PID, % "ahk_id " all%A_Index%
    WinGetTitle, title, ahk_pid %pid%
    if (InStr(title, "Minecraft*")) {
      rawPIDs[idx] := pid
      idx += 1
    }
  }
  return rawPIDs.MaxIndex()
}

GetInstanceNumberFromMcDir(mcdir) {
  numFile := mcdir . "instanceNumber.txt"
  num := -1
  if (mcdir == "" || mcdir == ".minecraft" || mcdir == ".minecraft\" || mcdir == ".minecraft/") { ; Misread something
    FileDelete, data/mcdirs.txt
    Reload
  }
  if (!FileExist(numFile)) {
    InputBox, num, Missing instanceNumber.txt, Missing instanceNumber.txt in:`n%mcdir%`nplease type the instance number and select "OK"
    FileAppend, %num%, %numFile%
    SendLog(LOG_LEVEL_WARNING, Format("Instance {1} instanceNumber.txt was missing but was corrected by user", num), A_TickCount)
  } else {
    FileRead, num, %numFile%
    if (!num || num > instances) {
      InputBox, num, Bad instanceNumber.txt, Error in instanceNumber.txt in:`n%mcdir%`nplease type the instance number and select "OK"
      FileDelete, %numFile%
      FileAppend, %num%, %numFile%
      SendLog(LOG_LEVEL_WARNING, Format("Instance {1} instanceNumber.txt contained either a number too high or nothing but was corrected by user", num), A_TickCount)
    }
  }
  SendLog(LOG_LEVEL_INFO, Format("Got instance number {1} from: {2}", num, mcdir), A_TickCount)
  return num
}

GetMcDirFromFile(idx) {
  Loop, Read, data/mcdirs.txt
  {
    split := StrSplit(A_LoopReadLine,"~")
    if (idx == split[1]) {
      mcdir := split[2]
      StringReplace,mcdir,mcdir,`n,,A
      if FileExist(mcdir) {
        SendLog(LOG_LEVEL_INFO, Format("Got {1} from cache for instance {2}", mcdir, idx), A_TickCount)
        return mcdir
      } else {
        FileDelete, data/mcdirs.txt
        Reload
      }
    }
  }
}

GetAllPIDs()
{
  SendLog(LOG_LEVEL_INFO, "Getting all Minecraft directory and PID data", A_TickCount)
  instances := GetInstanceTotal()
  if !instances {
    MsgBox, No open instances detected.
    SendLog(LOG_LEVEL_WARNING, "No open instances detected", A_TickCount)
    Return
  }
  SendLog(LOG_LEVEL_INFO, Format("{1} Instances detected", instances), A_TickCount)
  ; If there are more/less instances than usual, rebuild cache
  if hasMcDirCache && GetLineCount("data/mcdirs.txt") != instances {
    FileDelete,data/mcdirs.txt
    hasMcDirCache := False
  }
  ; Generate mcdir and order PIDs
  Loop, %instances% {
    if hasMcDirCache
      mcdir := GetMcDirFromFile(A_Index)
    else
      mcdir := GetMcDir(rawPIDs[A_Index])
    if (num := GetInstanceNumberFromMcDir(mcdir)) == -1
      ExitApp
    if !hasMcDirCache {
      FileAppend,%num%~%mcdir%`n,data/mcdirs.txt
      pid := rawPIDs[A_Index]
      PIDs[num] := rawPIDs[A_Index] ; TODELETE
    } else {
      pid := GetPIDFromMcDir(mcdir)
      PIDs[num] := GetPIDFromMcDir(mcdir) ; TODELETE
    }
    McDirectories[num] := mcdir

    inMemoryInstances.Push(new Instance(pid,mcdir,num))
  }
  OutputDebug, % "GetAllPIDs end"
}

SetAffinities(idx:=0) {
  for i, mcdir in McDirectories {
    pid := PIDs[i]
    idle := mcdir . "idle.tmp"
    hold := mcdir . "hold.tmp"
    preview := mcdir . "preview.tmp"
    if (idx == i) { ; this is active instance
      SetAffinity(pid, playBitMask)
    } else if (idx > 0) { ; there is another active instance
      if !FileExist(idle)
        SetAffinity(pid, bgLoadBitMask)
      else
        SetAffinity(pid, lowBitMask)
    } else { ; there is no active instance
      if FileExist(idle)
        SetAffinity(pid, lowBitMask)
      else if locked[i]
        SetAffinity(pid, lockBitMask)
      else if FileExist(hold)
        SetAffinity(pid, highBitMask)
      else if FileExist(preview)
        SetAffinity(pid, midBitMask)
      else
        SetAffinity(pid, highBitMask)
    }
  }
}

SetAffinity(pid, mask) {
  hProc := DllCall("OpenProcess", "UInt", 0x0200, "Int", false, "UInt", pid, "Ptr")
  DllCall("SetProcessAffinityMask", "Ptr", hProc, "Ptr", mask)
  DllCall("CloseHandle", "Ptr", hProc)
}

GetBitMask(threads) {
  return ((2 ** threads) - 1)
}

SwitchInstance(idx, skipBg:=false, from:=-1)
{ 
  OutputDebug, % idx 
  idleFile := McDirectories[idx] . "idle.tmp"
  if (idx>=0 && idx <= instances && (FileExist(idleFile) || mode == "C")) {
    holdFile := McDirectories[idx] . "hold.tmp"
    FileAppend,,%holdFile%
    killFile := McDirectories[idx] . "kill.tmp"
    FileAppend,,%killFile%
    FileDelete,data/instance.txt
    FileAppend,%idx%,data/instance.txt
    if tinder
      currBg := GetFirstBgInstance(idx, skipBg)
    pid := PIDs[idx]
    SetAffinities(idx)
    if !locked[idx]
      LockInstance(idx, False, False)
    if (widthMultiplier)
      WinMaximize, ahk_pid %pid%
    WinMinimize, Fullscreen Projector
    WinMinimize, Full-screen Projector
    if unpauseOnSwitch
      ControlSend,, {Blind}{Esc}, ahk_pid %pid%
    WinSet, AlwaysOnTop, On, ahk_pid %pid%
    if (windowMode == "F") {
      fsKey := fsKeys[idx]
      ControlSend,, {Blind}{%fsKey%}, ahk_pid %pid%
      sleep, %fullScreenDelay%
    }
    WinSet, AlwaysOnTop, Off, ahk_pid %pid%
    Send {RButton} ; Make sure the window is activated
    if (f1States[idx] == 2)
      ControlSend,, {Blind}{F1}, ahk_pid %pid%
    if (coop)
      ControlSend,, {Blind}{Esc}{Tab 7}{Enter}{Tab 4}{Enter}{Tab}{Enter}, ahk_pid %pid%
    if (obsControl != "ASS" && obsControl != "controller") {
      if (obsControl == "N")
        obsKey := "Numpad" . idx
      else if (obsControl == "F")
        obsKey := "F" . (idx+12)
      else if (obsControl == "ARR")
        obsKey := obsCustomKeyArray[idx]
      Send {%obsKey% down}
      Sleep, %obsDelay%
      Send {%obsKey% up}
    } else if (obsControl == "controller") {
      SendOBSCmd("Play," . idx)
    }
  } else if smartSwitch {
    nextInst := FindBypassInstance()
    if (nextInst > 0)
      SwitchInstance(nextInst, false)
  } else {
    if !locked[idx]
      LockInstance(idx, False)
  }
}


SendOBSCmd(cmd) {
    static cmdNum := 1
    static cmdDir := % "data/pycmds/" . A_TickCount
    FileAppend, %cmd%, %cmdDir%%cmdNum%.txt
    cmdNum++
}
GetActiveInstanceNum() {
  WinGet, pid, PID, A
  for i, tmppid in PIDs {
    if (tmppid == pid)
      return i
  }
  return -1
}
GetActiveInstance(){
  WinGet, pid, PID, A
  for i, inst in inMemoryInstances {
    if (inst.GetPID() == pid)
      return inst
  }
  return
}
ExitWorld(nextInst:=-1)
{
  instance := GetActiveInstance()


  if (instance) {
    pid := instance.GetPID()
    if f1States[idx] ; goofy ghost pie removal
      ControlSend,, {Blind}{Esc}{F1}{F3}{Esc}{F1}{F3}, ahk_pid %pid%
    else
      ControlSend,, {Blind}{Esc}{F3}{Esc}{F3}, ahk_pid %pid%
    if (CheckOptionsForValue(instance.GetMcDir() . "options.txt", "fullscreen:", "false") == "true") {
      fsKey := instance.fsKey
      ControlSend,, {Blind}{%fsKey%}, ahk_pid %pid%
      sleep, %fullScreenDelay%
    }
    FileDelete,% instance.GetHoldFile()
    FileDelete,% instance.GetKillFile()
    WinRestore, ahk_pid %pid%

    if (mode == "C" && nextInst == -1)
      nextInst := Mod(instance.GetInstanceNum(), instances) + 1
    else if ((mode == "B" || mode == "M") && nextInst == -1)
      nextInst := FindBypassInstance()
    if (nextInst > 0){
      MoveLast(GetInstanceIndexByNum(instance.GetInstanceNum()))
      instance.Reset(true)
      SwitchInstance(nextInst, false, idx)
    }else{
      MoveLast(GetInstanceIndexByNum(instance.GetInstanceNum()))
      instance.Reset(true)
      ToWall(idx)
    }
    SetAffinities(nextInst)
  
    NotifyObs()
    if (widthMultiplier)
      WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%newHeight%
    isWide := False
  }
}

MousePosToInstNumber() {
  MouseGetPos, mX, mY
  if (!grid_mode) {
    return (Floor(mY / instHeight) * cols) + Floor(mX / instWidth) + 1
  }

  
  if (mx <= A_ScreenWidth * grid_estate && my <= A_ScreenHeight * grid_estate){ ; Inside Focus Grid
    return inMemoryInstances[(Floor(mY / (A_ScreenHeight * grid_estate/cols) ) * cols) + Floor(mX / (A_ScreenWidth * grid_estate/rows )) + 1].GetInstanceNum()
  }
  if (my>= A_ScreenHeight * grid_estate && mx<=A_ScreenWidth * grid_estate) {
      static locked_rows_before_rollover := 3
      locked_count:= GetLockedInstanceCount()
      locked_cols := Ceil(locked_count / locked_rows_before_rollover)
      locked_rows := Min(locked_count,locked_rows_before_rollover)
      locked_inst_width := (A_ScreenWidth*grid_estate) / locked_cols
      locked_inst_height := (A_ScreenHeight * (1-grid_estate)) / locked_rows
      index := GetGridUsageInstancecount() + (Floor((mY - A_ScreenHeight*grid_estate)  / locked_inst_height) ) + Floor(mX / locked_inst_width) * locked_rows+ 1
      if (!inMemoryInstances[index].IsLocked()){
        return -1
      }
      return inMemoryInstances[index].GetInstanceNum()
  }

  if (mx>= A_ScreenWidth * grid_estate) { ; Inside passive instances
    index:= GetGridUsageInstancecount() + GetLockedInstanceCount() + Floor(my / (A_ScreenHeight / GetPassiveInstanceCount())) + 1
    return inMemoryInstances[index].GetInstanceNum()
  }
  

  return
  
}

NotifyObs(){
    OutputDebug, % "Building obs wall file"
    output := ""
    gridUsageInstanceCount := GetGridUsageInstancecount() ; To prevent looping every time
    for i,inst  in inMemoryInstances {
        nr := inst.GetInstanceNum()
        if (output!="" ) {
            output:= output . ","
        }
        output := output . nr
        
        if ( inst.IsLocked() ){
          output := output . "L"
        }

        if (!inst.IsLocked() && A_Index>gridUsageInstanceCount){
          output := output . "H"
        }
    }
    OutputDebug, % output

    FileDelete, data/obs.txt
    FileAppend, %output%, data/obs.txt
    return output
}

SwapWithOldest(instanceIndex){
  Swap(inMemoryInstances,instanceIndex,GetOldestInstanceIndexOutsideOfGrid())
}
SwapWithFirstPassive(instanceIndex){
  Swap(inMemoryInstances,instanceIndex,GetGridUsageInstancecount()+GetLockedInstanceCount()+1)
}

MoveLast(hoveredIndex){
  inst := inMemoryInstances[hoveredIndex]
  inMemoryInstances.RemoveAt(hoveredIndex)
  inMemoryInstances.Push(inst)
}

GetOldestInstanceIndexOutsideOfGrid(){
    oldInstanceCount := GetPassiveInstanceCount()


    oldestInstanceIndex :=-1
    oldestPreviewTime:=A_TickCount
    ; Find oldest instance based on preview time, if any
    loop, %oldInstanceCount%{
        index := GetGridUsageInstancecount()+GetLockedInstanceCount()+A_Index
        instance:= inMemoryInstances[index]
        
        if (!instance.IsLocked() && instance.GetPreviewTime() != 0 && instance.GetPreviewTime() <= oldestPreviewTime){
            oldestPreviewTime:=instance.GetPreviewTime()
            oldestInstanceIndex:=index
        }
    }
    if (oldestInstanceIndex>-1) {
      OutputDebug, % "oldestInstanceIndex " . oldestInstanceIndex . " previewtime " . oldestPreviewTime
      return oldestInstanceIndex
    }
    ; Find oldest instance based on when they were reset.
    oldestTickCount := A_TickCount
    loop, %oldInstanceCount%{
        index := GetGridUsageInstancecount()+GetLockedInstanceCount() + A_Index
        instance:= inMemoryInstances[index]
        if (!instance.IsLocked() && instance.lastReset <= oldestTickCount){
            oldestTickCount:=instance.lastReset
            oldestInstanceIndex:=index
        }
    }
    if (oldestInstanceIndex<0){
      ; There is no passive instances to swap with, take last of grid
      return GetGridUsageInstancecount()
    }
    return oldestInstanceIndex
}

Swap(list,t,u)
{
    if ( t < 1 || u < 1  || t > list.MaxIndex() ||  u > list.MaxIndex()) {
      
      return list
    }
    tmp1 := list[t], tmp2 := list[u]
    list[t] := tmp2, list[u] := tmp1
    return list
}
GetPassiveInstanceCount(){
  passiveInstanceCount:=0
  for i,inst  in inMemoryInstances {
    if (A_Index > GetGridUsageInstancecount()){
      if (!inst.isLocked()){
        passiveInstanceCount++
      }
    }
  }
  return passiveInstanceCount
}
; Differs from rows*cols in that sometimes the user locks so many instances that the grid isnt filled
GetGridUsageInstancecount(){
  gridInstanceCount := 0
  for i,inst  in inMemoryInstances {
    if (inst.IsLocked()){
      return gridInstanceCount
    }
    gridInstanceCount++
    if (gridInstanceCount == GetWantedGridInstanceCount()){
      return gridInstanceCount
    }
  }
}

GetWantedGridInstanceCount(){
  return rows*cols
}

GetLockedInstanceCount(){
  lockedInstanceCount:=0
  for i,inst  in inMemoryInstances {
    if (inst.isLocked()){
      lockedInstanceCount++
    }
  }
  return lockedInstanceCount
}
GetHoveredInstance(){
  instNum := MousePosToInstNumber()
  return GetInstanceByNum(instNum)
}
GetHoveredInstanceIndex(){
  instNum := MousePosToInstNumber()
  return GetInstanceIndexByNum(instNum)
}

GetInstanceIndexByNum(num){
  for i,inst in inMemoryInstances{
    if (inst.GetInstanceNum() == num){
      return A_Index
    }
  }
}
GetInstanceByNum(num){
  for i,inst in inMemoryInstances{
    if (inst.GetInstanceNum() == num){
      return A_Index
    }
  }
}

SetTitles() {
  for i, pid in PIDs {
    WinSetTitle, ahk_pid %pid%, , Minecraft* - Instance %i%
  }
}

ToWall(comingFrom) {
  FileDelete,data/instance.txt
  FileAppend,0,data/instance.txt
  FileDelete,data/bg.txt
  FileAppend,0,data/bg.txt
  WinMaximize, Fullscreen Projector
  WinActivate, Fullscreen Projector
  WinMaximize, Full-screen Projector
  WinActivate, Full-screen Projector
  if ( obsControl != "ASS" && obsControl != "controller") {
    send {%obsWallSceneKey% down}
    sleep, %obsDelay%
    send {%obsWallSceneKey% up}
  }
  if ( obsControl == "controller" ){
    SendOBSCmd("ToWall")
  }
}





GetRandomLockNumber() {
  if (themeLockCount == -1) {
    themeLockCount := 0
    Loop, Files, %A_ScriptDir%\media\lock*.png
    {
      themeLockCount += 1
    }
  }
  SendLog(LOG_LEVEL_INFO, Format("Theme lock count found to be {1}", themeLockCount), A_TickCount)
  Random, randLock, 1, %themeLockCount%
  return randLock
}

LockInstance(idx, sound:=true, affinityChange:=true) {
  if (!idx || (idx > rows * cols))
    return
  locked[idx] := true
  lockDest := McDirectories[idx] . "lock.png"
  randLock := GetRandomLockNumber()
  SendLog(LOG_LEVEL_INFO, Format("Randomly picked lock{1}.png to send as lock", randLock), A_TickCount)
  source := A_ScriptDir . "\media\lock" . randLock . ".png"
  If !FileExist(source)
    source := A_ScriptDir . "\media\lock.png"
  FileCopy, %source%, %lockDest%, 1
  FileSetTime,,%lockDest%,M
  lockDest := McDirectories[idx] . "lock.tmp"
  FileAppend,, %lockDest%
  if ((sounds == "A" || sounds == "F" || sound == "L") && sound) {
    SoundPlay, A_ScriptDir\..\media\lock.wav
    if obsLockMediaKey {
      send {%obsLockMediaKey% down}
      sleep, %obsDelay%
      send {%obsLockMediaKey% up}
    }
  }
  if affinityChange {
    pid := PIDs[idx]
    SetAffinity(pid, lockBitMask)
  }
}

UnlockInstance(idx, sound:=true) {
  if (!idx || (idx > rows * cols))
    return
  locked[idx] := false
  lockDest := McDirectories[idx] . "lock.png"
  FileCopy, A_ScriptDir\..\media\unlock.png, %lockDest%, 1
  FileSetTime,,%lockDest%,M
  lockDest := McDirectories[idx] . "lock.tmp"
  FileDelete, %lockDest%
  if ((sounds == "A" || sounds == "F" || sound == "L") && sound) {
    SoundPlay, A_ScriptDir\..\media\unlock.wav
    if obsUnlockMediaKey {
      send {%obsUnlockMediaKey% down}
      sleep, %obsDelay%
      send {%obsUnlockMediaKey% up}
    }
  }
}

LockAll(sound:=true) {
  loop, %instances% {
    LockInstance(A_Index, false)
  }
  if ((sounds == "A" || sounds == "F" || sound == "L") && sound) {
    SoundPlay, A_ScriptDir\..\media\lock.wav
    if obsLockMediaKey {
      send {%obsLockMediaKey% down}
      sleep, %obsDelay%
      send {%obsLockMediaKey% up}
    }
  }
}

UnlockAll(sound:=true) {
  loop, %instances% {
    UnlockInstance(A_Index, false)
  }
  if ((sounds == "A" || sounds == "F" || sound == "L") && sound) {
    SoundPlay, A_ScriptDir\..\media\unlock.wav
    if obsUnlockMediaKey {
      send {%obsUnlockMediaKey% down}
      sleep, %obsDelay%
      send {%obsUnlockMediaKey% up}
    }
  }
}

PlayNextLock() {
  SwitchInstance(FindBypassInstance())
}

WorldBop() {
  MsgBox, 4, Delete Worlds?, Are you sure you want to delete all of your worlds?
  IfMsgBox No
  Return
  cmd := "python.exe """ . A_ScriptDir . "\scripts\worldBopper9000x.py"""
  RunWait,%cmd%, %A_ScriptDir%\scripts ,Hide
  MsgBox, Completed World Bopping!
}

CloseInstances() {
  MsgBox, 4, Close Instances?, Are you sure you want to close all of your instances?
  IfMsgBox No
  Return
  for i, pid in PIDs {
    WinClose, ahk_pid %pid%
  }
  DetectHiddenWindows, On
  for i, rmpid in RM_PIDs {
    WinClose, ahk_pid %rmpid%
  }
  DetectHiddenWindows, Off
}

GetLineCount(file) {
  lineNum := 0
  Loop, Read, %file%
    lineNum := A_Index
  return lineNum
}

SetTheme(theme) {
  SendLog(LOG_LEVEL_INFO, Format("Setting macro theme to {1}", theme), A_TickCount)
  Loop, Files, %A_ScriptDir%\themes\%theme%\*
  {
    fileDest := A_ScriptDir . "\media\" . A_LoopFileName
    FileCopy, %A_LoopFileFullPath%, %fileDest%, 1
    FileSetTime,,%fileDest%,M
    SendLog(LOG_LEVEL_INFO, Format("Copying file {1} to {2}", A_LoopFileFullPath, fileDest), A_TickCount)
  }
}

IsProcessElevated(ProcessID) {
  if !(hProcess := DllCall("OpenProcess", "uint", 0x1000, "int", 0, "uint", ProcessID, "ptr")) {
    SendLog(LOG_LEVEL_WARNING, "OpenProcess failed. Process not open?", A_TickCount)
    return 0
  }
  if !(DllCall("advapi32\OpenProcessToken", "ptr", hProcess, "uint", 0x0008, "ptr*", hToken)) {
    SendLog(LOG_LEVEL_WARNING, "OpenProcessToken failed. Process not open?", A_TickCount)
    return 0
  }
  if !(DllCall("advapi32\GetTokenInformation", "ptr", hToken, "int", 20, "uint*", IsElevated, "uint", 4, "uint*", size))
    throw Exception("GetTokenInformation failed", -1), DllCall("CloseHandle", "ptr", hToken) && DllCall("CloseHandle", "ptr", hProcess)
  return IsElevated, DllCall("CloseHandle", "ptr", hToken) && DllCall("CloseHandle", "ptr", hProcess)
}

VerifyInstance(mcdir, pid, idx) {
  moddir := mcdir . "mods\"
  optionsFile := mcdir . "options.txt"
  atum := false
  wp := false
  standardSettings := false
  fastReset := false
  sleepBg := false
  sodium := false
  srigt := false
  SendLog(LOG_LEVEL_INFO, Format("Starting instance verification for directory: {1}", mcdir), A_TickCount)
  FileRead, settings, %optionsFile%
  Loop, Files, %moddir%*.jar
  {
    if InStr(A_LoopFileName, ".disabled")
      continue
    else if InStr(A_LoopFileName, "atum")
      atum := true
    else if InStr(A_LoopFileName, "worldpreview")
      wp := true
    else if InStr(A_LoopFileName, "standardsettings")
      standardSettings := true
    else if InStr(A_LoopFileName, "fast-reset")
      fastReset := true
    else if InStr(A_LoopFileName, "sleepbackground")
      sleepBg := true
    else if InStr(A_LoopFileName, "sodium")
      sodium := true
    else if InStr(A_LoopFileName, "SpeedRunIGT")
      srigt := true
  }
  if !atum {
    SendLog(LOG_LEVEL_ERROR, Format("Instance {1} missing required mod: atum. Macro will not work. Download: https://github.com/VoidXWalker/Atum/releases. (In directory: {2})", idx, moddir), A_TickCount)
    MsgBox, Instance %idx% missing required mod: atum. Macro will not work. Download: https://github.com/VoidXWalker/Atum/releases.`n(In directory: %moddir%)
  }
  if !wp {
    SendLog(LOG_LEVEL_ERROR, Format("Instance {1} missing recommended mod: World Preview. Macro will likely not work. Download: https://github.com/VoidXWalker/WorldPreview/releases. (In directory: {2})", idx, moddir), A_TickCount)
    MsgBox, Instance %idx% missing recommended mod: World Preview. Macro will likely not work. Download: https://github.com/VoidXWalker/WorldPreview/releases.`n(In directory: %moddir%)
  }
  if !standardSettings {
    SendLog(LOG_LEVEL_WARNING, Format("Instance {1} missing highly recommended mod standardsettings. Download: https://github.com/KingContaria/StandardSettings/releases. (In directory: {2})", idx, moddir), A_TickCount)
    MsgBox, Instance %idx% missing highly recommended mod: standardsettings. Download: https://github.com/KingContaria/StandardSettings/releases.`n(In directory: %moddir%)
    if InStr(settings, "pauseOnLostFocus:true") {
      MsgBox, Instance %idx% has required disabled setting pauseOnLostFocus enabled. Please disable it with f3+p and THEN press OK to continue
      SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had pauseOnLostFocus set true, macro requires it false. User was informed. (In file: {2})", idx, optionsFile), A_TickCount)
    }
    if (InStr(settings, "key_Create New World:key.keyboard.unknown") && atum) {
      MsgBox, Instance %idx% missing required hotkey: Create New World. Please set it in your hotkeys and THEN press OK to continue
      SendLog(LOG_LEVEL_ERROR, Format("Instance {1} had no Create New World key set. User was informed. (In file: {2})", idx, optionsFile), A_TickCount)
      resetKey := CheckOptionsForValue(optionsFile, "key_Create New World", "F6")
      SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile), A_TickCount)
    } else if (atum) {
      resetKey := CheckOptionsForValue(optionsFile, "key_Create New World", "F6")
      SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile), A_TickCount)
      resetKeys[idx] := resetKey
    }
    if (InStr(settings, "key_Leave Preview:key.keyboard.unknown") && wp) {
      MsgBox, Instance %idx% missing highly recommended hotkey: Leave Preview. Please set it in your hotkeys and THEN press OK to continue
      SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had no Leave Preview key set. User was informed. (In file: {2})", idx, optionsFile), A_TickCount)
      lpKey := CheckOptionsForValue(optionsFile, "key_Leave Preview", "h")
      SendLog(LOG_LEVEL_INFO, Format("Found leave preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile), A_TickCount)
      lpkeys[idx] := lpKey
    } else if (wp) {
      lpKey := CheckOptionsForValue(optionsFile, "key_Leave Preview", "h")
      SendLog(LOG_LEVEL_INFO, Format("Found leave preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile), A_TickCount)
      lpkeys[idx] := lpKey
    }
    if (InStr(settings, "key_key.fullscreen:key.keyboard.unknown") && windowMode == "F") {
      MsgBox, Instance %idx% missing required hotkey for fullscreen mode: Fullscreen. Please set it in your hotkeys and THEN press OK to continue
        SendLog(LOG_LEVEL_ERROR, Format("Instance {1} had no Fullscreen key set. User was informed. (In file: {2})", idx, optionsFile), A_TickCount)
      fsKey := CheckOptionsForValue(optionsFile, "key_key.fullscreen", "F11")
      SendLog(LOG_LEVEL_INFO, Format("Found Fullscreen key: {1} for instance {2} from {3}", fsKey, idx, optionsFile), A_TickCount)
      fsKeys[idx] := fsKey
    } else if (windowMode == "F") {
      fsKey := CheckOptionsForValue(optionsFile, "key_key.fullscreen", "F11")
      SendLog(LOG_LEVEL_INFO, Format("Found Fullscreen key: {1} for instance {2} from {3}", fsKey, idx, optionsFile), A_TickCount)
      fsKeys[idx] := fsKey
    }
    f1States[idx] := 0
  } else {
    standardSettingsFile := mcdir . "config\standardoptions.txt"
    FileRead, ssettings, %standardSettingsFile%
    if (RegExMatch(ssettings, "[A-Z]\w{0}:(\/|\\).+.txt")) {
      standardSettingsFile := ssettings
      SendLog(LOG_LEVEL_INFO, Format("Global standard options file detected, rereading standard options from {1}", standardSettingsFile), A_TickCount)
      FileRead, ssettings, %standardSettingsFile%
    }
    if InStr(ssettings, "fullscreen:true") {
      ssettings := StrReplace(ssettings, "fullscreen:true", "fullscreen:false")
      FileDelete, %standardSettingsFile%
      FileAppend, %ssettings%, %standardSettingsFile%
      SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had fullscreen set true, macro requires it false. Automatically fixed. (In file: {2})", idx, standardSettingsFile), A_TickCount)
    }
    if InStr(ssettings, "pauseOnLostFocus:true") {
      ssettings := StrReplace(ssettings, "pauseOnLostFocus:true", "pauseOnLostFocus:false")
      FileDelete, %standardSettingsFile%
      FileAppend, %ssettings%, %standardSettingsFile%
      SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had pauseOnLostFocus set true, macro requires it false. Automatically fixed. (In file: {2})", idx, standardSettingsFile), A_TickCount)
    }
    if (RegExMatch(ssettings, "f1:.+", regexVar)) {
      SendLog(LOG_LEVEL_INFO, Format("Instance {1} f1 state '{2}' found. This will be used for ghost pie and instance join. (In file: {3})", idx, regexVar, standardSettingsFile), A_TickCount)
      f1States[idx] := regexVar == "f1:true" ? 2 : 1
    } else {
      f1States[idx] := 0
    }
    Loop, 1 {
      if (InStr(ssettings, "key_Create New World:key.keyboard.unknown") && atum) {
        Loop, 1 {
          MsgBox, 4, Create New World Key, Instance %idx% has no Create New World hotkey set. Would you like to set this back to default (F6)?`n(In file: %standardSettingsFile%)
          IfMsgBox No
          break
          ssettings := StrReplace(ssettings, "key_Create New World:key.keyboard.unknown", "key_Create New World:key.keyboard.f6")
          FileDelete, %standardSettingsFile%
          FileAppend, %ssettings%, %standardSettingsFile%
          resetKeys[idx] := "F6"
          SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had no Create New World key set and chose to let it be automatically set to f6. (In file: {2})", idx, standardSettingsFile), A_TickCount)
          break 2
        }
        SendLog(LOG_LEVEL_ERROR, Format("Instance {1} has no Create New World key set. (In file: {2})", idx, standardSettingsFile), A_TickCount)
      } else if (InStr(ssettings, "key_Create New World:") && atum) {
        resetKey := CheckOptionsForValue(standardSettingsFile, "key_Create New World", "F6")
        if resetKey {
          SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, standardSettingsFile), A_TickCount)
          resetKeys[idx] := resetKey
          break
        } else {
          SendLog(LOG_LEVEL_WARNING, Format("Failed to read reset key for instance {1}, trying to read from {2} instead of {3}", idx, optionsFile, standardSettingsFile), A_TickCount)
          resetKey := CheckOptionsForValue(optionsFile, "key_Create New World", "F6")
          if resetKey {
            SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile), A_TickCount)
            resetKeys[idx] := resetKey
            break
          } else {
            SendLog(LOG_LEVEL_ERROR, Format("Failed to find reset key in instance {1}, falling back to 'F6'. (Checked files: {2} and {3})", idx, standardSettingsFile, optionsFile), A_TickCount)
            resetKeys[idx] := "F6"
            break
          }
        }
      } else if (InStr(settings, "key_Create New World:key.keyboard.unknown") && atum) {
        Loop, 1 {
          MsgBox, Instance %idx% has no required hotkey set for Create New World. Please set it in your hotkeys and THEN press OK to continue
            SendLog(LOG_LEVEL_ERROR, Format("Instance {1} had no Create New World key set. User was informed. (In file: {2})", idx, optionsFile), A_TickCount)
          resetKey := CheckOptionsForValue(optionsFile, "key_Create New World", "F6")
          SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile), A_TickCount)
          resetKeys[idx] := resetKey
          break 2
        }
        SendLog(LOG_LEVEL_ERROR, Format("Instance {1} has no Create New World key set. (In file: {2})", idx, optionsFile), A_TickCount)
      } else if (InStr(settings, "key_Create New World:") && atum) {
        resetKey := CheckOptionsForValue(optionsFile, "key_Create New World", "F6")
        if resetKey {
          SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile), A_TickCount)
          resetKeys[idx] := resetKey
          break
        } else {
          SendLog(LOG_LEVEL_ERROR, Format("Failed to find reset key in instance {1}, falling back to 'F6'. (In file: {2})", idx, optionsFile), A_TickCount)
          resetKeys[idx] := "F6"
          break
        }
      } else if (atum) {
        MsgBox, No Create New World hotkey found even though you have the mod, you likely have an outdated version. Please update to the latest version.
        SendLog(LOG_LEVEL_ERROR, Format("No Create New World hotkey found for instance {1} even though mod is installed. Using 'f6' to avoid reset manager errors", idx), A_TickCount)
        resetKeys[idx] := "F6"
        break
      } else {
        SendLog(LOG_LEVEL_ERROR, Format("No required atum mod in instance {1}. Using 'f6' to avoid reset manager errors", idx), A_TickCount)
        resetKeys[idx] := "F6"
        break
      }
    }
    Loop, 1 {
      if (InStr(ssettings, "key_Leave Preview:key.keyboard.unknown") && wp) {
        Loop, 1 {
          MsgBox, 4, Leave Preview Key, Instance %idx% has no Leave Preview hotkey set. Would you like to set this back to default (h)?`n(In file: %standardSettingsFile%)
          IfMsgBox No
          break
          ssettings := StrReplace(ssettings, "key_Leave Preview:key.keyboard.unknown", "key_Leave Preview:key.keyboard.h")
          FileDelete, %standardSettingsFile%
          FileAppend, %ssettings%, %standardSettingsFile%
          lpKeys[idx] := "h"
          SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had no Leave Preview key set and chose to let it be automatically set to 'h'. (In file: {2})", idx, standardSettingsFile), A_TickCount)
          break 2
        }
        SendLog(LOG_LEVEL_ERROR, Format("Instance {1} has no Leave Preview key set. (In file: {2})", idx, standardSettingsFile), A_TickCount)
      } else if (InStr(ssettings, "key_Leave Preview:") && wp) {
        lpKey := CheckOptionsForValue(standardSettingsFile, "key_Leave Preview", "h")
        if lpKey {
          SendLog(LOG_LEVEL_INFO, Format("Found Leave Preview key: {1} for instance {2} from {3}", lpKey, idx, standardSettingsFile), A_TickCount)
          lpKeys[idx] := lpKey
          break
        } else {
          SendLog(LOG_LEVEL_WARNING, Format("Failed to read Leave Preview key for instance {1}, trying to read from {2} instead of {3}", idx, optionsFile, standardSettingsFile), A_TickCount)
          lpKey := CheckOptionsForValue(optionsFile, "key_Leave Preview", "h")
          if lpKey {
            SendLog(LOG_LEVEL_INFO, Format("Found Leave Preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile), A_TickCount)
            lpKeys[idx] := lpKey
            break
          } else {
            SendLog(LOG_LEVEL_ERROR, Format("Failed to find Leave Preview key in instance {1}, falling back to 'h'. (Checked files: {2} and {3})", idx, standardSettingsFile, optionsFile), A_TickCount)
            lpKeys[idx] := "h"
            break
          }
        }
      } else if (InStr(settings, "key_Leave Preview:key.keyboard.unknown") && wp) {
        Loop, 1 {
          MsgBox, Instance %idx% has no recommended hotkey set for Leave Preview. Please set it in your hotkeys and THEN press OK to continue
            SendLog(LOG_LEVEL_ERROR, Format("Instance {1} had no Leave Preview key set. User was informed. (In file: {2})", idx, optionsFile), A_TickCount)
          lpKey := CheckOptionsForValue(optionsFile, "key_Leave Preview", "h")
          SendLog(LOG_LEVEL_INFO, Format("Found Leave Preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile), A_TickCount)
          lpKeys[idx] := lpKey
          break 2
        }
        SendLog(LOG_LEVEL_ERROR, Format("Instance {1} has no Leave Preview key set. (In file: {2})", idx, optionsFile), A_TickCount)
      } else if (InStr(settings, "key_Leave Preview:") && wp) {
        lpKey := CheckOptionsForValue(optionsFile, "key_Leave Preview", "h")
        if lpKey {
          SendLog(LOG_LEVEL_INFO, Format("Found Leave Preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile), A_TickCount)
          lpKeys[idx] := lpKey
          break
        } else {
          SendLog(LOG_LEVEL_ERROR, Format("Failed to find Leave Preview key in instance {1}, falling back to 'h'. (In file: {2})", idx, optionsFile), A_TickCount)
          lpKeys[idx] := "h"
          break
        }
      } else if (wp) {
        MsgBox, No Leave Preview hotkey found even though you have the mod, something went wrong trying to find the key.
        SendLog(LOG_LEVEL_ERROR, Format("No Leave Preview hotkey found for instance {1} even though mod is installed. Using 'h' to avoid reset manager errors", idx), A_TickCount)
        lpKeys[idx] := "h"
        break
      } else {
        SendLog(LOG_LEVEL_ERROR, Format("No recommended World Preview mod in instance {1}. Using 'h' to avoid reset manager errors", idx), A_TickCount)
        lpKeys[idx] := "h"
        break
      }
    }
    Loop, 1 {
      if (InStr(ssettings, "key_key.fullscreen:key.keyboard.unknown") && windowMode == "F") {
        Loop, 1 {
          MsgBox, 4, Fullscreen Key, Instance %idx% missing required hotkey for fullscreen mode: Fullscreen. Would you like to set this back to default (f11)?`n(In file: %standardSettingsFile%)
            IfMsgBox No
          break
          ssettings := StrReplace(ssettings, "key_key.fullscreen:key.keyboard.unknown", "key_key.fullscreen:key.keyboard.f11")
          FileDelete, %standardSettingsFile%
          FileAppend, %ssettings%, %standardSettingsFile%
          fsKeys[idx] := "F11"
          SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had no Fullscreen key set and chose to let it be automatically set to 'f11'. (In file: {2})", idx, standardSettingsFile), A_TickCount)
          break 2
        }
        SendLog(LOG_LEVEL_ERROR, Format("Instance {1} has no Fullscreen key set. (In file: {2})", idx, standardSettingsFile), A_TickCount)
      } else {
        fsKey := CheckOptionsForValue(standardSettingsFile, "key_key.fullscreen", "F11")
        SendLog(LOG_LEVEL_INFO, Format("Found Fullscreen key: {1} for instance {2} from {3}", fsKey, idx, standardSettingsFile), A_TickCount)
        fsKeys[idx] := fsKey
        break
      }
    }
    Loop, 1 {
      if (InStr(ssettings, "key_key.command:key.keyboard.unknown")) {
        Loop, 1 {
          MsgBox, 4, Command Key, Instance %idx% missing recommended command hotkey. Would you like to set this back to default (/)?`n(In file: %standardSettingsFile%)
          IfMsgBox No
          break
          ssettings := StrReplace(ssettings, "key_key.command:key.keyboard.unknown", "key_key.command:key.keyboard.slash")
          FileDelete, %standardSettingsFile%
          FileAppend, %ssettings%, %standardSettingsFile%
          commandkeys[idx] := "/"
          SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had no command key set and chose to let it be automatically set to '/'. (In file: {2})", idx, standardSettingsFile), A_TickCount)
          break 2
        }
        SendLog(LOG_LEVEL_ERROR, Format("Instance {1} has no command key set. (In file: {2})", idx, standardSettingsFile), A_TickCount)
      } else {
        commandkey := CheckOptionsForValue(standardSettingsFile, "key_key.command", "/")
        SendLog(LOG_LEVEL_INFO, Format("Found Command key: {1} for instance {2} from {3}", commandkey, idx, standardSettingsFile), A_TickCount)
        commandkeys[idx] := commandkey
        break
      }
    }
  }
  if !fastReset
    SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing recommended mod fast-reset. Download: https://github.com/jan-leila/FastReset/releases", moddir), A_TickCount)
  if !sleepBg
    SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing recommended mod sleepbackground. Download: https://github.com/RedLime/SleepBackground/releases", moddir), A_TickCount)
  if !sodium
    SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing recommended mod sodium. Download: https://github.com/jan-leila/sodium-fabric/releases", moddir), A_TickCount)
  if !srigt
    SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing recommended mod SpeedRunIGT. Download: https://redlime.github.io/SpeedRunIGT/", moddir), A_TickCount)
  FileRead, settings, %optionsFile%
  if InStr(settings, "fullscreen:true") {
    fsKey := fsKeys[idx]
    ControlSend,, {Blind}{%fsKey%}, ahk_pid %pid%
  }
  SendLog(LOG_LEVEL_INFO, Format("Finished instance verification for directory: {1}", mcdir), A_TickCount)
}

WideHardo() {
  idx := GetActiveInstanceNum()
  commandkey := commandkeys[idx]
  pid := PIDs[idx]
  if (isWide)
    WinMaximize, ahk_pid %pid%
  else {
    WinRestore, ahk_pid %pid%
    WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%newHeight%
  }
  isWide := !isWide
}

OpenToLAN() {
  idx := GetActiveInstanceNum()
  commandkey := commandkeys[idx]
  Send, {Esc}
  Send, {ShiftDown}{Tab 3}{Enter}{Tab}{ShiftUp}
  Send, {Enter}{Tab}{Enter}
  Send, {%commandkey%}
  Sleep, 100
  Send, gamemode
  Send, {Space}
  Send, creative
  Send, {Enter}
}

GoToNether() {
  idx := GetActiveInstanceNum()
  commandkey := commandkeys[idx]
  Send, {%commandkey%}
  Sleep, 100
  Send, setblock
  Send, {Space}{~}{Space}{~}{Space}{~}{Space}
  Send, minecraft:nether_portal
  Send, {Enter}
}

OpenToLANAndGoToNether() {
  OpenToLAN()
  GoToNether()
}

CheckFor(struct, x := "", z := "") {
  idx := GetActiveInstanceNum()
  commandkey := commandkeys[idx]
  Send, {%commandkey%}
  Sleep, 100
  if (z != "" && x != "") {
    Send, execute
    Send, {Space}
    Send, positioned
    Send, {Space}
    Send, %x%
    Send, {Space}{0}{Space}
    Send, %z%
    Send, {Space}
    Send, run
    Send, {Space}
  }
  Send, locate
  Send, {Space}
  Send, %struct%
  Send, {Enter}
}

CheckFourQuadrants(struct) {
  CheckFor(struct, "1", "1")
  CheckFor(struct, "-1", "1")
  CheckFor(struct, "1", "-1")
  CheckFor(struct, "-1", "-1")
}

; Shoutout peej
CheckOptionsForValue(file, optionsCheck, defaultValue) {
  static keyArray := Object("key.keyboard.f1", "F1"
  ,"key.keyboard.f2", "F2"
  ,"key.keyboard.f3", "F3"
  ,"key.keyboard.f4", "F4"
  ,"key.keyboard.f5", "F5"
  ,"key.keyboard.f6", "F6"
  ,"key.keyboard.f7", "F7"
  ,"key.keyboard.f8", "F8"
  ,"key.keyboard.f9", "F9"
  ,"key.keyboard.f10", "F10"
  ,"key.keyboard.f11", "F11"
  ,"key.keyboard.f12", "F12"
  ,"key.keyboard.f13", "F13"
  ,"key.keyboard.f14", "F14"
  ,"key.keyboard.f15", "F15"
  ,"key.keyboard.f16", "F16"
  ,"key.keyboard.f17", "F17"
  ,"key.keyboard.f18", "F18"
  ,"key.keyboard.f19", "F19"
  ,"key.keyboard.f20", "F20"
  ,"key.keyboard.f21", "F21"
  ,"key.keyboard.f22", "F22"
  ,"key.keyboard.f23", "F23"
  ,"key.keyboard.f24", "F24"
  ,"key.keyboard.q", "q"
  ,"key.keyboard.w", "w"
  ,"key.keyboard.e", "e"
  ,"key.keyboard.r", "r"
  ,"key.keyboard.t", "t"
  ,"key.keyboard.y", "y"
  ,"key.keyboard.u", "u"
  ,"key.keyboard.i", "i"
  ,"key.keyboard.o", "o"
  ,"key.keyboard.p", "p"
  ,"key.keyboard.a", "a"
  ,"key.keyboard.s", "s"
  ,"key.keyboard.d", "d"
  ,"key.keyboard.f", "f"
  ,"key.keyboard.g", "g"
  ,"key.keyboard.h", "h"
  ,"key.keyboard.j", "j"
  ,"key.keyboard.k", "k"
  ,"key.keyboard.l", "l"
  ,"key.keyboard.z", "z"
  ,"key.keyboard.x", "x"
  ,"key.keyboard.c", "c"
  ,"key.keyboard.v", "v"
  ,"key.keyboard.b", "b"
  ,"key.keyboard.n", "n"
  ,"key.keyboard.m", "m"
  ,"key.keyboard.1", "1"
  ,"key.keyboard.2", "2"
  ,"key.keyboard.3", "3"
  ,"key.keyboard.4", "4"
  ,"key.keyboard.5", "5"
  ,"key.keyboard.6", "6"
  ,"key.keyboard.7", "7"
  ,"key.keyboard.8", "8"
  ,"key.keyboard.9", "9"
  ,"key.keyboard.0", "0"
  ,"key.keyboard.tab", "Tab"
  ,"key.keyboard.left.bracket", "["
  ,"key.keyboard.right.bracket", "]"
  ,"key.keyboard.backspace", "Backspace"
  ,"key.keyboard.equal", "="
  ,"key.keyboard.minus", "-"
  ,"key.keyboard.grave.accent", "`"
  ,"key.keyboard.slash", "/"
  ,"key.keyboard.space", "Space"
  ,"key.keyboard.left.alt", "LAlt"
  ,"key.keyboard.right.alt", "RAlt"
  ,"key.keyboard.print.screen", "PrintScreen"
  ,"key.keyboard.insert", "Insert"
  ,"key.keyboard.scroll.lock", "ScrollLock"
  ,"key.keyboard.pause", "Pause"
  ,"key.keyboard.right.control", "RControl"
  ,"key.keyboard.left.control", "LControl"
  ,"key.keyboard.right.shift", "RShift"
  ,"key.keyboard.left.shift", "LShift"
  ,"key.keyboard.comma", ","
  ,"key.keyboard.period", "."
  ,"key.keyboard.home", "Home"
  ,"key.keyboard.end", "End"
  ,"key.keyboard.page.up", "PgUp"
  ,"key.keyboard.page.down", "PgDn"
  ,"key.keyboard.delete", "Delete"
  ,"key.keyboard.left.win", "LWin"
  ,"key.keyboard.right.win", "RWin"
  ,"key.keyboard.menu", "AppsKey"
  ,"key.keyboard.backslash", "\"
  ,"key.keyboard.caps.lock", "CapsLock"
  ,"key.keyboard.semicolon", ";"
  ,"key.keyboard.apostrophe", "'"
  ,"key.keyboard.enter", "Enter"
  ,"key.keyboard.up", "Up"
  ,"key.keyboard.down", "Down"
  ,"key.keyboard.left", "Left"
  ,"key.keyboard.right", "Right"
  ,"key.keyboard.keypad.0", "Numpad0"
  ,"key.keyboard.keypad.1", "Numpad1"
  ,"key.keyboard.keypad.2", "Numpad2"
  ,"key.keyboard.keypad.3", "Numpad3"
  ,"key.keyboard.keypad.4", "Numpad4"
  ,"key.keyboard.keypad.5", "Numpad5"
  ,"key.keyboard.keypad.6", "Numpad6"
  ,"key.keyboard.keypad.7", "Numpad7"
  ,"key.keyboard.keypad.8", "Numpad8"
  ,"key.keyboard.keypad.9", "Numpad9"
  ,"key.keyboard.keypad.decimal", "NumpadDot"
  ,"key.keyboard.keypad.enter", "NumpadEnter"
  ,"key.keyboard.keypad.add", "NumpadAdd"
  ,"key.keyboard.keypad.subtract", "NumpadSub"
  ,"key.keyboard.keypad.multiply", "NumpadMult"
  ,"key.keyboard.keypad.divide", "NumpadDiv"
  ,"key.mouse.left", "LButton"
  ,"key.mouse.right", "RButton"
  ,"key.mouse.middle", "MButton"
  ,"key.mouse.4", "XButton1"
  ,"key.mouse.5", "XButton2")
  FileRead, fileData, %file%
  if (RegExMatch(fileData, "[A-Z]\w{0}:(\/|\\).+.txt")) {
    file := fileData
  }
  Loop, Read, %file%
  {
    if (InStr(A_LoopReadLine, optionsCheck)) {
      split := StrSplit(A_LoopReadLine, ":")
      if (split.MaxIndex() == 2)
        if keyArray[split[2]]
        return keyArray[split[2]]
      else
        return split[2]
      SendLog(LOG_LEVEL_ERROR, Format("Couldn't parse options correctly, defaulting to '{1}'. Line: {2}", defaultKey, A_LoopReadLine), A_TickCount)
      return defaultValue
    }
  }
}