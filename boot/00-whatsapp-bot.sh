#!/data/data/com.termux/usr/bin/bash
# Auto-start WhatsApp Bot ao ligar o celular

# Configuracao: defina como "true" para iniciar ngrok automaticamente
START_NGROK=false

sleep 15

# Matar processos antigos
pkill -f "node server.js" 2>/dev/null
pkill -f "ngrok" 2>/dev/null
sleep 1

# Verificar dependencias
cd /sdcard/WhatsApp-Bot/server
if [ ! -d "node_modules" ]; then
  npm install
fi

# Iniciar bot
setsid node server.js < /dev/null > /dev/null 2>&1 &

# Iniciar ngrok se configurado
if [ "$START_NGROK" = true ]; then
  NGROK_BIN=/sdcard/WhatsApp-Bot/ngrok-tool/ngrok
  if [ -x "$NGROK_BIN" ]; then
    "$NGROK_BIN" http 3000 &>/dev/null &
    sleep 3
    NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$NGROK_URL" ]; then
      echo "[$(date)] Ngrok: ${NGROK_URL}" >> ~/bot.log
    fi
  fi
fi

# Log
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "[$(date)] Bot iniciado em http://${IP}:3000" >> ~/bot.log
