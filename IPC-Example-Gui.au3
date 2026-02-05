#cs ----------------------------------------------------------------------------

	 AutoIt Version: 3.3.18.0
	 Author:         Kanashius

	 Script Function:
		Example script for the IPC InterProcessCommunication UDF.

#ce ----------------------------------------------------------------------------

#include "IPC.au3"
#include <EditConstants.au3>

Global Const $iCOMMAND_TEST = 1, $iCOMMAND_UNKNOWN = 2, $iCOMMAND_PROGRESS = 3
Global $mMainGui[] ; just a map for all ctrl variables to avoid to many global variables

; check if the call is a sub process
Local $hSubProcess = __IPC_SubCheck("_CallbackSub")
If $hSubProcess<>0 Then ; if it is a sub process, the handle is checked here
	_SubProcess($hSubProcess) ; start the subprocess
Else ; otherwise start the main process
	_MainProcess()
EndIf

; main/sub process both should call shutdown before exit
__IPC_Shutdown()
Exit

Func _MainProcess()
	; call IPC StartUp for initialization. For the subprocess, this is done by the __IPC_SubCheck method.
	__IPC_StartUp($__IPC_LOG_INFO, Default, Default)
	If @error Then ConsoleWrite("Error __IPC_StartUp "&@error&":"&@extended&@crlf)

	Local $iWidth = 800, $iHeight = 600, $iCtrlHeight = 25, $iSpace = 5
	$mMainGui.hGui = GUICreate("Example IPC", $iWidth, $iHeight)
	$mMainGui.idButtonStart = GUICtrlCreateButton("Start subprocess", $iSpace, $iSpace, $iWidth-2*$iSpace, $iCtrlHeight)
	Local $iTop = $iCtrlHeight+$iSpace*2
	$mMainGui.idProgress = GUICtrlCreateProgress($iSpace, $iTop, $iWidth-2*$iSpace, $iCtrlHeight)
	$iTop += $iCtrlHeight+$iSpace*2
	$mMainGui.idEdit = GUICtrlCreateEdit("", $iSpace, $iTop, $iWidth-2*$iSpace, $iHeight-$iTop-$iSpace, BitOR($ES_READONLY, $ES_AUTOVSCROLL, $ES_AUTOHSCROLL))
	GUISetState()

	While True
		Switch GUIGetMsg()
			Case -3
				ExitLoop
			Case $mMainGui.idButtonStart
				GUICtrlSetData($mMainGui.idEdit, "")
				GUICtrlSetData($mMainGui.idProgress, 0)
				Local $hProcess = __IPC_StartProcess("_CallbackMain", "11")
		EndSwitch
	WEnd
EndFunc

Func _CallbackMain($hProcess, $data, $iCmd = Default)
	Switch $iCmd
		Case $iCOMMAND_TEST
			GUICtrlSetData($mMainGui.idEdit, "COMMAND_TEST: "&$data&@crlf, True)
		Case $iCOMMAND_PROGRESS
			Local $iTotal = Int(BinaryMid($data, 1, 4)) ; int values are 32bit=>4byte
			Local $iItemsDone = Int(BinaryMid($data, 5, 4)) ; int values are 32bit=>4byte
			Local $iPerc = ($iItemsDone=$iTotal)?100:Mod($iItemsDone, $iTotal)
			GUICtrlSetData($mMainGui.idProgress, $iPerc)
			GUICtrlSetData($mMainGui.idEdit, "COMMAND_PROGRESS: "&$iItemsDone&"/"&$iTotal&" = "&Round($iItemsDone/$iTotal, 2)&" => "&$iPerc&"%"&@crlf, True)
		Case Default
			GUICtrlSetData($mMainGui.idEdit, $data&@crlf, True)
		Case Else
			GUICtrlSetData($mMainGui.idEdit, "COMMAND_UNKNOWN ["&$iCmd&"]: "&$data&@crlf, True)
	EndSwitch
EndFunc

Func _SubProcess($hSubProcess)
	Local $iTotalItems = 10
	If UBound($CmdLine)>1 Then $iTotalItems = Int($CmdLine[1])
	ConsoleWrite("Process ["&$hSubProcess&"]: Start processing items: "&$iTotalItems&@crlf)
	__IPC_SubSend("Start processing items") ; send data without a command
	ConsoleWrite(">>1"&@crlf)
	For $i=0 to $iTotalItems-1
		ConsoleWrite(">>1.1"&@crlf)
		__IPC_SubSend($iCOMMAND_PROGRESS, Binary($iTotalItems)&Binary($i+1))
		ConsoleWrite(">>1.2"&@crlf)
		Local $iSleep = Random(1,50, 1)
		ConsoleWrite(">>1.3 "&$iSleep&@crlf)
		Sleep($iSleep) ; just this sleep lets the entire application freeze/crash (why?)
		ConsoleWrite(">>1.4"&@crlf)
	Next
	ConsoleWrite(">>2"&@crlf)
	__IPC_SubSend("Done processing items")
	__IPC_SubSend($iCOMMAND_TEST, "test command")
	If @error Then __IPC_Log($__IPC_LOG_ERROR, "Failed sending", @error, @extended) ; to check for errors when sending
	__IPC_SubSend($iCOMMAND_UNKNOWN, "") ; send an unknown command
	ConsoleWrite("Process ["&$hSubProcess&"]: Finished"&@crlf)
EndFunc

Func _CallbackSub($data, $iCmd = Default)
	ConsoleWrite("Callback Sub: "&$iCmd&" >> "&$data&@crlf)
EndFunc