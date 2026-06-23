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
  NGROK_SRC=/sdcard/WhatsApp-Bot/ngrok-tool/ngrok
  if [ -f "$NGROK_SRC" ]; then
    NGROK_BIN="$HOME/.local/bin/ngrok"
    mkdir -p "$HOME/.local/bin"
    cp "$NGROK_SRC" "$NGROK_BIN"
    chmod +x "$NGROK_BIN"
    RESOLV_CONF=/sdcard/WhatsApp-Bot/ngrok-tool/etc/resolv.conf
    PROOT_BIN=$(command -v proot 2>/dev/null)
    if [ -n "$PROOT_BIN" ] && [ -f "$RESOLV_CONF" ]; then
      proot -b "$RESOLV_CONF:/etc/resolv.conf" "$NGROK_BIN" http 3000 &>/dev/null &
    else
      "$NGROK_BIN" http 3000 &>/dev/null &
    fi
    sleep 4
    NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$NGROK_URL" ]; then
      echo "[$(date)] Ngrok: ${NGROK_URL}" >> ~/bot.log
    fi
  fi
fi

# Log
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "[$(date)] Bot iniciado em http://${IP}:3000" >> ~/bot.log
