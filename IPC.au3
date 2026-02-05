#include-once
#include <AutoItConstants.au3>
#include "../ToString.au3"

; #INDEX# =======================================================================================================================
; Title .........: IPC (InterProcessCommunication)
; AutoIt Version : 3.3.18.1
; Language ......: English
; Description ...: UDF for inter process communication between the main and child processes.
; Author(s) .....: Kanashius
; Version .......: 0.1.0a
; ===============================================================================================================================

; #GLOBAL CONSTANTS# ============================================================================================================
;
Global Const $__IPC_SERVER = 1, $__IPC_CLIENT = 2
Global Const $__IPC_Port = 40001, $__IPC_ServerPullRate = 100, $__IPC_MaxByteRecv = 1024, $__IPC_ClientPullRate = 100
Global Const $__IPC_MSG_CONNECT = 1, $__IPC_MSG_DISCONNECT = 2, $__IPC_MSG_DATA = 3, $__IPC_MSG_DATA_STR = 4
Global Const $__IPC_MSG_DATA_CMD = 5, $__IPC_MSG_DATA_CMD_STR = 6
Global Const $__IPC_LOG_FATAL = 1, $__IPC_LOG_ERROR = 2, $__IPC_LOG_WARN = 3, $__IPC_LOG_INFO = 4, $__IPC_LOG_DEBUG = 5
Global Const $__IPC_LOG_TRACE = 6
Global Const $__IPC_PARAM_CONNECT = "--IPC-CONNECT"
; ===============================================================================================================================

; #INTERNAL_USE_ONLY GLOBAL VARIABLES # =========================================================================================
Global $__IPC__Data[]
; ===============================================================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: __IPC_StartUp
; Description ...: StartUp of the ICP UDF initializing required variables. Must be called before using other UDF functions.
; Syntax ........: __IPC_StartUp([$iPort = Default])
; Parameters ....: $iPort               - [optional] Default: 40001. The TCP-Port to use for IPC.
; Return values .: True on success.
; Author ........: Kanashius
; Modified ......:
; Remarks .......:
;                 If the provided $iPort is already in use, the tool loops over $iPort by adding one, until a free port is found.
;                 Use __IPC_GetServerPort to retrieve the actual listen port.
;
;                 Errors:
;                 1 - Parameter not valid (@extended: 1 - $iType)
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func __IPC_StartUp($iLogLevel = $__IPC_LOG_INFO, $iServerPullRate = Default, $iServerPort = Default)
	If Not UBound(MapKeys($__IPC__Data))=0 Then Return SetError(2, 0, False)
	If $iServerPullRate = Default Then $iServerPullRate = $__IPC_ServerPullRate
	If $iServerPort = Default Then $iServerPort = $__IPC_Port
	If Not IsInt($iServerPullRate) Or $iServerPullRate<=1 Then Return SetError(1, 2, False)
	If Not IsInt($iServerPort) Or $iServerPort<1024 Or $iServerPort>65535 Then Return SetError(1, 3, False)
	If Not IsInt($iLogLevel) Or $iLogLevel<0 Or $iLogLevel>$__IPC_LOG_TRACE Then Return SetError(1, 4, False)
	Local $iTypeBefore = 0
	If Not MapExists($__IPC__Data, "iLogLevel") Then $__IPC__Data.iLogLevel = $iLogLevel
	TCPStartup()
	Local $mServer[], $mConnects[], $mProcesses[]
	$mServer.mConnects = $mConnects
	$mServer.mProcesses = $mProcesses
	$mServer.iServerPullRate = $iServerPullRate
	$mServer.iServerStartPort = $iServerPort
	$mServer.iListen = Default
	$mServer.iPort = Default
	$mServer.iOpenProcesses = 0
	$__IPC__Data.mServer = $mServer
	Local $mClient[]
	$mClient.iSocket = Default
	$mClient.dataBuffer = Default
	$mClient.iDataBufferSize = Default
	$mClient.iLastCommand = Default
	$mClient.iCommandBytes = Default
	$mClient.iPullRate = $__IPC_ClientPullRate
	$__IPC__Data.mClient = $mClient
	__IPC_Log($__IPC_LOG_INFO, "IPC started")
	Return True
EndFunc

