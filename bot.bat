@echo off
chcp 65001 >nul 2>&1
title WhatsApp Bot - Gerenciador

pushd "%~dp0"

set NGROK_BIN=%~dp0ngrok-tool\windows\ngrok.exe

if "%1"=="start" goto do_start
if "%1"=="start-ngrok" goto do_start_ngrok
if "%1"=="stop" goto do_stop
if "%1"=="restart" goto do_restart
if "%1"=="status" goto do_status
if "%1"=="install" goto do_install

:menu
echo =============================
echo   WhatsApp Bot - Gerenciador
echo =============================
echo.
echo Uso: bot.bat [comando]
echo.
echo Comandos:
echo   start         Iniciar bot
echo   start-ngrok   Iniciar bot + ngrok
echo   stop          Parar bot
echo   restart       Reiniciar bot
echo   status        Ver status
echo   install       Instalar dependencias
echo.
popd
goto :eof

:do_start
tasklist /FI "IMAGENAME eq node.exe" 2>nul | find /I "node.exe" >nul
if %errorlevel% equ 0 (
    echo Bot ja esta rodando!
    popd
    goto :eof
)
cd /d "%~dp0server"
start "WhatsApp Bot" /min node server.js
timeout /t 2 /nobreak >nul
echo Bot iniciado!
echo http://localhost:3000
popd
goto :eof

:do_start_ngrok
tasklist /FI "IMAGENAME eq node.exe" 2>nul | find /I "node.exe" >nul
if %errorlevel% equ 0 (
    echo Bot ja esta rodando!
    popd
    goto :eof
)
cd /d "%~dp0server"
start "WhatsApp Bot" /min node server.js
timeout /t 2 /nobreak >nul
echo Bot iniciado!
echo http://localhost:3000
if exist "%NGROK_BIN%" (
    start "Ngrok" /min "%NGROK_BIN%" http 3000
    timeout /t 3 /nobreak >nul
    echo Ngrok: http://localhost:4040 (painel de inspecao)
) else (
    echo [AVISO] Binario ngrok nao encontrado em ngrok-tool\windows\
)
popd
goto :eof

:do_stop
taskkill /FI "WINDOWTITLE eq WhatsApp Bot" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq WhatsApp Bot*" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq Ngrok" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq Ngrok*" /F >nul 2>&1
echo Bot parado!
popd
goto :eof

:do_restart
call :do_stop
timeout /t 2 /nobreak >nul
call :do_start
goto :eof

:do_status
tasklist /FI "IMAGENAME eq node.exe" 2>nul | find /I "node.exe" >nul
if %errorlevel% equ 0 (
    echo Bot rodando!
    echo http://localhost:3000
    tasklist /FI "IMAGENAME eq ngrok.exe" 2>nul | find /I "ngrok.exe" >nul
    if %errorlevel% equ 0 (
        echo Ngrok: rodando
    )
) else (
    echo Bot parado
)
popd
goto :eof

:do_install
cd /d "%~dp0server"
echo Instalando dependencias...
call npm install
echo Concluido!
popd
goto :eof
