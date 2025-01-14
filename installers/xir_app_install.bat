@echo off

:: Установка AutoHotkey
echo Установка AutoHotkey...
powershell -Command "Start-Process msiexec.exe -ArgumentList '/i https://www.autohotkey.com/download/ahk-install.exe /quiet' -NoNewWindow -Wait"

:: Создание скрипта AutoHotkey
echo Создание скрипта AutoHotkey...
echo ^t:: > C:\Path\to\CtrlT.ahk
echo Run, "C:\Path\to\your\application.exe" >> C:\Path\to\CtrlT.ahk
echo return >> C:\Path\to\CtrlT.ahk

:: Запуск скрипта AutoHotkey
echo Запуск скрипта AutoHotkey...
start C:\Path\to\CtrlT.ahk

echo Установка завершена.
pause
