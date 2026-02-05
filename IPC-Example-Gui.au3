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

; check if the call is a sub process and start the respective function
Local $hSubProcess = __IPC_SubCheck("_SubProcess", "_MainProcess", "_CallbackSub")
If @error Then __IPC_Log($__IPC_LOG_ERROR, "__IPC_SubCheck: "&@error&":"&@extended)

; main/sub process both should call shutdown before exit
__IPC_Shutdown()
Exit

Func _MainProcess()
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
			GUICtrlSetData($mMainGui.idEdit, "COMMAND_TEST ["&$hProcess&"]: "&$data&@crlf, True)
		Case $iCOMMAND_PROGRESS
			Local $iTotal = Int(BinaryMid($data, 1, 4)) ; int values are 32bit=>4byte
			Local $iItemsDone = Int(BinaryMid($data, 5, 4)) ; int values are 32bit=>4byte
			Local $dProgress = $iItemsDone/$iTotal
			Local $iPerc = Int($dProgress*100)
			GUICtrlSetData($mMainGui.idProgress, $iPerc)
			GUICtrlSetData($mMainGui.idEdit, "COMMAND_PROGRESS ["&$hProcess&"]: "&$iItemsDone&"/"&$iTotal&" = "&Round($dProgress, 2)&" => "&$iPerc&"%"&@crlf, True)
		Case Default
			GUICtrlSetData($mMainGui.idEdit, $data&@crlf, True)
		Case Else
			GUICtrlSetData($mMainGui.idEdit, "COMMAND_UNKNOWN ["&$hProcess&"] ["&$iCmd&"]: "&$data&@crlf, True)
	EndSwitch
EndFunc

Func _SubProcess($hSubProcess)
	Local $iTotalItems = 10
	If UBound($CmdLine)>1 Then $iTotalItems = Int($CmdLine[1])
	__IPC_SubSend("Start processing items") ; send data without a command
	For $i=0 to $iTotalItems-1
		__IPC_SubSend($iCOMMAND_PROGRESS, Binary($iTotalItems)&Binary($i+1))
		Sleep(Random(1,500, 1)) ; just this sleep lets the entire application freeze/crash (why?)
	Next
	__IPC_SubSend("Done processing items")
	__IPC_SubSend($iCOMMAND_TEST, "test command")
	If @error Then __IPC_Log($__IPC_LOG_ERROR, "Failed sending", @error, @extended) ; to check for errors when sending
	__IPC_SubSend($iCOMMAND_UNKNOWN, "") ; send an unknown command
EndFunc

Func _CallbackSub($data, $iCmd = Default)
	ConsoleWrite("Callback Sub: "&$iCmd&" >> "&$data&@crlf)
EndFunc