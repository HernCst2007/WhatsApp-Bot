@echo off
chcp 65001 >nul 2>&1
title WhatsApp Bot - Setup

pushd "%~dp0"

echo ================================
echo   WhatsApp Bot - Setup
echo ================================
echo.

:: --- Verificar Node.js ---
echo [1/3] Verificando Node.js...
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo Node.js NAO encontrado!
    echo.
    echo Baixe e instale: https://nodejs.org/
    echo Escolha a versao LTS (v18+)
    echo.
    echo Apos instalar, execute este script novamente.
    pause
    exit /b 1
)
echo Node.js encontrado [OK]

:: --- Instalar dependencias ---
echo.
echo [2/3] Instalando dependencias do projeto...
cd /d "%~dp0server"
if not exist "node_modules" (
    call npm install
    echo Dependencias instaladas!
) else (
    echo Dependencias ja instaladas [OK]
)

:: --- Verificar localtunnel ---
echo.
echo [3/3] Verificando tunnel...
if not exist "node_modules\localtunnel" (
    echo Instalando localtunnel...
    call npm install localtunnel --save
    echo localtunnel instalado!
) else (
    echo localtunnel [OK]
)

:: --- Resumo ---
echo.
echo ================================
echo   Setup concluido!
echo ================================
echo.
echo Iniciar o bot:
echo   start.bat                 # Local
echo   start.bat --tunnel        # Local + Externo
echo.
echo Gerenciador:
echo   bot.bat start
echo   bot.bat start-tunnel
echo.
popd
pause
