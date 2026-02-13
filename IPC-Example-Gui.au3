#cs ----------------------------------------------------------------------------

	 AutoIt Version: 3.3.18.0
	 Author:         Kanashius

	 Script Function:
		Example script for the IPC InterProcessCommunication UDF.
		This example shows how sub processes can be started and stopped through
		user interaction.

#ce ----------------------------------------------------------------------------
#include "IPC.au3"
#include <EditConstants.au3>

Global Const $iCOMMAND_TEST = 1, $iCOMMAND_UNKNOWN = 2, $iCOMMAND_PROGRESS = 3
Global $mMainGui[] ; just a map for all ctrl variables to avoid to many global variables

; check if the call is a sub process and start the respective function
__IPC_SubCheck("_SubProcess", "_MainProcess", "_CallbackSub", "_CallbackSubClose")
If @error Then __IPC_Log($__IPC_LOG_ERROR, "__IPC_SubCheck: "&@error&":"&@extended)

; main/sub process both should call shutdown before exit
__IPC_Shutdown()
Exit

; the main process main method, registered in __IPC_SubCheck to be called when the script is running as main process (no sub process command line arguments detected)
Func _MainProcess()
	Local Static $hSubProcessLast = 0
	Local $iWidth = 800, $iHeight = 600, $iCtrlHeight = 25, $iSpace = 5
	$mMainGui.hGui = GUICreate("Example IPC", $iWidth, $iHeight)
	Local $iButtonWidth = ($iWidth-3*$iSpace)/2
	$mMainGui.idButtonStart = GUICtrlCreateButton("Start subprocess", $iSpace, $iSpace, $iButtonWidth, $iCtrlHeight)
	$mMainGui.idButtonStop = GUICtrlCreateButton("Stop subprocess", $iSpace*2+$iButtonWidth, $iSpace, $iButtonWidth, $iCtrlHeight)
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
				$hSubProcessLast = __IPC_StartProcess("_CallbackMain", "11", "_CallbackSubProcessEnds")
			Case $mMainGui.idButtonStop
				If $hSubProcessLast<>0 Then __IPC_ProcessStop($hSubProcessLast)
		EndSwitch
	WEnd
EndFunc

; registered as callback in __IPC_StartProcess to be called when data from the sub process is received
Func _CallbackMain($hSubProcess, $iCmd, $arData)
	Switch $iCmd
		Case $iCOMMAND_TEST
			GUICtrlSetData($mMainGui.idEdit, "COMMAND_TEST ["&$hSubProcess&"]: "&$arData[0]&@crlf, True)
		Case $iCOMMAND_PROGRESS
			Local $iTotal = $arData[0]
			Local $iItemsDone = $arData[1]
			Local $dProgress = $iItemsDone/$iTotal
			Local $iPerc = Int($dProgress*100)
			GUICtrlSetData($mMainGui.idProgress, $iPerc)
			GUICtrlSetData($mMainGui.idEdit, "COMMAND_PROGRESS ["&$hSubProcess&"]: "&$iItemsDone&"/"&$iTotal&" = "&Round($dProgress, 2)&" => "&$iPerc&"%"&@crlf, True)
		Case Default
			GUICtrlSetData($mMainGui.idEdit, $arData[0]&@crlf, True)
		Case Else
			GUICtrlSetData($mMainGui.idEdit, "COMMAND_UNKNOWN ["&$hSubProcess&"] ["&$iCmd&"] arData["&UBound($arData)&"]"&@crlf, True)
	EndSwitch
EndFunc

; registered as callback in __IPC_StartProcess to be called when a sub process is closed/ends
Func _CallbackSubProcessEnds($hSubProcess)
	__IPC_Log($__IPC_LOG_INFO, "SUBPROCESS ENDS ["&$hSubProcess&"]")
EndFunc

; the sub process main method, registered in __IPC_SubCheck to be called when the script is running as a sub process
Func _SubProcess($hSubProcess)
	Local $iTotalItems = 20
	If UBound($CmdLine)>1 Then $iTotalItems = Int($CmdLine[1])
	__IPC_SubSend("Start processing items") ; send data without a command
	For $i=0 to $iTotalItems-1
		__IPC_SubSendCmd($iCOMMAND_PROGRESS, $iTotalItems, $i+1)
		If @error Then Return SetError(2, 0 , False)
		Sleep(Random(1,500, 1)) ; just this sleep lets the entire application freeze/crash (why?)
	Next
	__IPC_SubSend("Done processing items")
	__IPC_SubSendCmd($iCOMMAND_TEST, "test command")
	If @error Then __IPC_Log($__IPC_LOG_ERROR, "Failed sending", @error, @extended) ; to check for errors when sending
	__IPC_SubSendCmd($iCOMMAND_UNKNOWN) ; send an unknown command
	Return True
EndFunc

; registered as callback in __IPC_SubCheck to be called, when the connection to the main process is seperated
Func _CallbackSubClose()
	__IPC_Log($__IPC_LOG_INFO, "Stop processing items and terminate sub process")
EndFunc

; registered as callback in __IPC_SubCheck to be called when data from the main process is received
Func _CallbackSub($iCmd, $arData)
	ConsoleWrite("Callback Sub: "&$iCmd&" >> "&UBound($arData)&@crlf)
EndFunc