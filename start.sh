#!/bin/bash
# WhatsApp Bot - Inicio rapido (Termux)
# Uso: bash start.sh [--ngrok]

SCRIPT_DIR="$(dirname "$0")"
NGROK_BIN="$SCRIPT_DIR/ngrok-tool/ngrok"
USE_NGROK=false

for arg in "$@"; do
  case "$arg" in
    --ngrok) USE_NGROK=true ;;
  esac
done

echo "============================="
echo "  WhatsApp Bot - Iniciando"
echo "============================"
echo ""

cd "$SCRIPT_DIR/server"

# Verificar Node.js
if ! command -v node &> /dev/null; then
  echo "Node.js nao encontrado. Instalando..."
  pkg install -y nodejs
fi

# Verificar dependencias
if [ ! -d "node_modules" ]; then
  echo "Instalando dependencias..."
  npm install
fi

# Verificar ngrok local
if [ -x "$NGROK_BIN" ]; then
  NGROK_AVAILABLE=true
else
  NGROK_AVAILABLE=false
fi

echo ""
echo "Iniciando servidor..."
echo ""

IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "Local:  http://${IP}:3000"

# Iniciar ngrok se solicitado
if [ "$USE_NGROK" = true ]; then
  if [ "$NGROK_AVAILABLE" = true ]; then
    "$NGROK_BIN" http 3000 &>/dev/null &
    NGROK_PID=$!
    sleep 3
    NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$NGROK_URL" ]; then
      echo "Ngrok:  ${NGROK_URL}"
    else
      echo "[AVISO] Ngrok iniciado mas URL nao disponivel. Verifique http://127.0.0.1:4040"
    fi
  else
    echo "[AVISO] --ngrok usado mas binario ngrok nao encontrado em ngrok-tool/"
  fi
fi
echo ""

# Capturar Ctrl+C para limpar ngrok
cleanup() {
  if [ -n "$NGROK_PID" ]; then
    kill $NGROK_PID 2>/dev/null
  fi
  exit 0
}
trap cleanup INT TERM

node server.js

cleanup
