class Instance {
    __New(pid, mcdir, idx){
        this.locked := false
        this.hwnd := getHwndForPid(pid)
        this.pid := pid
        this.mcdir := mcdir
        this.idx := idx
        this.lastReset := A_TickCount
        this.gridTime :=A_TickCount
    }

    GetMcDir(){
        return this.mcdir
    }

    GetInstanceNum(){
        return this.idx
    }

    GetHoldFile(){
        return this.GetMcDir() . "hold.tmp"
    }
    GetKillFile(){
        return this.GetMcDir() . "kill.tmp"
    }

    GetPreviewFile(){
        return this.GetMcDir() . "preview.tmp"
    }

    GetPreviewTime(){
        previewFile:= this.GetPreviewFile()
        FileRead, previewTime, %previewFile%
        previewTime += 0
        return previewTime
    }
    GetPID(){
        return this.pid
    }
    GetHwnd(){
        return this.hwnd
    }

    SetPID(pid){
        this.pid := pid
    }

    GetRMPID(){
        return this.rmpid
    }
    SetRMPID(rmpid){
        this.rmpid := rmpid
    }

    IsLocked(){
        return this.locked
    }
    Unlock(){
        if (!this.IsLocked())
            return
        this.locked:=false
        FileDelete, % this.GetLockFile()
    }
    Lock(sound:=true, affinityChange:= true){
        if (this.IsLocked()){
            return
        }
        this.locked:=True
        if ((sounds == "A" || sounds == "F" || sound == "L") && sound) {
            SoundPlay, A_ScriptDir\..\media\lock.wav
            if obsLockMediaKey {
                send {%obsLockMediaKey% down}
                sleep, %obsDelay%
                send {%obsLockMediaKey% up}
            }
        }
        if affinityChange {
            SetAffinity(this.pid, lockBitMask)
        }
        FileAppend,, % this.GetLockFile()

    }
    IsThin(){
        return this.thin
    }

    ToggleThin(){
        if (this.IsThin()){
            DllCall("MoveWindow","uint",this.GetHwnd(),"Int",0,"Int",0,"Int",A_ScreenWidth,"Int",A_ScreenHeight,"Int",1)
            this.thin := false
        }else{
            DllCall("MoveWindow","uint",this.GetHwnd(),"Int",A_ScreenWidth/2-(300/2),"Int",0,"Int",300,"Int",A_ScreenHeight,"Int",1)
            this.thin := true
        }
    }

    GetLockFile(){
        return this.GetMcDir() . "lock.tmp"
    }
    GetIdleFile(){
        return this.GetMcDir() . "idle.tmp"
    }
    GetGridTime(){
        return this.gridTime
    }
    UpdateGridTime(){
        this.gridTime := A_TickCount
    }
    RecentlySwapped(){

        return (A_TickCount - this.gridTime) < gridProtection ; make configurable
    }

    Reset(bypassLock:=true, extraProt:=0) {
        if (!FileExist(this.GetHoldFile()) && (bypassLock || ((spawnProtection + extraProt + this.GetPreviewTime()) < A_TickCount && (!this.locked)) ))
        {
            this.lastReset:=A_TickCount
            FileDelete, % this.GetPreviewFile()
            FileAppend,, % this.GetHoldFile()
            SendLog(LOG_LEVEL_INFO, Format("Instance {1} valid reset triggered", this.GetInstanceNum()), A_TickCount)
            ControlSend, ahk_parent
            , % "{Blind}{" . this.lpkey . "}{" . this.resetKey . "}"
            , % "ahk_pid " . this.pid
            DetectHiddenWindows, On
            PostMessage, MSG_RESET,,,, % "ahk_pid " this.rmpid
            DetectHiddenWindows, Off

            this.Unlock()
            this.thin := false
            resets++
        }
    }

    SwitchTo(){
        if ( FileExist(this.GetIdleFile()) || mode == "C") {
            FileAppend,,% this.GetHoldFile()
            FileAppend,,% this.GetKillFile()
            FileDelete,data/instance.txt
            FileAppend,% this.GetInstanceNum(), data/instance.txt
            SetAffinities(this.GetInstanceNum())
            this.Lock(false,false)
            GetProjectorID(projectorID)
            WinMinimize, ahk_id %projectorID%
            if (windowMode == "F") {
                fsKey := fsKeys[this.GetInstanceNum()]
                ControlSend,, % "{Blind}{" . this.fsKey . "}", % "ahk_pid " . this.pid
            }

            foreGroundWindow := DllCall("GetForegroundWindow")
            windowThreadProcessId := DllCall("GetWindowThreadProcessId", "uint",foreGroundWindow,"uint",0)
            currentThreadId := DllCall("GetCurrentThreadId")
            DllCall("AttachThreadInput", "uint",windowThreadProcessId,"uint",currentThreadId,"int",1)
            if (widthMultiplier && (windowMode == "W" || windowMode == "B"))
                DllCall("SendMessage","uint",this.GetHwnd(),"uint",0x0112,"uint",0xF030,"int",0) ; fast maximise
            DllCall("SetForegroundWindow", "uint",this.GetHwnd()) ; Probably only important in windowed, helps application take input without a Send Click
            DllCall("BringWindowToTop", "uint",this.GetHwnd())
            DllCall("AttachThreadInput", "uint",windowThreadProcessId,"uint",currentThreadId,"int",0)

            if unpauseOnSwitch
                ControlSend,, {Blind}{Esc}, % "ahk_pid " . this.pid
            if (f1States[this.GetInstanceNum()] == 2)
                ControlSend,, {Blind}{F1}, % "ahk_pid " . this.pid
            if (coop)
                ControlSend,, {Blind}{Esc}{Tab 7}{Enter}{Tab 4}{Enter}{Tab}{Enter}, % "ahk_pid " . this.pid
        
            SendOBSCmd("Play," . this.GetInstanceNum())

            if (scrollBgResetting){
                CreateBackgroundArray()
            }
            NotifyObsBackground()
        } else {
            this.Lock()
        }
    }
}