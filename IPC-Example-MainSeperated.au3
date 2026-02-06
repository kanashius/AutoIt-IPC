#cs ----------------------------------------------------------------------------

	 AutoIt Version: 3.3.18.0
	 Author:         Kanashius

	 Script Function:
		Example script for the IPC InterProcessCommunication UDF.

#ce ----------------------------------------------------------------------------
#include "IPC.au3"

; call IPC StartUp for initialization.
__IPC_StartUp($__IPC_LOG_INFO, 80)
If @error Then ConsoleWrite("Error __IPC_StartUp "&@error&":"&@extended&@crlf)

Global $arArguments = [100, 200, 300]
Global $hProcess = __IPC_StartProcess("_CallbackMain", $arArguments, Default, __IPC_GetScriptExecutable("IPC-Example-SubSeperated"))
If @error Then __IPC_Log($__IPC_LOG_ERROR, "Error starting subprocess: "&@error&":"&@extended)

While ProcessExists(__IPC_SubGetPID($hProcess)) And Sleep(10)
WEnd

_Exit()

Func _Exit()
	; call IPC shutdown when the UDF is no longer used.
	__IPC_Shutdown()
	Exit
EndFunc

Func _CallbackMain($hProcess, $data, $iCmd = Default)
	If $iCmd >= 500 And $data="Done" Then
		__IPC_ProcessStop($hProcess)
	Else
		If $data="Done" Then
			__IPC_Log($__IPC_LOG_INFO, "Done: "&$iCmd)
			If $iCmd>=300 Then
				__IPC_Log($__IPC_LOG_INFO, "Send start command for: "&$iCmd+100)
				__IPC_MainSend($hProcess, $iCmd+100, "")
				If @error Then __IPC_Log($__IPC_LOG_ERROR, "MainSend: ", @error, @extended)
			EndIf
		Else
			__IPC_Log($__IPC_LOG_INFO, $data&": "&$iCmd)
		EndIf
	EndIf
EndFunc
