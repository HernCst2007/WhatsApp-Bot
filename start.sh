#!/bin/bash
# WhatsApp Bot - Script de início rápido
# Uso: bash start.sh

echo "============================="
echo "  WhatsApp Bot - Iniciando"
echo "============================"
echo ""

cd "$(dirname "$0")/server"

# Verificar Node.js
if ! command -v node &> /dev/null; then
  echo "❌ Node.js não encontrado. Instalando..."
  pkg install -y nodejs
fi

# Verificar dependências
if [ ! -d "node_modules" ]; then
  echo "📦 Instalando dependências..."
  npm install
fi

# Verificar ngrok
NGROK_AVAILABLE=false
if command -v ngrok &> /dev/null; then
  echo "✅ Ngrok disponível"
  NGROK_AVAILABLE=true
else
  echo "⚠️  Ngrok não instalado"
  echo "   Instalando ngrok automaticamente..."
  if [ -d "$(dirname "$0")/ngrok-tool" ]; then
    cd "$(dirname "$0")/ngrok-tool"
    bash install.sh
    cd "$(dirname "$0")/server"
    if command -v ngrok &> /dev/null; then
      echo "✅ Ngrok instalado com sucesso!"
      NGROK_AVAILABLE=true
    else
      echo "❌ Falha ao instalar ngrok"
    fi
  else
    echo "   Pasta ngrok-tool não encontrada no projeto"
  fi
fi

echo ""
echo "🚀 Iniciando servidor..."
echo ""

# IP local
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "📱 Acesse no celular:"
echo "   http://${IP}:3000"
echo ""
echo "🌐 Ou no navegador:"
echo "   http://localhost:3000"
echo ""

# Iniciar ngrok em background
if [ "$NGROK_AVAILABLE" = true ]; then
  echo "🌐 Iniciando túnel ngrok..."
  ngrok http 3000 &>/dev/null &
  NGROK_PID=$!
  sleep 3
  
  # Tentar obter URL do ngrok via API local
  NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"[^"]*"' | head -1 | cut -d'"' -f4)
  
  if [ -n "$NGROK_URL" ]; then
    echo "🌍 Ngrok tunnel ativo:"
    echo "   ${NGROK_URL}"
    echo ""
  else
    echo "🌍 Ngrok iniciado (verifique http://127.0.0.1:4040 para a URL)"
    echo ""
  fi
fi

node server.js

# Cleanup ngrok ao sair
if [ -n "$NGROK_PID" ]; then
  kill $NGROK_PID 2>/dev/null
fi
