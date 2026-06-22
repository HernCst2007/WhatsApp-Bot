#!/data/data/com.termux/files/usr/bin/bash
# Auto-start WhatsApp Bot ao ligar o celular

# Esperar rede conectar
sleep 15

# Iniciar bot
cd ~/whatsapp-bot/server
setsid node server.js < /dev/null > /dev/null 2>&1 &

# Log
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "[$(date)] Bot iniciado em http://${IP}:3000" >> ~/bot.log
