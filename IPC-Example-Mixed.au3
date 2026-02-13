#cs ----------------------------------------------------------------------------

	 AutoIt Version: 3.3.18.0
	 Author:         Kanashius

	 Script Function:
		Example script for the IPC InterProcessCommunication UDF.
		This example shows how only data and commands, as well as commands with
		additional data can be sent and received.

#ce ----------------------------------------------------------------------------
#include "IPC.au3"

Global Const $iCOMMAND_TEST = 1, $iCOMMAND_UNKNOWN = 2, $iCOMMAND_PROGRESS = 3

; check if the call is a sub process and start the respective function
__IPC_SubCheck("_SubProcess", "_MainProcess")
If @error Then __IPC_Log($__IPC_LOG_ERROR, "__IPC_SubCheck: "&@error&":"&@extended)

; main/sub process both should call shutdown before exit
__IPC_Shutdown()
Exit

; the main process main method, registered in __IPC_SubCheck to be called when the script is running as main process (no sub process command line arguments detected)
Func _MainProcess()
	; start a sub process calling the same script.
	; the _CallbackMain method is called for messages received from the sub process
	; 100 is the parameter provided to the sub process (total items)
	Local $hSubProcess = __IPC_StartProcess("_CallbackMain", "11")
	; wait for the sub process to finish
	While ProcessExists(__IPC_SubGetPID($hSubProcess)) And Sleep(10)
	WEnd
	ConsoleWrite("Prepare second process"&@crlf)
	Sleep(1000) ; looking at the logs, it shows, that the server is stopped, while no subprocess is running
	$hSubProcess = __IPC_StartProcess("_CallbackMain", "11")
	; wait for the sub process to finish
	While ProcessExists(__IPC_SubGetPID($hSubProcess)) And Sleep(10)
	WEnd
EndFunc

; registered as callback in __IPC_StartProcess to be called when data from the sub process is received
Func _CallbackMain($hSubProcess, $iCmd, $arData)
	; $hSubProcess can be used to differentiate between different sub processes (if multiple are started with the same callback method)
	; $data can be a string or binary data, depending on the data sent by the sub process
	; $iCmd only needs to be a parameter, if the sub process sends commands. If the sub process may send commands, but also only data without a command, a default value needs to be specified.
	Switch $iCmd
		Case $iCOMMAND_TEST
			If UBound($arData)<1 Then
				ConsoleWrite("$iCOMMAND_TEST failed, missing parameter"&@crlf)
				Return
			EndIf
			ConsoleWrite("Command 1: "&$arData[0]&@crlf)
		Case $iCOMMAND_PROGRESS
			If UBound($arData)<2 Then
				ConsoleWrite("$iCOMMAND_PROGRESS failed, missing parameter"&@crlf)
				Return
			ElseIf Not IsInt($arData[0]) Or Not IsInt($arData[1]) Then
				ConsoleWrite("$iCOMMAND_PROGRESS failed, parameter is not an integer"&@crlf)
				Return
			EndIf
			Local $iTotal = $arData[0]
			Local $iItemsDone = $arData[1]
			Local $iPerc = ($iItemsDone=$iTotal)?100:Mod($iItemsDone, $iTotal)
			ConsoleWrite("Progress: "&$iItemsDone&"/"&$iTotal&" = "&Round($iItemsDone/$iTotal, 2)&" => "&$iPerc&"%"&@crlf)
		Case Default
			If UBound($arData)<1 Then Return
			ConsoleWrite("Data: "&$arData[0]&@crlf)
		Case Else
			ConsoleWrite("Unknown command ["&$iCmd&"]: "&UBound($arData)&@crlf)
	EndSwitch
EndFunc

; the sub process main method, registered in __IPC_SubCheck to be called when the script is running as a sub process
Func _SubProcess($hSubProcess)
	Local $iTotalItems = 10
	If UBound($CmdLine)>1 Then $iTotalItems = Int($CmdLine[1])
	ConsoleWrite("Process ["&$hSubProcess&"]: Start processing items: "&$iTotalItems&@crlf)
	__IPC_SubSend("Start processing items") ; send data without a command
	For $i=0 to $iTotalItems-1
		__IPC_SubSendCmd($iCOMMAND_PROGRESS, $iTotalItems, $i+1)
	Next
	__IPC_SubSend("Done processing items")
	__IPC_SubSendCmd($iCOMMAND_TEST, "test command")
	If @error Then __IPC_Log($__IPC_LOG_ERROR, "Failed sending", @error, @extended) ; to check for errors when sending
	__IPC_SubSendCmd($iCOMMAND_UNKNOWN) ; send an unknown command
	ConsoleWrite("Process ["&$hSubProcess&"]: Finished"&@crlf)
EndFunc