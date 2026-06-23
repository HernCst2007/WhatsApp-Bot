#!/data/data/com.termux/usr/bin/bash
# Auto-start WhatsApp Bot ao ligar o celular

# Configuracao: defina como "true" para iniciar tunnel externo
START_TUNNEL=false

sleep 15

# Matar processos antigos
pkill -f "node server.js" 2>/dev/null
pkill -f "cloudflared" 2>/dev/null
sleep 1

# Verificar dependencias
cd /sdcard/WhatsApp-Bot/server
if [ ! -d "node_modules" ]; then
  npm install --no-bin-links
fi

# Iniciar bot
setsid node server.js < /dev/null > /dev/null 2>&1 &

# Iniciar tunnel se configurado
if [ "$START_TUNNEL" = true ]; then
  if ! command -v cloudflared &> /dev/null; then
    pkg install -y cloudflared
  fi
  cloudflared tunnel --url http://localhost:3000 &
  sleep 5
fi

# Log
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "[$(date)] Bot iniciado em http://${IP}:3000" >> ~/bot.log
