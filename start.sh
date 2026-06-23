#!/bin/bash
# WhatsApp Bot - Inicio rapido (Termux)
# Uso: bash start.sh [--tunnel]

SCRIPT_DIR="$(dirname "$0")"
USE_TUNNEL=false

for arg in "$@"; do
  case "$arg" in
    --tunnel) USE_TUNNEL=true ;;
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
  npm install --no-bin-links
fi

# Verificar cloudflared
if [ "$USE_TUNNEL" = true ]; then
  if ! command -v cloudflared &> /dev/null; then
    echo "cloudflared nao encontrado. Instalando..."
    pkg install -y cloudflared
  fi
fi

echo ""
echo "Iniciando servidor..."
echo ""

IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "Local:  http://${IP}:3000"

# Iniciar cloudflared se solicitado
if [ "$USE_TUNNEL" = true ]; then
  TUNNEL_LOG=$(mktemp)
  cloudflared tunnel --url http://localhost:3000 > "$TUNNEL_LOG" 2>&1 &
  TUNNEL_PID=$!
  TUNNEL_URL=""
  for i in $(seq 1 15); do
    sleep 1
    TUNNEL_URL=$(grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | head -1)
    if [ -n "$TUNNEL_URL" ]; then break; fi
  done
  rm -f "$TUNNEL_LOG"
  echo ""
  if [ -n "$TUNNEL_URL" ]; then
    echo "============================="
    echo "  Tunnel Externo"
    echo "============================="
    echo ""
    echo "Link: $TUNNEL_URL"
    echo ""
  else
    echo "[AVISO] Tunnel iniciado, mas o link ainda nao apareceu."
    echo "        Aguarde alguns segundos e verifique o terminal."
  fi
fi
echo ""

# Capturar Ctrl+C para limpar tunnel
cleanup() {
  if [ -n "$TUNNEL_PID" ]; then
    kill $TUNNEL_PID 2>/dev/null
  fi
  exit 0
}
trap cleanup INT TERM

node server.js

cleanup
