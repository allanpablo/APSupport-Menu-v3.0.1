@echo off
REM Executa o menu de suporte com bypass para policies e sem perfil
setlocal
set SCRIPT=%~dp0Menu-Suporte-AllanPablo.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
endlocal
