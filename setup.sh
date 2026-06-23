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
echo "[1/4] Verificando Node.js..."
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
echo "[2/4] Instalando dependencias do projeto..."
cd "$SCRIPT_DIR/server"
if [ ! -d "node_modules" ]; then
  npm install
  echo "Dependencias instaladas!"
else
  echo "Dependencias ja instaladas [OK]"
fi

# --- Verificar ngrok ---
echo ""
echo "[3/4] Verificando ngrok..."
NGROK_SRC="$SCRIPT_DIR/ngrok-tool/ngrok"
NGROK_BIN="$HOME/.local/bin/ngrok"

# Copiar binario para local com permissao (SD card usa FAT)
if [ -f "$NGROK_SRC" ]; then
  mkdir -p "$HOME/.local/bin"
  cp "$NGROK_SRC" "$NGROK_BIN"
  chmod +x "$NGROK_BIN"
  echo "ngrok $($NGROK_BIN version) [OK]"
else
  echo "ngrok nao encontrado. Baixando..."
  mkdir -p "$SCRIPT_DIR/ngrok-tool"

  ARCH=$(uname -m)
  case "$ARCH" in
    aarch64|arm64) NGROK_ARCH="arm64" ;;
    armv7l|armhf)  NGROK_ARCH="arm" ;;
    x86_64|amd64)  NGROK_ARCH="amd64" ;;
    *) echo "[ERRO] Arquitetura $ARCH nao suportada"; exit 1 ;;
  esac

  curl -sL "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-${NGROK_ARCH}.zip" -o "$SCRIPT_DIR/ngrok-tool/ngrok.zip"
  unzip -qo "$SCRIPT_DIR/ngrok-tool/ngrok.zip" -d "$SCRIPT_DIR/ngrok-tool/"
  rm -f "$SCRIPT_DIR/ngrok-tool/ngrok.zip"

  # Copiar para local com permissao
  mkdir -p "$HOME/.local/bin"
  cp "$NGROK_SRC" "$NGROK_BIN"
  chmod +x "$NGROK_BIN"
  echo "ngrok baixado com sucesso!"
fi

# Configurar resolv.conf para proot (Android nao tem /etc/resolv.conf)
echo ""
echo "[4/4] Configuracao..."
mkdir -p "$SCRIPT_DIR/ngrok-tool/etc"
echo "nameserver 8.8.8.8" > "$SCRIPT_DIR/ngrok-tool/etc/resolv.conf"
echo "nameserver 8.8.4.4" >> "$SCRIPT_DIR/ngrok-tool/etc/resolv.conf"

# Verificar proot
if ! command -v proot &> /dev/null; then
  echo "proot nao encontrado. Instalando..."
  pkg install -y proot
fi

if command -v proot &> /dev/null; then
  echo "proot [OK]"
else
  echo "[AVISO] proot nao disponivel - ngrok pode nao funcionar"
fi

# Verificar token ngrok
AUTHTOKEN_FILE="$HOME/.config/ngrok/ngrok.yml"
if [ -f "$AUTHTOKEN_FILE" ] && grep -q "authtoken:" "$AUTHTOKEN_FILE" 2>/dev/null; then
  echo "Token ngrok configurado [OK]"
else
  echo "Token ngrok NAO configurado."
  echo ""
  echo "  Para usar ngrok (acesso externo):"
  echo "  1. Crie conta: https://dashboard.ngrok.com/signup"
  echo "  2. Copie o token: https://dashboard.ngrok.com/get-started/your-authtoken"
  echo "  3. Execute: $NGROK_BIN config add-authtoken SEU_TOKEN"
  echo ""
fi

# --- Resumo ---
echo ""
echo "================================"
echo "  Setup concluido!"
echo "================================"
echo ""
echo "Iniciar o bot:"
echo "  bash start.sh           # Local"
echo "  bash start.sh --ngrok   # Local + Externo"
echo ""
echo "Gerenciador:"
echo "  bash boot/bot-start.sh start"
echo "  bash boot/bot-start.sh start-ngrok"
echo ""
