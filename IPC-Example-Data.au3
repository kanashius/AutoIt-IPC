#cs ----------------------------------------------------------------------------

	 AutoIt Version: 3.3.18.0
	 Author:         Kanashius

	 Script Function:
		Example script for the IPC InterProcessCommunication UDF.
		This example show multiple sub processes sending data

#ce ----------------------------------------------------------------------------
#include "IPC.au3"

; check if the call is a sub process and start the respective function
Local $hSubProcess = __IPC_SubCheck("_SubProcess", "_MainProcess")
If @error Then __IPC_Log($__IPC_LOG_ERROR, "__IPC_SubCheck: "&@error&":"&@extended)

; main/sub process both should call shutdown before exit
__IPC_Shutdown()
Exit

Func _MainProcess()
	; start a sub process calling the same script.
	; the _CallbackMain method is called for messages received from the sub process
	Local $hProcess1 = __IPC_StartProcess("_CallbackMain")
	Local $hProcess2 = __IPC_StartProcess("_CallbackMain")
	; wait for the sub process to finish
	While (ProcessExists(__IPC_SubGetPID($hProcess1)) Or ProcessExists(__IPC_SubGetPID($hProcess2))) And Sleep(10)
	WEnd
EndFunc

Func _CallbackMain($hProcess, $data)
	; $hProcess can be used to differentiate between different sub processes (if multiple are started with the same callback method)
	; $data can be a string or binary data, depending on the data sent by the sub process
	ConsoleWrite("Data from ["&$hProcess&"]: "&$data&@crlf)
EndFunc

Func _SubProcess($hSubProcess)
	; send data to the main process
	__IPC_SubSend("Starting")
	Sleep(Random(10, 1000, 1)) ; wait random time
	; send data to the main process
	__IPC_SubSend("Done")
EndFunc