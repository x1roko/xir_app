#!/bin/bash

# Обновление и установка xdotool
sudo apt update
sudo apt install -y xdotool

# Создание скрипта для xdotool
cat <<EOF > ~/.config/autostart/xdotool.sh
#!/bin/bash
xdotool key Ctrl+t
EOF

# Сделать скрипт исполняемым
chmod +x ~/.config/autostart/xdotool.sh

# Добавить скрипт в автозагрузку
cp ~/.config/autostart/xdotool.sh /etc/xdg/autostart/

echo "Установка завершена. Перезагрузите компьютер для применения настроек."
