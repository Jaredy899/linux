#!/bin/sh
# Detect OS and run appropriate installer

case "$(uname -s)" in
  Linux*)   sh ./bootstrap/install-linux.sh ;;
  Darwin*)  sh ./bootstrap/install-macos.sh ;;
  CYGWIN*|MINGW*|MSYS*) pwsh ./bootstrap/install-windows.ps1 ;;
  *) echo "❌ Unsupported OS." ;;
esac