Func __IPC_Shutdown()
	Local $arProcesses = MapKeys($__IPC__Data.mServer.mProcesses)
	For $i=0 To UBound($arProcesses)-1
		__IPC__ServerProcessRemove($arProcesses[$i], True)
	Next
	MapRemove($__IPC__Data, "iType")
	Local $bClient = False
	If $__IPC__Data.mClient.iSocket<>Default Then
		$bClient = True
		TCPSend($__IPC__Data.mClient.iSocket, $__IPC_MSG_DISCONNECT)
		TCPCloseSocket($__IPC__Data.mClient.iSocket)
		$__IPC__Data.mClient.iSocket = Default
		If $__IPC__Data.mClient.sCallback<>Default Then AdlibUnRegister("__IPC__ClientWorker")
	EndIf
	Local $mData[]
	$__IPC__Data = $mData
	__IPC_Log($__IPC_LOG_INFO, "IPC shutdown")
	If $bClient Then Sleep(100) ; wait a moment to enable the last stdoutread/stderrread
	TCPShutdown()
EndFunc

; See Run for parameters $sWorkingDir, $show, opt_flag and for the error/extended codes, $STDIO_INHERIT_PARENT => No StdOut/StdErr handling
Func __IPC_StartProcess($sCallback = Default, $arguments = Default, $sExecutable = Default, $sWorkingDir = "", $show = @SW_HIDE, $opt_flag = BitOR($STDOUT_CHILD, $STDERR_CHILD))
	If Not __IPC__ServerIsRunning() Then __IPC__ServerStart()
	If $sExecutable=Default Then
		If @ScriptFullPath=@AutoItExe Then
			$sExecutable = '"'&@ScriptFullPath&'"'
		Else
			$sExecutable = '"'&@AutoItExe&'" "'&@ScriptFullPath&'"'
		EndIf
	EndIf
	If $sCallback<>Default And Not IsFunc(Execute($sCallback)) Then Return SetError(1, 1, -1)
	If $arguments<>Default And Not IsString($arguments) And Not IsArray($arguments) Then Return SetError(1, 2, 0)
	If $sExecutable<>Default And Not IsString($sExecutable) Then Return SetError(1, 3, 0)
	If Not IsString($sWorkingDir) Then Return SetError(1, 4, 0)
	If $show<>@SW_SHOW And $show<>@SW_HIDE And $show<>@SW_MINIMIZE And $show<>@SW_MAXIMIZE Then Return SetError(1, 5, 0)
	If Not IsInt($opt_flag) Then Return SetError(1, 6, 0)
	; create process handle
	Local $mProcess[]
	$mProcess.bStdErr = (BitAND($opt_flag, $STDERR_CHILD)?(True):(False))
	$mProcess.bStdOut = ((BitAND($opt_flag, $STDOUT_CHILD) Or BitAND($opt_flag, $STDERR_MERGED))?(True):(False))
	$mProcess.iSocket = Default
	Local $iProcess = MapAppend($__IPC__Data.mServer.mProcesses, $mProcess)
	Local $hProcess = __IPC__ProcessIdToHandle($iProcess)
	; create arguments
	Local $sArguments = $__IPC_PARAM_CONNECT&" "&$__IPC__Data.mServer.iPort&" "&$hProcess
	If IsString($arguments) Then
		$sArguments &= " "&$arguments
	ElseIf UBound($arguments)>0 Then
		For $i=0 to UBound($arguments)-1 Step 1
			$sArguments&=' "'&StringReplace($arguments[$i], '"', '""')&'"'
		Next
	EndIf
	__IPC_Log($__IPC_LOG_INFO, "Start process: "&$sExecutable)
	__IPC_Log($__IPC_LOG_DEBUG, @TAB&" with arguments: "&$sArguments)
	Local $sCmd = $sExecutable&" "&$sArguments
	Local $iPID = Run($sCmd, $sWorkingDir, $show, $opt_flag)
	Local $iError = @error, $iExtended = @extended
	$__IPC__Data["mServer"]["mProcesses"][$iProcess]["iPID"] = $iPID
	$__IPC__Data["mServer"]["mProcesses"][$iProcess]["hProcess"] = $hProcess
	$__IPC__Data["mServer"]["mProcesses"][$iProcess]["sCallback"] = $sCallback
	$__IPC__Data["mServer"]["iOpenProcesses"] += 1
	If $iError Then
		__IPC__ServerProcessRemove($iProcess, True)
		__IPC_Log($__IPC_LOG_ERROR, "Failed process start: "&$sCmd)
		Return SetError($iError, $iExtended, 0)
	EndIf
	Return SetExtended($iExtended, $hProcess)
EndFunc

