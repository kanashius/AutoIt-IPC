#cs ----------------------------------------------------------------------------

	 AutoIt Version: 3.3.18.0
	 Author:         Kanashius

	 Script Function:
		Example script for the IPC InterProcessCommunication UDF.

#ce ----------------------------------------------------------------------------
#include "IPC.au3"

Global Const $iCOMMAND_TEST = 1, $iCOMMAND_UNKNOWN = 2, $iCOMMAND_PROGRESS = 3

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
	ConsoleWrite("Prepare second process"&@crlf)
	Sleep(1000) ; looking at the logs, it shows, that the server is stopped, while no subprocess is running
	Local $hProcess = __IPC_StartProcess("_CallbackMain", "11")
	; wait for the sub process to finish
	While ProcessExists(__IPC_SubGetPID($hProcess)) And Sleep(10)
	WEnd
EndFunc

Func _CallbackMain($hProcess, $data, $iCmd = Default)
	; $hProcess can be used to differentiate between different sub processes (if multiple are started with the same callback method)
	; $data can be a string or binary data, depending on the data sent by the sub process
	; $iCmd only needs to be a parameter, if the sub process sends commands. If the sub process may send commands, but also only data without a command, a default value needs to be specified.
	Switch $iCmd
		Case $iCOMMAND_TEST
			ConsoleWrite("Command 1: "&$data&@crlf)
		Case $iCOMMAND_PROGRESS
			Local $iTotal = Int(BinaryMid($data, 1, 4)) ; int values are 32bit=>4byte
			Local $iItemsDone = Int(BinaryMid($data, 5, 4)) ; int values are 32bit=>4byte
			Local $iPerc = ($iItemsDone=$iTotal)?100:Mod($iItemsDone, $iTotal)
			ConsoleWrite("Progress: "&$iItemsDone&"/"&$iTotal&" = "&Round($iItemsDone/$iTotal, 2)&" => "&$iPerc&"%"&@crlf)
		Case Default
			ConsoleWrite("Data: "&$data&@crlf)
		Case Else
			ConsoleWrite("Unknown command ["&$iCmd&"]: "&$data&@crlf)
	EndSwitch
EndFunc

Func _SubProcess($hSubProcess)
	Local $iTotalItems = 10
	If UBound($CmdLine)>1 Then $iTotalItems = Int($CmdLine[1])
	ConsoleWrite("Process ["&$hSubProcess&"]: Start processing items: "&$iTotalItems&@crlf)
	__IPC_SubSend("Start processing items") ; send data without a command
	For $i=0 to $iTotalItems-1
		__IPC_SubSend($iCOMMAND_PROGRESS, Binary($iTotalItems)&Binary($i+1))
	Next
	__IPC_SubSend("Done processing items")
	__IPC_SubSend($iCOMMAND_TEST, "test command")
	If @error Then __IPC_Log($__IPC_LOG_ERROR, "Failed sending", @error, @extended) ; to check for errors when sending
	__IPC_SubSend($iCOMMAND_UNKNOWN, "") ; send an unknown command
	ConsoleWrite("Process ["&$hSubProcess&"]: Finished"&@crlf)
EndFunc