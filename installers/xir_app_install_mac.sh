#!/bin/bash

# Установка AutoHotkey
echo "Установка AutoHotkey..."
curl -O https://www.autohotkey.com/download/ahk-install.exe
chmod +x ahk-install.exe
./ahk-install.exe /S

# Создание скрипта AutoHotkey
echo "Создание скрипта AutoHotkey..."
cat <<EOF > ~/CtrlT.ahk
^t::
Run, "open -a /Applications/YourApplication.app"
return
EOF

# Запуск скрипта AutoHotkey
echo "Запуск скрипта AutoHotkey..."
open -a AutoHotkey ~/CtrlT.ahk

echo "Установка завершена."