Func __IPC_SubGetPID($hProcess)
	Local $iProcess = __IPC__ProcessHandleToId($hProcess)
	If @error Then Return SetError(1, 1, 0)
	Return $__IPC__Data.mServer.mProcesses[$iProcess].iPID
EndFunc

Func __IPC_SubCheck($sCallback = Default, $iLogLevel = $__IPC_LOG_INFO, $iPullRate = Default)
	If $sCallback<>Default And Not IsFunc(Execute($sCallback)) Then Return SetError(1, 1, 0)
	If $iPullRate = Default Then $iPullRate = $__IPC_ClientPullRate
	If Not IsInt($iLogLevel) Or $iLogLevel<0 Or $iLogLevel>$__IPC_LOG_TRACE Then Return SetError(1, 2, False)
	If Not IsInt($iPullRate) Or $iPullRate<=1 Then Return SetError(1, 3, False)
	Local $iPort = Default, $hProcess = Default
	If UBound($CmdLine)>=4 Then
		If $CmdLine[1]=$__IPC_PARAM_CONNECT Then
			Local $iPort = Int($CmdLine[2])
			Local $hProcess = Int($CmdLine[3])
		EndIf
		Local $arCmdLine[UBound($CmdLine)-3]
		$arCmdLine[0] = UBound($arCmdLine)-1
		For $i=4 to UBound($CmdLine)-1
			$arCmdLine[$i-3] = $CmdLine[$i]
		Next
		$CmdLine = $arCmdLine
	EndIf
	If $iPort<>Default And $hProcess<>Default Then
		__IPC_StartUp($iLogLevel)
		If @error Then Return SetError(3, @error, False)
		__IPC_Log($__IPC_LOG_INFO, "Connect: "&$iPort&" >> "&$hProcess)
		Local $iSocket = TCPConnect("127.0.0.1", $iPort)
		If @error Then
			__IPC_Log($__IPC_LOG_ERROR, "Could not connect to main process: "&$iPort&" > "&$hProcess)
			Return SetError(2, 0, 0)
		EndIf
		$__IPC__Data["mClient"]["iSocket"] = $iSocket
		$__IPC__Data["mClient"]["sCallback"] = $sCallback
		$__IPC__Data["mClient"]["iPullRate"] = $iPullRate
		If $sCallback<>Default Then AdlibRegister("__IPC__ClientWorker", $__IPC__Data.mClient.iPullRate)
		TCPSend($iSocket, Binary($__IPC_MSG_CONNECT)&Binary($hProcess))
		Return $hProcess
	EndIf
	Return 0
EndFunc

Func __IPC_SubSend($iCmdOrData, $data = Default)
	If $__IPC__Data.mClient.iSocket=Default Then Return SetError(2, 0, False)
	Local $bResult = __IPC__SendMsg($__IPC__Data.mClient.iSocket, $iCmdOrData, $data)
	If @error Then Return SetError(@error, @extended, $bResult)
	Return $bResult
EndFunc

Func __IPC_MainSend($hProcess, $iCmdOrData, $data = Default)
	Local $iProcess = __IPC__ProcessHandleToId($hProcess)
	If @error Then Return SetError(1, 1, False)
	Local $iSocket = $__IPC__Data.mServer.mProcesses[$iProcess].iSocket
	If $iSocket=Default Then Return SetError(3, 0, False)
	Local $bResult = __IPC__SendMsg($iSocket, $iCmdOrData, $data)
	If @error=1 Then Return SetError(@error, @extended+1, $bResult)
	If @error Then Return SetError(@error, @extended, $bResult)
	Return $bResult
EndFunc

Func __IPC_Log($iLevel, $sMsg, $iError=Default, $iExtended = Default, $hSubProcess = Default, $iLine = @ScriptLineNumber)
	If $iLevel>$__IPC__Data.iLogLevel Then Return False
	Local $sError = ""
	If $iError<>Default And $iExtended<>Default Then
		$sError = " [Error: "&$iError&", Extended: "&$iExtended&"]"
	ElseIf $iError<>Default Then
		$sError = " [Error: "&$iError&"]"
	ElseIf $iExtended<>Default Then
		$sError = " [Extended: "&$iExtended&"]"
	EndIf
	Local $sLevel
	Switch $iLevel
		Case $__IPC_LOG_FATAL
			$sLevel = "FATAL"
		Case $__IPC_LOG_ERROR
			$sLevel = "ERROR"
		Case $__IPC_LOG_WARN
			$sLevel = "WARN "
		Case $__IPC_LOG_INFO
			$sLevel = "INFO "
		Case $__IPC_LOG_DEBUG
			$sLevel = "DEBUG"
		Case $__IPC_LOG_TRACE
			$sLevel = "TRACE"
	EndSwitch
	If $hSubProcess<>Default Then
		ConsoleWrite(">"&"Sub["&$hSubProcess&"] "&$sLevel&" ["&@YEAR&"/"&@MON&"/"&@MDAY&" "&@HOUR&":"&@MIN&":"&@SEC&"."&@MSEC&"] "&$sMsg&$sError&@crlf)
	Else
		ConsoleWrite(">"&$sLevel&" ["&@YEAR&"/"&@MON&"/"&@MDAY&" "&@HOUR&":"&@MIN&":"&@SEC&"."&@MSEC&"] "&$sMsg&$sError&@crlf)
	EndIf
	Return True
