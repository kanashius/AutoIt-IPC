#cs ----------------------------------------------------------------------------

	 AutoIt Version: 3.3.18.0
	 Author:         Kanashius

	 Script Function:
		Example script for the IPC InterProcessCommunication UDF.
		This example shows how commands can be sent and received.
		This includes commands with additional data.

#ce ----------------------------------------------------------------------------
#include "IPC.au3"

Global Const $iCOMMAND_START = 1, $iCOMMAND_END = 2, $iCOMMAND_PROGRESS = 3, $iCOMMAND_UNKNOWN = 4

; check if the call is a sub process and start the respective function
__IPC_SubCheck("_SubProcess", "_MainProcess")
If @error Then __IPC_Log($__IPC_LOG_ERROR, "__IPC_SubCheck: "&@error&":"&@extended)

; main/sub process both should call shutdown before exit
__IPC_Shutdown()
Exit
; registered as callback in __IPC_StartProcess to be called when data from the sub process is received
; the main process main method, registered in __IPC_SubCheck to be called when the script is running as main process (no sub process command line arguments detected)
Func _MainProcess()
	; start a sub process calling the same script.
	; the _CallbackMain method is called for messages received from the sub process
	; 100 is the parameter provided to the sub process (total items)
	Local $hProcess = __IPC_StartProcess("_CallbackMain", "11")
	; wait for the sub process to finish
	While ProcessExists(__IPC_SubGetPID($hProcess)) And Sleep(10)
	WEnd
EndFunc

; registered as callback in __IPC_StartProcess to be called when data from the sub process is received
Func _CallbackMain($hSubProcess, $iCmd, $arData)
	; $hSubProcess can be used to differentiate between different sub processes (if multiple are started with the same callback method)
	; $iCmd contains the command send by the server, or Default if only data was sent
	; $arData contains an array with all the send data or Default if only a command was sent
	Switch $iCmd
		Case $iCOMMAND_START
			ConsoleWrite("Start processing "&$arData[0]&" items"&@crlf)
		Case $iCOMMAND_END
			ConsoleWrite("Finished processing"&@crlf)
		Case $iCOMMAND_PROGRESS
			Local $iTotal = $arData[0]
			Local $iItemsDone = $arData[1]
			Local $iPerc = ($iItemsDone=$iTotal)?100:Mod($iItemsDone, $iTotal)
			ConsoleWrite("Progress: "&$iItemsDone&"/"&$iTotal&" = "&Round($iItemsDone/$iTotal, 2)&" => "&$iPerc&"%"&@crlf)
		Case Default
			ConsoleWrite("Data received"&@crlf)
		Case Else
			ConsoleWrite("Unknown command ["&$iCmd&"] with arData["&UBound($arData)&"] "&@crlf)
	EndSwitch
EndFunc

; the sub process main method, registered in __IPC_SubCheck to be called when the script is running as a sub process
Func _SubProcess($hSubProcess)
	Local $iTotalItems = 10
	If UBound($CmdLine)>1 Then $iTotalItems = Int($CmdLine[1])
	ConsoleWrite("Process ["&$hSubProcess&"]: Start processing items: "&$iTotalItems&@crlf)
	__IPC_SubSendCmd($iCOMMAND_START, $iTotalItems)
	If @error Then __IPC_Log($__IPC_LOG_ERROR, "Failed sending", @error, @extended) ; to check for errors when sending
	For $i=0 to $iTotalItems-1
		__IPC_SubSendCmd($iCOMMAND_PROGRESS, $iTotalItems, $i+1)
	Next
	__IPC_SubSendCmd($iCOMMAND_END) ; to sent only a command, make $data empty. Otherwise, the command will be sent as data
	__IPC_SubSendCmd($iCOMMAND_UNKNOWN, "some command")
	ConsoleWrite("Process ["&$hSubProcess&"]: Finished"&@crlf)
EndFunc