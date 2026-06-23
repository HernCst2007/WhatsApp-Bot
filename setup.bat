@echo off
chcp 65001 >nul 2>&1
title WhatsApp Bot - Setup

pushd "%~dp0"

echo ================================
echo   WhatsApp Bot - Setup
echo ================================
echo.

:: --- Verificar Node.js ---
echo [1/4] Verificando Node.js...
where node >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=1 delims=." %%v in ('node -v') do set NODE_MAJOR=%%v
    set NODE_MAJOR=%NODE_MAJOR:v=%
    echo Node.js encontrado [OK]
) else (
    echo Node.js NAO encontrado!
    echo.
    echo Baixe e instale: https://nodejs.org/
    echo Escolha a versao LTS (v18+)
    echo.
    echo Apos instalar, execute este script novamente.
    pause
    exit /b 1
)

:: --- Instalar dependencias ---
echo.
echo [2/4] Instalando dependencias do projeto...
cd /d "%~dp0server"
if not exist "node_modules" (
    call npm install
    echo Dependencias instaladas!
) else (
    echo Dependencias ja instaladas [OK]
)

:: --- Verificar ngrok ---
echo.
echo [3/4] Verificando ngrok...
set NGROK_BIN=%~dp0ngrok-tool\windows\ngrok.exe
if exist "%NGROK_BIN%" (
    echo ngrok encontrado [OK]
) else (
    echo ngrok NAO encontrado. Baixando...
    mkdir "%~dp0ngrok-tool\windows" 2>nul
    curl -sL "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip" -o "%~dp0ngrok-tool\ngrok.zip"
    cd /d "%~dp0ngrok-tool"
    powershell -command "Expand-Archive -Path 'ngrok.zip' -DestinationPath 'windows' -Force"
    del ngrok.zip
    echo ngrok baixado com sucesso!
)

:: --- Resumo ---
echo.
echo ================================
echo   Setup concluido!
echo ================================
echo.
echo Iniciar o bot:
echo   start.bat              # Local
echo   start.bat --ngrok      # Local + Externo
echo.
echo Gerenciador:
echo   bot.bat start
echo   bot.bat start-ngrok
echo.
popd
pause
