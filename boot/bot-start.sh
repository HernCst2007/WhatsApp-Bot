#!/bin/bash
# Gerenciador do WhatsApp Bot

PROJDIR=~/WhatsApp-Bot
get_ip() {
  node -e "const os=require('os');for(const n of Object.keys(os.networkInterfaces())){for(const i of os.networkInterfaces()[n])if(i.family==='IPv4'&&!i.internal)console.log(i.address)}" 2>/dev/null | head -1
}

kill_all() {
  pkill -f "node server.js" 2>/dev/null
  pkill -f "ngrok" 2>/dev/null
  sleep 1
}

case "$1" in
  start)
    kill_all
    cd "$PROJDIR/server" && setsid node server.js < /dev/null > /dev/null 2>&1 &
    sleep 2
    IP=$(get_ip)
    echo "✅ Bot iniciado!"
    echo "📱 http://${IP}:3000"
    ;;
  stop)
    kill_all
    echo "✅ Bot parado!"
    ;;
  restart)
    kill_all
    cd "$PROJDIR/server" && setsid node server.js < /dev/null > /dev/null 2>&1 &
    sleep 2
    echo "✅ Bot reiniciado!"
    ;;
  status)
    if pgrep -f "node server.js" > /dev/null; then
      echo "🟢 Bot rodando!"
      echo "📱 http://$(get_ip):3000"
    else
      echo "🔴 Bot parado"
    fi
    ;;
  ip)
    echo "📱 IP: $(get_ip)"
    ;;
  hide-notif)
    termux-notification-dismiss --id all 2>/dev/null
    echo "✅ Notificações ocultas"
    ;;
  *)
    echo "============================="
    echo "  WhatsApp Bot - Gerenciador"
    echo "============================="
    echo ""
    echo "Uso: bash ~/WhatsApp-Bot/boot/bot-start.sh [comando]"
    echo ""
    echo "Comandos:"
    echo "  start      Iniciar bot"
    echo "  stop       Parar bot"
    echo "  restart    Reiniciar bot"
    echo "  status     Ver status"
    echo "  ip         Mostrar IP"
    echo "  hide-notif Ocultar notificações"
    ;;
esac
