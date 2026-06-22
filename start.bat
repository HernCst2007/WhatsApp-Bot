@echo off
chcp 65001 >nul 2>&1
title WhatsApp Bot

:: Navegar para a pasta do script
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

echo Iniciando servidor...
echo.
echo   http://localhost:3000
echo.

node server.js
popd
pause
