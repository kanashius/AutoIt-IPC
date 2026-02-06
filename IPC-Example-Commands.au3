#cs ----------------------------------------------------------------------------

	 AutoIt Version: 3.3.18.0
	 Author:         Kanashius

	 Script Function:
		Example script for the IPC InterProcessCommunication UDF.

#ce ----------------------------------------------------------------------------
#include "IPC.au3"

Global Const $iCOMMAND_START = 1, $iCOMMAND_END = 2, $iCOMMAND_PROGRESS = 3, $iCOMMAND_UNKNOWN = 4

; check if the call is a sub process and start the respective function
Global $hSubProcess = __IPC_SubCheck("_SubProcess", "_MainProcess")
If @error Then __IPC_Log($__IPC_LOG_ERROR, "__IPC_SubCheck: "&@error&":"&@extended)
; main/sub process both should call shutdown before exit
__IPC_Shutdown()
Exit

Func _MainProcess()

	; start a sub process calling the same script.
	; the _CallbackMain method is called for messages received from the sub process
	; 100 is the parameter provided to the sub process (total items)
	Local $hProcess = __IPC_StartProcess("_CallbackMain", "11")
	; wait for the sub process to finish
	While ProcessExists(__IPC_SubGetPID($hProcess)) And Sleep(10)
	WEnd
EndFunc

Func _CallbackMain($hProcess, $data, $iCmd)
	; $hProcess can be used to differentiate between different sub processes (if multiple are started with the same callback method)
	;~ TODO: That hint above is confusing to me. Is it simply not in use yet
	;~ or is it a left over and can be removed? I mean $hProcess.

	; $data can be a string or binary data, depending on the data sent by the sub process
	; $iCmd contains the command send by the server
	Switch $iCmd
		Case $iCOMMAND_START
			ConsoleWrite("Start processing "&$data&" items"&@crlf)
		Case $iCOMMAND_END
			ConsoleWrite("Finished processing"&@crlf)
		Case $iCOMMAND_PROGRESS
			Local $iTotal = Int(BinaryMid($data, 1, 4)) ; int values are 32bit=>4byte
			Local $iItemsDone = Int(BinaryMid($data, 5, 4)) ; int values are 32bit=>4byte
			Local $iPerc = ($iItemsDone=$iTotal)?100:Mod($iItemsDone, $iTotal)
			ConsoleWrite("Progress: "&$iItemsDone&"/"&$iTotal&" = "&Round($iItemsDone/$iTotal, 2)&" => "&$iPerc&"%"&@crlf)
		Case Else
			ConsoleWrite("Unknown command ["&$iCmd&"]: "&$data&@crlf)
	EndSwitch
EndFunc

Func _SubProcess($hSubProcess)
	Local $iTotalItems = 10
	If UBound($CmdLine)>1 Then $iTotalItems = Int($CmdLine[1])
	ConsoleWrite("Process ["&$hSubProcess&"]: Start processing items: "&$iTotalItems&@crlf)
	__IPC_SubSend($iCOMMAND_START, $iTotalItems)
	If @error Then __IPC_Log($__IPC_LOG_ERROR, "Failed sending", @error, @extended) ; to check for errors when sending
	For $i=0 to $iTotalItems-1
		__IPC_SubSend($iCOMMAND_PROGRESS, Binary($iTotalItems)&Binary($i+1))
	Next
	__IPC_SubSend($iCOMMAND_END, "") ; to sent only a command, make $data empty. Otherwise, the command will be sent as data
	__IPC_SubSend($iCOMMAND_UNKNOWN, "some command")
	ConsoleWrite("Process ["&$hSubProcess&"]: Finished"&@crlf)
EndFunc
