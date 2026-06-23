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

:: Verificar ngrok local
set NGROK_BIN=%~dp0ngrok-tool\windows\ngrok.exe
set NGROK_AVAILABLE=0
if exist "%NGROK_BIN%" set NGROK_AVAILABLE=1

:: Verificar flag --ngrok
set USE_NGROK=0
if "%1"=="--ngrok" set USE_NGROK=1

echo Iniciando servidor...
echo.
echo   http://localhost:3000

:: Iniciar ngrok se solicitado
if "%USE_NGROK%"=="1" (
    if "%NGROK_AVAILABLE%"=="1" (
        start "Ngrok" /min "%NGROK_BIN%" http 3000
        timeout /t 3 /nobreak >nul
        echo   Ngrok: http://localhost:4040 (painel de inspecao)
    ) else (
        echo.
        echo [AVISO] --ngrok usado mas binario ngrok nao encontrado em ngrok-tool\windows\
    )
)
echo.

node server.js
popd
pause
