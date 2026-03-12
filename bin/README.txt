; SAPI5 TTS helper — compiled with AutoHotkey or similar on Windows.
; This VBScript-based implementation is run via Wine's built-in cscript.
; The PHP tts.php wrapper calls:
;   wine cscript.exe tts.vbs --voice="<name>" --text="<text>" --output="<path>"
;
; NOTE: tts.vbs is the actual runtime script; this file documents the interface.
; The Dockerfile copies tts.vbs into the Wine prefix so cscript can find it.
