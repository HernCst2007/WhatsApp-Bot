#!/bin/bash
# WhatsApp Bot - Inicio rapido (Termux)
# Uso: bash start.sh

echo "============================="
echo "  WhatsApp Bot - Iniciando"
echo "============================"
echo ""

cd "$(dirname "$0")/server"

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

# Verificar ngrok
NGROK_AVAILABLE=false
if command -v ngrok &> /dev/null; then
  echo "Ngrok disponivel"
  NGROK_AVAILABLE=true
else
  echo "Ngrok nao instalado"
  if [ -d "$(dirname "$0")/ngrok-tool" ]; then
    cd "$(dirname "$0")/ngrok-tool"
    bash install.sh
    cd "$(dirname "$0")/server"
    if command -v ngrok &> /dev/null; then
      echo "Ngrok instalado com sucesso!"
      NGROK_AVAILABLE=true
    fi
  fi
fi

echo ""
echo "Iniciando servidor..."
echo ""

IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "http://${IP}:3000"
echo ""

if [ "$NGROK_AVAILABLE" = true ]; then
  ngrok http 3000 &>/dev/null &
  NGROK_PID=$!
  sleep 3
  NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"[^"]*"' | head -1 | cut -d'"' -f4)
  if [ -n "$NGROK_URL" ]; then
    echo "Ngrok: ${NGROK_URL}"
    echo ""
  fi
fi

node server.js

if [ -n "$NGROK_PID" ]; then
  kill $NGROK_PID 2>/dev/null
fi