EndFunc

Func __IPC__SendMsg($iSocket, $iCmdOrData, $data = Default)
	Local $bCmd = True
	If $data=Default Then
		$data = $iCmdOrData
		$bCmd = False
	EndIf
	Local $iMsg = $__IPC_MSG_DATA
	If Not IsBinary($data) Then
		If Not IsString($data) Then $data = String($data)
		$iMsg = $__IPC_MSG_DATA_STR
		$data = StringToBinary($data, 2)
	EndIf
	If $bCmd Then
		If Not IsInt($iCmdOrData) Then Return SetError(1, 1, False)
		$data = Binary($iCmdOrData)&$data
		If $iMsg=$__IPC_MSG_DATA Then
			$iMsg = $__IPC_MSG_DATA_CMD
		Else
			$iMsg = $__IPC_MSG_DATA_CMD_STR
		EndIf
	EndIf
	Local $iLen = BinaryLen($data)
	TCPSend($iSocket, Binary($iMsg)&Binary($iLen))
	If @error Then Return SetError(2, __IPC__SubDisconnected(), False)
	For $i=1 To $iLen Step $__IPC_MaxByteRecv
		Local $bSend = BinaryMid($data, $i, $__IPC_MaxByteRecv)
		TCPSend($iSocket, $bSend)
		If @error Then Return SetError(2, __IPC__SubDisconnected(), False)
	Next
	Return True
EndFunc

Func __IPC__SubDisconnected()
	__IPC_Log($__IPC_LOG_ERROR, "Connection to main process lost.")
	__IPC_Shutdown()
	Return 0
EndFunc

Func __IPC__ServerStart()
	If $__IPC__Data.mServer.iListen<>Default Then Return SetError(2, 0, False) ; server already open
	Local $iPort = $__IPC__Data.mServer.iServerStartPort
	Local $iListen = -1
	While True
		Local $iListen = TCPListen("127.0.0.1", $iPort)
		If @error=1 Then Return SetError(2, 0, False)
		If $iListen>=0 Then ExitLoop
		$iPort+=1
		If $iPort>65535 Then $iPort = 1024
		If $iPort=$__IPC__Data.mServer.iServerStartPort-1 Then Return SetError(3, 0, False)
	WEnd
	If $iListen>0 Then
		AdlibRegister("__IPC__ServerWorker", $__IPC__Data.mServer.iServerPullRate)
		$__IPC__Data.mServer.iListen = $iListen
		$__IPC__Data.mServer.iPort = $iPort
		__IPC_Log($__IPC_LOG_INFO, "IPC Server listening at 127.0.0.1:"&$iPort)
	EndIf
	Return True
EndFunc

Func __IPC__ServerIsRunning()
	Return $__IPC__Data.mServer.iListen<>Default
EndFunc

Func __IPC__ServerStop()
	If $__IPC__Data.mServer.iListen=Default Then Return SetError(2, 0, False)
	TCPCloseSocket($__IPC__Data.mServer.iListen)
	$__IPC__Data.mServer.iListen = Default
	AdlibUnRegister("__IPC__ServerWorker")
	__IPC_Log($__IPC_LOG_INFO, "IPC Server stopped")
	Return True
EndFunc

Func __IPC__ClientWorker()
	__IPC__ClientProcessMessages()
EndFunc

Func __IPC__ServerWorker()
	__IPC__ServerAccept()
	__IPC__ServerProcessMessages()
	__IPC__ServerProcessStdOut()
EndFunc

