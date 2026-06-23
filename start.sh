#!/bin/bash
# WhatsApp Bot - Inicio rapido (Termux)
# Uso: bash start.sh [--tunnel]

SCRIPT_DIR="$(dirname "$0")"
USE_TUNNEL=false

for arg in "$@"; do
  case "$arg" in
    --tunnel|--ngrok) USE_TUNNEL=true ;;
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

# Verificar localtunnel
if [ "$USE_TUNNEL" = true ]; then
  if [ ! -d "node_modules/localtunnel" ]; then
    echo "Instalando localtunnel (primeira vez)..."
    npm install localtunnel --save --no-bin-links
    echo "localtunnel instalado!"
  fi
fi

echo ""
echo "Iniciando servidor..."
echo ""

IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "Local:  http://${IP}:3000"

# Iniciar localtunnel se solicitado
if [ "$USE_TUNNEL" = true ]; then
  node -e "
    const lt = require('localtunnel');
    (async () => {
      const tunnel = await lt({ port: 3000 });
      console.log('Tunnel:  ' + tunnel.url);
      tunnel.on('close', () => process.exit());
    })();
  " &
  TUNNEL_PID=$!
  sleep 3
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
