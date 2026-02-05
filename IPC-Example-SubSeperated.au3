#cs ----------------------------------------------------------------------------

	 AutoIt Version: 3.3.18.0
	 Author:         Kanashius

	 Script Function:
		Example script for the IPC InterProcessCommunication UDF.

#ce ----------------------------------------------------------------------------
#include "IPC.au3"

; __IPC_SubCheck will handle the StartUp call, if needed (e.g. when started as subprocess)
Global $bRun = True

; check if the call is a sub process and start the respective function
Local $hSubProcess = __IPC_SubCheck("_SubProcess", Default, "_CallbackSub", "_CallbackExit", $__IPC_LOG_INFO)
If @error Then
	__IPC_Log($__IPC_LOG_ERROR, "__IPC_SubCheck: "&@error&":"&@extended)
ElseIf $hSubProcess=0 Then
	ConsoleWrite("Error: Not started as subprocess."&@crlf)
EndIf

Exit

Func _SubProcess()
	ConsoleWrite("SubProcess started."&@crlf)
	For $i=1 To UBound($CmdLine)-1
		_process(Int($CmdLine[$i]))
	Next
	While $bRun And Sleep(100)
	WEnd
	ConsoleWrite("SubProcess done."&@crlf)
	__IPC_Shutdown()
	Exit
EndFunc

Func _CallbackSub($data, $iCmd = Default)
	_process($iCmd)
EndFunc

Func _CallbackExit()
	$bRun = False
EndFunc

Func _process($iCmd)
	ConsoleWrite("SubProcess start: "&$iCmd&@crlf)
	__IPC_SubSend($iCmd, "Start")
	If @error Then __IPC_Log($__IPC_LOG_ERROR, "__IPC_SubSend", @error, @extended)
	Sleep(Random(500, 2000, 1))
	__IPC_SubSend($iCmd, "Done")
	If @error Then __IPC_Log($__IPC_LOG_ERROR, "__IPC_SubSend", @error, @extended)
	ConsoleWrite("SubProcess ready: "&$iCmd&@crlf)
EndFunc