Func __IPC__ServerProcessStdOut()
	__IPC_Log($__IPC_LOG_TRACE, "Run __IPC__ServerProcessStdOut")
	Local $arProcesses = MapKeys($__IPC__Data.mServer.mProcesses)
	For $i=0 to UBound($arProcesses)-1 Step 1
		__IPC_Log($__IPC_LOG_TRACE, "Check std of $iProcess: "&$arProcesses[$i])
		Local $mProcess = $__IPC__Data.mServer.mProcesses[$arProcesses[$i]]
		If $mProcess.bStdOut Then
			__IPC__ServerProcessLogStd($arProcesses[$i])
		EndIf
		If $mProcess.bStdErr Then
			__IPC__ServerProcessLogStd($arProcesses[$i], True)
		EndIf
		If Not ProcessExists($mProcess.iPID) Then __IPC__ServerProcessRemove($arProcesses[$i])
	Next
	__IPC_Log($__IPC_LOG_TRACE, "Done __IPC__ServerProcessStdOut")
EndFunc

Func __IPC__ServerProcessLogStd($iProcess, $bErr = False)
	If MapExists($__IPC__Data.mServer.mProcesses, $iProcess) Then
		Local $mProcess = $__IPC__Data.mServer.mProcesses[$iProcess]
		Local $sData
		If Not $bErr Then $sData = StdoutRead($mProcess.iPID)
		If $bErr Then $sData = StderrRead($mProcess.iPID)
		If @error Then Return SetError(2, 0, 0)
		If @extended>0 Then
			Local $arData = StringSplit($sData, @CRLF, 3)
			For $i=0 To UBound($arData)-1
				If $i=UBound($arData)-1 And StringLen($arData[$i])=0 Then ContinueLoop
				If $bErr Then
					__IPC_Log($__IPC_LOG_ERROR, $arData[$i], Default, Default, $mProcess.hProcess)
				Else
					__IPC_Log($__IPC_LOG_INFO, $arData[$i], Default, Default, $mProcess.hProcess)
				EndIf
			Next
		EndIf
	EndIf
EndFunc

Func __IPC__ServerAccept()
	__IPC_Log($__IPC_LOG_TRACE, "Run __IPC__ServerAccept")
	While True
		Local $iTimeout = Opt("TCPTimeout", 0) ; disable 100ms timeout for TCPAccept
		Local $iSocket = TCPAccept($__IPC__Data.mServer.iListen)
		Opt("TCPTimeout", $iTimeout) ; reset to old timeout for users
		If $iSocket=-1 Then ExitLoop
		__IPC_Log($__IPC_LOG_INFO, "Client connect: "&$iSocket)
		Local $mConn[]
		$mConn.iSocket = $iSocket
		$mConn.iLastCommand = Default
		$mConn.iDataSize = Default
		$mConn.dataBuffer = Default
		$mConn.iDataBufferSize = Default
		$mConn.hProcess = Default
		$mConn.iCommandBytes = Default
		$__IPC__Data["mServer"]["mConnects"][$iSocket] = $mConn
		$__IPC__Data["mServer"]["iOpenProcesses"] -=1
	WEnd
	__IPC_Log($__IPC_LOG_TRACE, "Done __IPC__ServerAccept")
EndFunc

