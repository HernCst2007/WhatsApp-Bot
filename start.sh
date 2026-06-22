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
if command -v ngrok &> /dev/null; then
  echo "✅ Ngrok disponível"
else
  echo "⚠️  Ngrok não instalado (opcional)"
  echo "   Para acessar de fora: pkg install ngrok"
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

node server.js
