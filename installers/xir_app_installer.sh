#!/bin/bash

# Определение операционной системы
OS="$(uname)"

if [ "$OS" == "Linux" ]; then
    echo "Detected Linux"
    bash install_linux.sh
elif [ "$OS" == "Darwin" ]; then
    echo "Detected macOS"
    bash install_macos.sh
elif [ "$OS" == "MINGW64_NT-10.0" ]; then
    echo "Detected Windows"
    cmd /c install.bat
else
    echo "Unsupported OS: $OS"
    exit 1
fi