Func __IPC__ClientProcessMessages()
	__IPC_Log($__IPC_LOG_TRACE, "Run __IPC__ClientProcessMessages")
	Local $iSocket = $__IPC__Data.mClient.iSocket
	If $iSocket = Default Then __IPC__SubDisconnected()
	While True
		Local $bData = TCPRecv($iSocket, $__IPC_MaxByteRecv, 1)
		If @error Then
			__IPC_Log($__IPC_LOG_ERROR, "Connection to main lost")
			__IPC__SubDisconnected()
			ExitLoop
		ElseIf BinaryLen($bData)=0 Then
			__IPC_Log($__IPC_LOG_TRACE, "Nothing received")
			ContinueLoop
		EndIf
		Local $iBinLen = BinaryLen($bData)
		__IPC_Log($__IPC_LOG_TRACE, "Received: "&$iBinLen&" >> "&$bData)
		If $__IPC__Data.mClient.dataBuffer=Default Then
			$__IPC__Data["mClient"]["dataBuffer"] = $bData
			$__IPC__Data["mClient"]["iDataBufferSize"] = $iBinLen
		Else
			$__IPC__Data["mClient"]["dataBuffer"] &= $bData
			$__IPC__Data["mClient"]["iDataBufferSize"] += $iBinLen
		EndIf
		If $iBinLen<$__IPC_MaxByteRecv Then ExitLoop ; more data may be available
	WEnd
	While $__IPC__Data.mClient.iDataBufferSize>0
		If $__IPC__Data.mClient.iLastCommand=Default Then
			Local $bData = __IPC__ClientReadBytes(4)
			If Not @error Then $__IPC__Data["mClient"]["iLastCommand"] = $bData
		EndIf
		Local $iCmd = $__IPC__Data.mClient.iLastCommand
		Switch $iCmd
			Case $__IPC_MSG_DATA, $__IPC_MSG_DATA_STR, $__IPC_MSG_DATA_CMD, $__IPC_MSG_DATA_CMD_STR
				If $__IPC__Data.mClient.iCommandBytes = Default Then
					Local $bData = __IPC__ClientReadBytes(4)
					If Not @error Then
						$__IPC__Data["mClient"]["iCommandBytes"] = Int($bData)
					EndIf
				Else
					Local $bData = __IPC__ClientReadBytes($__IPC__Data.mClient.iCommandBytes)
					If Not @error Then
						Local $iDataCommand = Default
						If $iCmd = $__IPC_MSG_DATA_CMD Or $iCmd = $__IPC_MSG_DATA_CMD_STR Then
							$iDataCommand = Int(BinaryMid($bData, 1, 4))
							$bData = BinaryMid($bData, 5)
						EndIf
						If $iCmd = $__IPC_MSG_DATA_STR Or $iCmd = $__IPC_MSG_DATA_CMD_STR Then $bData=BinaryToString($bData, 2)
						Local $sCallback = $__IPC__Data.mClient.sCallback
						If $sCallback<>Default And $iDataCommand<>Default Then
							__IPC_Log($__IPC_LOG_DEBUG, "MSG_DATA_CMD Received data: "&$iSocket&" >> "&$iDataCommand&" >> "&$bData)
							Call($sCallback, $bData, $iDataCommand)
							If @error Then __IPC_Log($__IPC_LOG_ERROR, "Error calling: "&$sCallback&" with 2 parameters")
						ElseIf $sCallback<>Default Then
							__IPC_Log($__IPC_LOG_DEBUG, "MSG_DATA Received data: "&$iSocket&" >> "&$bData)
							Call($sCallback, $bData)
							If @error Then __IPC_Log($__IPC_LOG_ERROR, "Error calling: "&$sCallback&" with 1 parameter")
						EndIf
						$__IPC__Data["mClient"]["iCommandBytes"] = Default
						$__IPC__Data["mClient"]["iLastCommand"] = Default
					EndIf
				EndIf
			Case $__IPC_MSG_DISCONNECT
				__IPC_Log($__IPC_LOG_INFO, "Main disconnected")
				__IPC__SubDisconnected()
				ExitLoop
		EndSwitch
	WEnd
	__IPC_Log($__IPC_LOG_TRACE, "Done __IPC__ClientProcessMessages")
EndFunc

Func __IPC__ClientReadBytes($iBytes)
	If Not IsInt($iBytes) Or $iBytes<=0 Then Return SetError(1, 1, 0)
	If $__IPC__Data.mClient.iDataBufferSize < $iBytes Then Return SetError(2, 0, 0)
	Local $bData = BinaryMid($__IPC__Data.mClient.dataBuffer, 1, $iBytes)
	$__IPC__Data["mClient"]["dataBuffer"] = BinaryMid($__IPC__Data.mClient.dataBuffer, $iBytes+1)
	$__IPC__Data["mClient"]["iDataBufferSize"] = BinaryLen($__IPC__Data.mClient.dataBuffer)
	Return $bData
EndFunc

