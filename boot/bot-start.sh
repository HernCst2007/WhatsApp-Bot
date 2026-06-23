#!/bin/bash
# Gerenciador do WhatsApp Bot (Termux)

PROJDIR=/sdcard/WhatsApp-Bot

get_ip() {
  hostname -I 2>/dev/null | awk '{print $1}'
}

kill_all() {
  pkill -f "node server.js" 2>/dev/null
  pkill -f "localtunnel" 2>/dev/null
  pkill -f "lt.js" 2>/dev/null
  sleep 1
}

start_tunnel() {
  cd "$PROJDIR/server"
  if [ ! -d "node_modules/localtunnel" ]; then
    echo "Instalando localtunnel..."
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
  TUNNEL_PID=$!
  sleep 3
}

case "$1" in
  start)
    kill_all
    cd "$PROJDIR/server"
    if [ ! -d "node_modules" ]; then
      echo "Instalando dependencias..."
      npm install --no-bin-links
    fi
    setsid node server.js < /dev/null > /dev/null 2>&1 &
    sleep 2
    IP=$(get_ip)
    echo "Bot iniciado!"
    echo "http://${IP}:3000"
    ;;
  start-tunnel)
    kill_all
    cd "$PROJDIR/server"
    if [ ! -d "node_modules" ]; then
      echo "Instalando dependencias..."
      npm install --no-bin-links
    fi
    setsid node server.js < /dev/null > /dev/null 2>&1 &
    sleep 2
    IP=$(get_ip)
    echo "Bot iniciado!"
    echo "http://${IP}:3000"
    start_tunnel
    ;;
  stop)
    kill_all
    echo "Bot parado!"
    ;;
  restart)
    kill_all
    cd "$PROJDIR/server" && setsid node server.js < /dev/null > /dev/null 2>&1 &
    sleep 2
    echo "Bot reiniciado!"
    ;;
  status)
    if pgrep -f "node server.js" > /dev/null; then
      echo "Bot rodando!"
      echo "http://$(get_ip):3000"
      if pgrep -f "lt.js" > /dev/null; then
        echo "Tunnel: rodando"
      fi
    else
      echo "Bot parado"
    fi
    ;;
  ip)
    echo "IP: $(get_ip)"
    ;;
  hide-notif)
    termux-notification-dismiss --id all 2>/dev/null
    echo "Notificacoes ocultas"
    ;;
  *)
    echo "============================="
    echo "  WhatsApp Bot - Gerenciador"
    echo "============================="
    echo ""
    echo "Uso: bash /sdcard/WhatsApp-Bot/boot/bot-start.sh [comando]"
    echo ""
    echo "Comandos:"
    echo "  start          Iniciar bot"
    echo "  start-tunnel   Iniciar bot + tunnel externo"
    echo "  stop           Parar bot"
    echo "  restart        Reiniciar bot"
    echo "  status         Ver status"
    echo "  ip             Mostrar IP"
    echo "  hide-notif     Ocultar notificacoes"
    ;;
esac
