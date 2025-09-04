@echo off
setlocal
set "ROOT=%~dp0"
set "MAIN=%ROOT%Menu-Suporte-AllanPablo.ps1"

REM Tenta elevar se nao for admin
whoami /groups | find "S-1-5-32-544" >nul
if errorlevel 1 (
  powershell -NoP -C "Start-Process -Verb RunAs -FilePath '%COMSPEC%' -ArgumentList '/c \"\"%~f0\"\"'"
  exit /b
)

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%MAIN%"
endlocal
