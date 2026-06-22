#!/data/data/com.termux/files/usr/bin/bash
# Auto-start WhatsApp Bot ao ligar o celular

sleep 15

# Matar processos antigos
pkill -f "node server.js" 2>/dev/null
sleep 1

# Verificar dependencias
cd ~/WhatsApp-Bot/server
if [ ! -d "node_modules" ]; then
  npm install
fi

# Iniciar bot
setsid node server.js < /dev/null > /dev/null 2>&1 &

# Log
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "[$(date)] Bot iniciado em http://${IP}:3000" >> ~/bot.log