Func __IPC__ServerProcessMessages()
	__IPC_Log($__IPC_LOG_TRACE, "Run __IPC__ServerProcessMessages")
	Local $arSockets = MapKeys($__IPC__Data.mServer.mConnects)
	; read new data from socket
	For $i=0 to UBound($arSockets)-1 Step 1
		Local $iSocket = $arSockets[$i]
		Local $bData = TCPRecv($iSocket, $__IPC_MaxByteRecv, 1)
		If @error Then
			__IPC_Log($__IPC_LOG_ERROR, "Connection lost: "&$iSocket)
			__IPC__ServerClientDisconnect($iSocket, True)
			ContinueLoop
		ElseIf BinaryLen($bData)=0 Then
			__IPC_Log($__IPC_LOG_TRACE, "Nothing received: "&$iSocket)
			ContinueLoop
		EndIf
		Local $iBinLen = BinaryLen($bData)
		__IPC_Log($__IPC_LOG_TRACE, "Received: "&$iSocket&":"&$iBinLen&" >> "&$bData)
		If $__IPC__Data["mServer"]["mConnects"][$iSocket]["dataBuffer"]=Default Then
			$__IPC__Data["mServer"]["mConnects"][$iSocket]["dataBuffer"] = $bData
			$__IPC__Data["mServer"]["mConnects"][$iSocket]["iDataBufferSize"] = $iBinLen
		Else
			$__IPC__Data["mServer"]["mConnects"][$iSocket]["dataBuffer"] &= $bData
			$__IPC__Data["mServer"]["mConnects"][$iSocket]["iDataBufferSize"] += $iBinLen
		EndIf
		If $iBinLen>=$__IPC_MaxByteRecv Then $i-=1 ; more data may be available, maybe limit this to 10 tries
	Next
	__IPC_Log($__IPC_LOG_TRACE, "Do process __IPC__ServerProcessMessages")
	; process data from socket
	Local $arSockets = MapKeys($__IPC__Data.mServer.mConnects)
	For $i=0 to UBound($arSockets)-1 Step 1
		Local $iSocket = $arSockets[$i]
		While $__IPC__Data.mServer.mConnects[$iSocket]["iDataBufferSize"]>0
			If $__IPC__Data.mServer.mConnects[$iSocket]["iLastCommand"]=Default Then
				Local $bData = __IPC__ServerReadBytes($iSocket, 4)
				If Not @error Then $__IPC__Data["mServer"]["mConnects"][$iSocket]["iLastCommand"] = $bData
			EndIf
			Local $iCmd = $__IPC__Data.mServer.mConnects[$iSocket]["iLastCommand"]
			Switch $iCmd
				Case $__IPC_MSG_DATA, $__IPC_MSG_DATA_STR, $__IPC_MSG_DATA_CMD, $__IPC_MSG_DATA_CMD_STR
					If $__IPC__Data["mServer"]["mConnects"][$iSocket]["iCommandBytes"] = Default Then
						Local $bData = __IPC__ServerReadBytes($iSocket, 4)
						If Not @error Then
							$__IPC__Data["mServer"]["mConnects"][$iSocket]["iCommandBytes"] = Int($bData)
						EndIf
					Else
						Local $bData = __IPC__ServerReadBytes($iSocket, $__IPC__Data.mServer.mConnects[$iSocket]["iCommandBytes"])
						If Not @error Then
							Local $iDataCommand = Default
							If $iCmd = $__IPC_MSG_DATA_CMD Or $iCmd = $__IPC_MSG_DATA_CMD_STR Then
								$iDataCommand = Int(BinaryMid($bData, 1, 4))
								$bData = BinaryMid($bData, 5)
							EndIf
							If $iCmd = $__IPC_MSG_DATA_STR Or $iCmd = $__IPC_MSG_DATA_CMD_STR Then $bData=BinaryToString($bData, 2)
							Local $hProcess = $__IPC__Data.mServer.mConnects[$iSocket].hProcess
							Local $iProcess = __IPC__ProcessHandleToId($hProcess)
							If @error Then ContinueLoop ; should not happen, as long as the connection is there
							Local $sCallback = $__IPC__Data.mServer.mProcesses[$iProcess].sCallback
							If $sCallback<>Default And $iDataCommand<>Default Then
								__IPC_Log($__IPC_LOG_DEBUG, "MSG_DATA_CMD Received data: "&$iSocket&" >> "&$iDataCommand&" >> "&$bData)
								Call($sCallback, $hProcess, $bData, $iDataCommand)
								If @error Then __IPC_Log($__IPC_LOG_ERROR, "Error calling: "&$sCallback&" with 2 parameters")
							ElseIf $sCallback<>Default Then
								__IPC_Log($__IPC_LOG_DEBUG, "MSG_DATA Received data: "&$iSocket&" >> "&$bData)
								Call($sCallback, $hProcess, $bData)
								If @error Then __IPC_Log($__IPC_LOG_ERROR, "Error calling: "&$sCallback&" with 1 parameter")
							EndIf
							$__IPC__Data["mServer"]["mConnects"][$iSocket]["iCommandBytes"] = Default
							$__IPC__Data["mServer"]["mConnects"][$iSocket]["iLastCommand"] = Default
						EndIf
					EndIf
				Case $__IPC_MSG_CONNECT
					Local $bData = __IPC__ServerReadBytes($iSocket, 4)
					If Not @error Then
						__IPC_Log($__IPC_LOG_INFO, "Subprocess connected: "&$iSocket&" Process: "&Int($bData))
						Local $hProcess = Int($bData)
						Local $iProcess = __IPC__ProcessHandleToId($hProcess)
						If Not @error Then
							$__IPC__Data["mServer"]["mConnects"][$iSocket]["hProcess"] = $hProcess
							$__IPC__Data["mServer"]["mProcesses"][$iProcess]["iSocket"] = $iSocket
							$__IPC__Data["mServer"]["mConnects"][$iSocket]["iLastCommand"] = Default
						EndIf
					EndIf
				Case $__IPC_MSG_DISCONNECT
					__IPC_Log($__IPC_LOG_INFO, "Subprocess disconnected: "&$iSocket)
					__IPC__ServerClientDisconnect($iSocket)
					ExitLoop
			EndSwitch
		WEnd
	Next
	__IPC_Log($__IPC_LOG_TRACE, "Done __IPC__ServerProcessMessages")
