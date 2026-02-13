#cs ----------------------------------------------------------------------------

	 AutoIt Version: 3.3.18.0
	 Author:         Kanashius

	 Script Function:
		Example script for the IPC InterProcessCommunication UDF.
		This example shows multiple sub processes sending data and how the data
		is received.

#ce ----------------------------------------------------------------------------
#include "IPC.au3"

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
	Local $hProcess1 = __IPC_StartProcess("_CallbackMain")
	Local $hProcess2 = __IPC_StartProcess("_CallbackMain")
	; wait for the sub process to finish
	While (ProcessExists(__IPC_SubGetPID($hProcess1)) Or ProcessExists(__IPC_SubGetPID($hProcess2))) And Sleep(10)
	WEnd
EndFunc

; registered as callback in __IPC_StartProcess to be called when data from the sub process is received
Func _CallbackMain($hSubProcess, $iCmd, $arData)
	; $hSubProcess can be used to differentiate between different sub processes (if multiple are started with the same callback method)
	; $iCmd contains the command send by the server, or Default if only data was sent => only Default here
	; $arData contains an array with all the send data
	ConsoleWrite("Data from ["&$hSubProcess&"]: ")
	For $i=0 to UBound($arData)-1
		If $i<>0 Then ConsoleWrite(", ")
		ConsoleWrite($arData[$i])
	Next
	ConsoleWrite(@crlf)
EndFunc

; the sub process main method, registered in __IPC_SubCheck to be called when the script is running as a sub process
Func _SubProcess($hSubProcess)
	; send data to the main process
	__IPC_SubSend("Starting")
	Local $iMs = Random(10, 1000, 1)
	__IPC_SubSend("Start sleep for", $iMs, "ms")
	Sleep($iMs) ; wait random time
	; send data to the main process
	__IPC_SubSend("Done")
EndFunc