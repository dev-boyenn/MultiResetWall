; v1.0
; General settings
global rows := LoadObsSetting("rows") ; Number of rows on the focus grid, should be equal to what you have configured in obs for index.py
global cols := LoadObsSetting("cols")  ; Number of columns on the focus grid, should be equal to what you have configured in obs for index.py
global mode := "W" ; W = Normal wall, B = Wall bypass (skip to next locked), S = Smart Bypass ( Bypass theres only bypassThreshold instances resetting ), M = Modern multi (send to wall when none loaded), C = Classic original multi (always force to next instance)
global windowMode := "W" ; W = windowed mode, F = fullscreen mode, B = borderless windowed
global screen_estate_horizontal = LoadObsSetting("screen_estate_horizontal")  ; Horizontal ratio of the focus grid. Setting this to 1 hides the passive instances.
global screen_estate_vertical = LoadObsSetting("screen_estate_vertical") ; Vertical ratio of the focus grid. Setting this to 1 hides the locked instances.
global locked_rows_before_rollover =LoadObsSetting("locked_rows_before_rollover") ; Specifies how many rows have to be reached in the locked section to start a new column. For example, having this set to 2 makes the locked layout: 1x1,2x1,2x2,2x2,2x3,2x3, ...
global freeze_percent = LoadObsSetting("freeze_percent") ; Specifies how many rows have to be reached in the locked section to start a new column. For example, having this set to 2 makes the locked layout: 1x1,2x1,2x2,2x2,2x3,2x3, ...
global scrollBgResetting = False ; Adds Scroll background resetting. Read README.md for how to set it up
global grid_mode := True ; If you set this to false shit will go south as the macro is currently not backward compatible
global bypassThreshold := 2 ; Makes it so that in smart bypass ( mode S ) and when using playNextLock, it will prefer keeping you on Wall scene if this many instances are idle ( fully loaded , not locked )

; Extra features
global widthMultiplier := 2.5 ; How wide your instances go to maximize visibility :) (set to 0 for no width change)
global coop := False ; Automatically opens to LAN when you load in a world
global sounds := "A" ; A = all, F = only functions, R = only resets, T = only tts, L = only locks, N = no sounds
global audioGui := False ; A simple GUI so the OBS application audio plugin can capture sounds
global tinder := False ; Set to True if you want to use tinder-style bg resetting
global unpauseOnSwitch := True ; Unpause instance right after switching to it
global smartSwitch := False ; Find an instance to switch to if current one is unloaded
global theme := "rawalle" ; the name of the folder you wish to use as your macro theme in the global themes folder

; Delays (Defaults are probably fine)
global spawnProtection := 500 ; Prevent a new instance from being reset for this many milliseconds after the preview is visible
global gridProtection := 200 ; Prevent an instance for being reset / locked when it just swapped into / out of grid
global fullScreenDelay := 100 ; ( DEV NOTE ) I think this is less of a problem with win32 activations, setting default to 100 to see if it causes issues for people
global tinderCheckBuffer := 5 ; When all instances cant reset, how often it checks for an instance in seconds

; Super advanced settings (Read about these settings on the README before changing)

; Affinity
; -1 == use macro math to determine thread counts
global affinityType := "A" ; N = no affinity management, B = basic affinity management, A = advanced affinity mangement (best if used with locking+resetAll)
global playThreadsOverride := -1 ; Thread count for instance you are playing
global lockThreadsOverride := -1 ; Thread count for locked instances loading on wall
global highThreadsOverride := -1 ; Thread count for instances on the 0% dirt screen while on wall
global midThreadsOverride := -1 ; Thread count for instances loading a preview (previewBurstLength) after detecting it
global lowThreadsOverride := -1 ; Thread count for instances loading a preview that has reached (previewLoadPercent) requirement and all idle instances
global bgLoadThreadsOverride := -1 ; Thread count for loading instances, and locked instances in bg
global previewBurstLength := 500 ; The delay before switching from high to mid while on wall or from bgLoad to low while in bg
global previewLoadPercent := 50 ; The percentage of world gen that must be reached before lowering to low

; OBS
global obsControl := "controller" ; N = Numpad keys (<10 inst), F = Function keys (f13-f24, <13 inst, setup script in utils folder), ARR = advanced array (see customKeyArray), ASS = advanced scene switcher (read GitHub)
global obsWallSceneKey := "F12" ; All obs scene control types use wallSceneKey
global obsCustomKeyArray := [] ; Must be used with advanced array control type. Add keys in quotes separated by commas. The index in the array corresponds to the scene
global obsResetMediaKey := "" ; Key pressed on any instance reset with sound (used for playing reset media file in obs for recordable/streamable resets and requires addition setup to work)
global obsLockMediaKey := "" ; Key pressed on any lock instance with sound (used for playing lock media file in obs for recordable/streamable lock sounds and requires addition setup to work)
global obsUnlockMediaKey := "" ; Key pressed on any unlock instance with sound (used for playing unlock media file in obs for recordable/streamable unlock sounds and requires addition setup to work)
global obsDelay := 50 ; delay between hotkey press and release, increase if not changing scenes in obs and using a hotkey form of control

; Reset Management
global beforePauseDelay := 0 ; extra delay before the final pause for a loading instance. May be needed for very laggy loading. Default (0) should be fine
global resetManagementTimeout := -1 ; Milliseconds that can pass before reset manager gives up. Too low might leave instances unpaused. Default (-1, don't timeout)
global manageResetAfter := 300 ; Delay before starting reset management log reading loop. Default (300) likely fine
global resetManagementLoopDelay := 70 ; Buffer time between log lines check in reset management loop. Lowering will decrease possible pause latencies but increase cpu usage of reset managers. Default (70) likely fine
global doubleCheckUnexpectedLoads := True ; If you plan to use the wall without World Preview mod you should disable this. Default (True)

; Attempts
global overallAttemptsFile := "data/ATTEMPTS.txt" ; File to write overall attempt count to
global dailyAttemptsFile := "data/ATTEMPTS_DAY.txt" ; File to write daily attempt count to