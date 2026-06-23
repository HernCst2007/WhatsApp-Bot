@echo off
chcp 65001 >nul 2>&1
title WhatsApp Bot

pushd "%~dp0"
cd /d "%~dp0server"

echo =============================
echo   WhatsApp Bot - Iniciando
echo =============================
echo.

:: Verificar Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERRO] Node.js nao encontrado!
    echo Baixe em: https://nodejs.org/
    pause
    exit /b 1
)

:: Verificar dependencias
if not exist "node_modules" (
    echo Instalando dependencias...
    call npm install
    echo.
)

:: Verificar flag --tunnel
set USE_TUNNEL=0
if "%1"=="--tunnel" set USE_TUNNEL=1
if "%1"=="--ngrok" set USE_TUNNEL=1

:: Verificar localtunnel
if "%USE_TUNNEL%"=="1" (
    if not exist "node_modules\localtunnel" (
        echo Instalando localtunnel...
        call npm install localtunnel --save
    )
)

echo Iniciando servidor...
echo.
echo   http://localhost:3000

:: Iniciar localtunnel se solicitado
if "%USE_TUNNEL%"=="1" (
    start "Tunnel" /min node -e "const lt=require('localtunnel');lt({port:3000}).then(t=>console.log('Tunnel: '+t.url))"
    timeout /t 3 /nobreak >nul
    echo   Tunnel: aguarde URL acima...
)
echo.

node server.js
popd
pause
