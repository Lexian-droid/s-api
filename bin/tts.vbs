' tts.vbs — SAPI5 TTS script executed via Wine + cscript.exe
'
' Usage (called by the PHP wrapper through Wine):
'   wine cscript.exe //NoLogo C:\tts\tts.vbs /voice:"Microsoft David" /text:"Hello" /output:"C:\tts\out.wav"
'
' Arguments:
'   /voice:<name>    SAPI5 voice name as registered in the Wine registry
'   /text:<string>   Text to synthesise
'   /output:<path>   Windows-style path for the WAV output file

Option Explicit

Dim voice, text, output
Dim i, arg

' Parse named arguments (//x style not supported in all Wine builds; use positional).
For i = 0 To WScript.Arguments.Count - 1
    arg = WScript.Arguments(i)
    If Left(LCase(arg), 7) = "/voice:" Then
        voice = Mid(arg, 8)
    ElseIf Left(LCase(arg), 6) = "/text:" Then
        text = Mid(arg, 7)
    ElseIf Left(LCase(arg), 8) = "/output:" Then
        output = Mid(arg, 9)
    End If
Next

If voice = "" Or text = "" Or output = "" Then
    WScript.Echo "Usage: cscript tts.vbs /voice:<name> /text:<text> /output:<path>"
    WScript.Quit 1
End If

' Create SAPI SpVoice object.
Dim sapi
Set sapi = CreateObject("SAPI.SpVoice")

' Select the requested voice.
Dim voices, v, matched
Set voices = sapi.GetVoices()
matched = False
For Each v In voices
    If InStr(1, v.GetDescription(), voice, vbTextCompare) > 0 Then
        Set sapi.Voice = v
        matched = True
        Exit For
    End If
Next

If Not matched Then
    WScript.Echo "Voice not found: " & voice
    WScript.Quit 2
End If

' Create a file stream and write audio to it.
Dim stream
Set stream = CreateObject("SAPI.SpFileStream")
stream.Open output, 3, False  ' SSFMCreateForWrite = 3

Set sapi.AudioOutputStream = stream
sapi.Speak text, 0

stream.Close

WScript.Echo "OK: " & output
WScript.Quit 0
