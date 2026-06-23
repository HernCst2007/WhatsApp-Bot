@echo off
chcp 65001 >nul 2>&1
title WhatsApp Bot - Gerenciador

pushd "%~dp0"

if "%1"=="start" goto do_start
if "%1"=="start-tunnel" goto do_start_tunnel
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
echo   start          Iniciar bot
echo   start-tunnel   Iniciar bot + tunnel externo
echo   stop           Parar bot
echo   restart        Reiniciar bot
echo   status         Ver status
echo   install        Instalar dependencias
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

:do_start_tunnel
tasklist /FI "IMAGENAME eq node.exe" 2>nul | find /I "node.exe" >nul
if %errorlevel% equ 0 (
    echo Bot ja esta rodando!
    popd
    goto :eof
)
cd /d "%~dp0server"
if not exist "node_modules\localtunnel" (
    echo Instalando localtunnel...
    call npm install localtunnel --save
)
start "WhatsApp Bot" /min node server.js
timeout /t 2 /nobreak >nul
echo Bot iniciado!
echo http://localhost:3000
start "Tunnel" /min node -e "const lt=require('localtunnel');lt({port:3000}).then(t=>{console.log('Tunnel: '+t.url);t.on('close',()=>process.exit())})"
timeout /t 3 /nobreak >nul
popd
goto :eof

:do_stop
taskkill /FI "WINDOWTITLE eq WhatsApp Bot" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq WhatsApp Bot*" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq Tunnel" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq Tunnel*" /F >nul 2>&1
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
