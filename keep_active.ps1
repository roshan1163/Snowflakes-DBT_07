$wshell = New-Object -ComObject wscript.shell
$file = "keep_alive.txt"
New-Item -ItemType File -Force -Path $file | Out-Null
Set-Content -Path $file -Value "Started logging to keep Teams active..."
notepad.exe $file
Start-Sleep -Seconds 2
$wshell.AppActivate("keep_alive.txt - Notepad") | Out-Null
Start-Sleep -Seconds 1
while ($true) {
    $wshell.SendKeys('hello world{ENTER}')
    Start-Sleep -Seconds 30
}
