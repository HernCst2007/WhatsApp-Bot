#!/bin/bash
# Setup completo do WhatsApp Bot (Termux/Linux)
# Uso: bash setup.sh

set -e

SCRIPT_DIR="$(dirname "$0")"
NODE_MIN_VERSION=18

echo "================================"
echo "  WhatsApp Bot - Setup"
echo "================================"
echo ""

# --- Funcoes ---
check_node() {
  if command -v node &> /dev/null; then
    NODE_CURRENT=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_CURRENT" -ge "$NODE_MIN_VERSION" ]; then
      echo "Node.js v$(node -v | sed 's/v//') [OK]"
      return 0
    fi
  fi
  return 1
}

install_node_termux() {
  echo "Instalando Node.js via pkg..."
  pkg update -y
  pkg install -y nodejs npm
}

install_node_linux() {
  echo "Instalando Node.js via repositorios..."
  if command -v apt &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
  elif command -v dnf &> /dev/null; then
    dnf module install nodejs:20/common -y
  elif command -v pacman &> /dev/null; then
    pacman -S --noconfirm nodejs npm
  else
    echo "[ERRO] Gerenciador de pacotes nao suportado"
    echo "       Instale Node.js manualmente: https://nodejs.org/"
    exit 1
  fi
}

# --- Verificar Node.js ---
echo "[1/3] Verificando Node.js..."
if check_node; then
  echo ""
else
  echo "Node.js nao encontrado ou versao antiga (min: v${NODE_MIN_VERSION})"
  echo ""

  # Detectar ambiente
  if [ -d "/data/data/com.termux" ] || [ -f "/data/data/com.termux/files/usr/bin/bash" ]; then
    echo "Ambiente detectado: Termux (Android)"
    install_node_termux
  else
    echo "Ambiente detectado: Linux"
    install_node_linux
  fi

  # Verificar instalacao
  if check_node; then
    echo "Node.js instalado com sucesso!"
  else
    echo "[ERRO] Falha ao instalar Node.js"
    exit 1
  fi
fi

# --- Instalar dependencias do projeto ---
echo ""
echo "[2/3] Instalando dependencias do projeto..."
cd "$SCRIPT_DIR/server"
if [ ! -d "node_modules" ]; then
  npm install --no-bin-links
  echo "Dependencias instaladas!"
else
  echo "Dependencias ja instaladas [OK]"
fi

# --- Verificar cloudflared ---
echo ""
echo "[3/3] Verificando tunnel..."
if command -v cloudflared &> /dev/null; then
  echo "cloudflared [OK]"
else
  echo "Instalando cloudflared..."
  pkg install -y cloudflared
  echo "cloudflared instalado!"
fi

# --- Resumo ---
echo ""
echo "================================"
echo "  Setup concluido!"
echo "================================"
echo ""
echo "Iniciar o bot:"
echo "  bash start.sh              # Local"
echo "  bash start.sh --tunnel     # Local + Externo"
echo ""
echo "Gerenciador:"
echo "  bash boot/bot-start.sh start"
echo "  bash boot/bot-start.sh start-tunnel"
echo ""
