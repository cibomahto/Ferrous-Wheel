#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

;run C:\Program Files\Tobias Erichsen\loopMIDI\loopMIDI.exe
;run "C:\Program Files\ZynAddSubFX\zynaddsubfx.exe -l fantasy_bell.xmz"
;run C:\Users\Ferrous Wheel\Documents\Processing\ferrous_wheel\ferrous_wheel.pde
run C:\Users\Ferrous Wheel\Desktop\shortcuts\FIRST.lnk
run C:\Users\Ferrous Wheel\Desktop\shortcuts\SECOND.lnk
run C:\Users\Ferrous Wheel\Desktop\shortcuts\THIRD.lnk
winwait ferrous_wheel
winactivate
sleep 1000
send ^r
