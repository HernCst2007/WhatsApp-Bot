#!/data/data/com.termux/usr/bin/bash
# Auto-start WhatsApp Bot ao ligar o celular

# Configuracao: defina como "true" para iniciar tunnel externo
START_TUNNEL=false

sleep 15

# Matar processos antigos
pkill -f "node server.js" 2>/dev/null
pkill -f "lt.js" 2>/dev/null
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
  if [ ! -d "node_modules/localtunnel" ]; then
    npm install localtunnel --save --no-bin-links
  fi
  node -e "
    const lt = require('localtunnel');
    (async () => {
      const tunnel = await lt({ port: 3000 });
      console.log('Tunnel: ' + tunnel.url);
      tunnel.on('close', () => process.exit());
    })();
  " &
  sleep 3
fi

# Log
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "[$(date)] Bot iniciado em http://${IP}:3000" >> ~/bot.log
