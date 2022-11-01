class Instance {
    __New(pid, mcdir, idx){
        this.locked := false
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
        this.locked:=false
    }
    Lock(){
        SetAffinity(this.GetPID(), lockBitMask)
        this.locked:=True
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
        
        return (A_TickCount - this.gridTime)  < gridProtection   ; make configurable
    }

    Reset(bypassLock:=true, extraProt:=0){
        if(
            !FileExist(this.GetHoldFile())
            && (spawnProtection + extraProt + this.GetPreviewTime()) < A_TickCount
            && ((!bypassLock && !this.locked) || bypassLock))
        {
            OutputDebug,  % "updating lastReset" 
            this.lastReset:=A_TickCount
            FileDelete, % this.GetPreviewFile()
            FileAppend,, % this.GetHoldFile()
            SendLog(LOG_LEVEL_INFO, Format("Instance {1} valid reset triggered", this.GetInstanceNum()), A_TickCount)
            ControlSend, ahk_parent
                , % "{Blind}{" . this.lpkey . "}{" . this.resetKey . "}"
                , % "ahk_pid" . this.pid 
            DetectHiddenWindows, On
            PostMessage, MSG_RESET,,,, % "ahk_pid" this.rmpid
            DetectHiddenWindows, Off
            
            this.Unlock()
            resets++
        }
    }

}