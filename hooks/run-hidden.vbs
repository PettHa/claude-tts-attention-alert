' Hidden-launch shim for Windows hooks.
' Usage: wscript.exe run-hidden.vbs <exe> [arg1] [arg2] ...
' Runs the given command with no console window and returns immediately.
Set sh = CreateObject("WScript.Shell")
cmd = ""
For i = 0 To WScript.Arguments.Count - 1
  a = WScript.Arguments(i)
  ' Quote every arg; double internal quotes per cmd.exe parsing rules.
  cmd = cmd & " """ & Replace(a, """", """""") & """"
Next
sh.Run Trim(cmd), 0, False
