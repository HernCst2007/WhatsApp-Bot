#!/data/data/com.termux/files/usr/bin/bash
# Auto-start WhatsApp Bot ao ligar o celular

# Esperar rede conectar
sleep 15

# Matar processos antigos
pkill -f "node server.js" 2>/dev/null
sleep 1

# Iniciar bot
cd ~/WhatsApp-Bot/server
setsid node server.js < /dev/null > /dev/null 2>&1 &

# Log
IP=$(node -e "const os=require('os');for(const n of Object.keys(os.networkInterfaces())){for(const i of os.networkInterfaces()[n])if(i.family==='IPv4'&&!i.internal)console.log(i.address)}" 2>/dev/null | head -1)
echo "[$(date)] Bot iniciado em http://${IP}:3000" >> ~/bot.log