EndFunc

Func __IPC__ServerReadBytes($iSocket, $iBytes)
	If Not IsInt($iSocket) Or Not MapExists($__IPC__Data.mServer.mConnects, $iSocket) Then Return SetError(1, 1, 0)
	If Not IsInt($iBytes) Or $iBytes<=0 Then Return SetError(1, 2, 0)
	If $__IPC__Data["mServer"]["mConnects"][$iSocket]["iDataBufferSize"] < $iBytes Then Return SetError(2, 0, 0)
	Local $bData = BinaryMid($__IPC__Data["mServer"]["mConnects"][$iSocket]["dataBuffer"], 1, $iBytes)
	$__IPC__Data["mServer"]["mConnects"][$iSocket]["dataBuffer"] = BinaryMid($__IPC__Data["mServer"]["mConnects"][$iSocket]["dataBuffer"], $iBytes+1)
	$__IPC__Data["mServer"]["mConnects"][$iSocket]["iDataBufferSize"] = BinaryLen($__IPC__Data.mServer.mConnects[$iSocket]["dataBuffer"])
	Return $bData
EndFunc

Func __IPC__ServerClientDisconnect($iSocket, $bError = False)
	If Not IsInt($iSocket) Or Not MapExists($__IPC__Data.mServer.mConnects, $iSocket) Then Return SetError(1, 1, False)
	TCPSend($iSocket, $__IPC_MSG_DISCONNECT)
	TCPCloseSocket($__IPC__Data.mServer.mConnects[$iSocket].iSocket)
	__IPC_Log($__IPC_LOG_INFO, "Disconnected: "&$iSocket)
	Local $iProcess = __IPC__ProcessHandleToId($__IPC__Data["mServer"]["mConnects"][$iSocket]["hProcess"])
	If Not @error Then
		$__IPC__Data["mServer"]["mProcesses"][$iProcess]["iSocket"] = Default
		__IPC__ServerProcessRemove($iProcess, $bError)
	EndIf
	MapRemove($__IPC__Data.mServer.mConnects, $iSocket)
	If UBound(MapKeys($__IPC__Data.mServer.mProcesses))=0 Then __IPC__ServerStop()
	return True
EndFunc

Func __IPC__ServerProcessRemove($iProcess, $bError = False)
	If Not IsInt($iProcess) And Not MapExists($__IPC__Data.mServer.mProcesses, $iProcess) Then Return SetError(1, 0, False)
	Local $mProcess = $__IPC__Data.mServer.mProcesses[$iProcess]
	__IPC__ServerProcessLogStd($iProcess) ; handle output a last time
	MapRemove($__IPC__Data.mServer.mProcesses, $iProcess)
	If $mProcess.iSocket<>Default Then
		__IPC__ServerClientDisconnect($mProcess.iSocket, $bError)
	Else
		$__IPC__Data["mServer"]["iOpenProcesses"] -= 1
	EndIf
	__IPC_Log($__IPC_LOG_INFO, "Process removed: "&$mProcess.hProcess)
	; todo if $bError Then ; todo callback for undesired error
	; call $mServer.mProcesses[$iProcess]["sCallback"]
	If UBound(MapKeys($__IPC__Data.mServer.mProcesses))=0 Then __IPC__ServerStop()
EndFunc

Func __IPC__ProcessIdToHandle($iId)
	Return $iId+1
EndFunc

Func __IPC__ProcessHandleToId($hProcess)
	If Not IsInt($hProcess) Or $hProcess-1<0 Or Not MapExists($__IPC__Data.mServer.mProcesses, $hProcess-1) Then Return SetError(1, 1, 0)
	Return $hProcess-1
EndFunc
