#cs ----------------------------------------------------------------------------

	 AutoIt Version: 3.3.18.0
	 Author:         Kanashius

	 Script Function:
		Example script for the IPC InterProcessCommunication UDF.
		This example shows how to handle large amount of data.

#ce ----------------------------------------------------------------------------
#include "IPC.au3"

Global Const $iCOMMAND_TEST = 1, $iCOMMAND_UNKNOWN = 2, $iCOMMAND_PROGRESS = 3

; limit the amount of tcprecv calls to 10, so the main process does not freeze
__IPC_StartUp($__IPC_LOG_TRACE, 0, 10)

; check if the call is a sub process and start the respective function
__IPC_SubCheck("_SubProcess", "_MainProcess", Default, Default, $__IPC_LOG_TRACE)
If @error Then __IPC_Log($__IPC_LOG_ERROR, "__IPC_SubCheck: "&@error&":"&@extended)

; main/sub process both should call shutdown before exit
__IPC_Shutdown()
Exit

; the main process main method, registered in __IPC_SubCheck to be called when the script is running as main process (no sub process command line arguments detected)
Func _MainProcess()
	; start a sub process calling the same script.
	; the _CallbackMain method is called for messages received from the sub process
	; 100 is the parameter provided to the sub process (total items)
	Local $hSubProcess = __IPC_StartProcess("_CallbackMain")
	; wait for the sub process to finish
	While ProcessExists(__IPC_SubGetPID($hSubProcess)) And Sleep(10)
		; handle data coming from sub processes
		__IPC_MainProcessing()
		ConsoleWrite("Possibly handle gui events"&@crlf)
		; Local $iMsg = GUIGetMsg()
		; ...
	WEnd
EndFunc

; registered as callback in __IPC_StartProcess to be called when data from the sub process is received
Func _CallbackMain($hSubProcess, $data, $iCmd = Default)
	; $hSubProcess can be used to differentiate between different sub processes (if multiple are started with the same callback method)
	; $data can be a string or binary data, depending on the data sent by the sub process
	; $iCmd only needs to be a parameter, if the sub process sends commands. If the sub process may send commands, but also only data without a command, a default value needs to be specified.
	ConsoleWrite("----------------------------------------------------"&@crlf)
	ConsoleWrite($data&@crlf)
	ConsoleWrite("----------------------------------------------------"&@crlf)
EndFunc

; the sub process main method, registered in __IPC_SubCheck to be called when the script is running as a sub process
Func _SubProcess($hSubProcess)
	ConsoleWrite("----------------------------------------------------"&@crlf)
	Local $sData = ""
	For $i=0 To $__IPC_MaxByteRecv*200 Step 10
		If $i<>0 Then $sData &= @CRLF
		For $j=0 To 10 Step 1
			$sData &= $j
		Next
	Next
	__IPC_SubSend($sData)
	; ConsoleWrite($sData&@crlf)
	ConsoleWrite("----------------------------------------------------"&@crlf)
EndFunc