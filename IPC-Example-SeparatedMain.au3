#cs ----------------------------------------------------------------------------

	 AutoIt Version: 3.3.18.0
	 Author:         Kanashius

	 Script Function:
		Example script for the IPC InterProcessCommunication UDF.
		This example shows (together with IPC-Example-SeperatedSub.au3) how the
		UDF works with the main and sub process in different scripts/executables.

#ce ----------------------------------------------------------------------------
#include "IPC.au3"

; call IPC StartUp for initialization.
__IPC_StartUp($__IPC_LOG_INFO, 80)
If @error Then ConsoleWrite("Error __IPC_StartUp "&@error&":"&@extended&@crlf)

; start the sub process with multiple command line arguments
Local $arArguments = [100, 200, 300]
Local $hSubProcess = __IPC_StartProcess("_CallbackMain", $arArguments, Default, __IPC_GetScriptExecutable("IPC-Example-SeparatedSub"))
If @error Then __IPC_Log($__IPC_LOG_ERROR, "Error starting subprocess: "&@error&":"&@extended)

; wait for the sub process to close => without the loop, __IPC_Shutdown would be called in _Exit() and the terminate signal sent to the sub process
While ProcessExists(__IPC_SubGetPID($hSubProcess)) And Sleep(10)
WEnd

_Exit()

Func _Exit()
	; call IPC shutdown when the UDF is no longer used.
	__IPC_Shutdown()
	Exit
EndFunc

; registered as callback in __IPC_StartProcess to be called when data from the sub process is received
Func _CallbackMain($hSubProcess, $iCmd, $arData)
	If $iCmd >= 500 And UBound($arData)>0 And $arData[0]="Done" Then
		; sends the terminate signal to the sub process and disconnects the connection to the sub process. Stdout/Stderr will be processed until the sub process or main process ends
		__IPC_ProcessStop($hSubProcess)
	Else
		If UBound($arData)>0 And $arData[0]="Done" Then
			__IPC_Log($__IPC_LOG_INFO, "Done: "&$iCmd)
			If $iCmd>=300 Then
				__IPC_Log($__IPC_LOG_INFO, "Send start command for: "&$iCmd+100)
				__IPC_MainSendCmd($hSubProcess, $iCmd+100)
				If @error Then __IPC_Log($__IPC_LOG_ERROR, "MainSend: ", @error, @extended)
			EndIf
		Else
			__IPC_Log($__IPC_LOG_INFO, $arData[0]&": "&$iCmd)
		EndIf
	EndIf
EndFunc