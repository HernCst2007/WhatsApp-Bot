#!/bin/bash
# Gerenciador do WhatsApp Bot

get_ip() {
  node -e "const os=require('os');for(const n of Object.keys(os.networkInterfaces())){for(const i of os.networkInterfaces()[n])if(i.family==='IPv4'&&!i.internal)console.log(i.address)}" 2>/dev/null | head -1
}

case "$1" in
  start)
    pkill -f "node server" 2>/dev/null
    sleep 1
    cd ~/whatsapp-bot/server && setsid node server.js < /dev/null > /dev/null 2>&1 &
    sleep 2
    IP=$(get_ip)
    echo "✅ Bot iniciado! Acesse: http://${IP}:3000"
    ;;
  stop)
    pkill -f "node server"
    echo "✅ Bot parado!"
    ;;
  restart)
    pkill -f "node server"
    sleep 1
    cd ~/whatsapp-bot/server && setsid node server.js < /dev/null > /dev/null 2>&1 &
    echo "✅ Bot reiniciado!"
    ;;
  status)
    if pgrep -f "node server" > /dev/null; then
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
    echo "WhatsApp Bot - Gerenciador"
    echo ""
    echo "Uso: bash ~/bot-start.sh [comando]"
    echo ""
    echo "Comandos:"
    echo "  start     Iniciar bot"
    echo "  stop      Parar bot"
    echo "  restart   Reiniciar bot"
    echo "  status    Ver status"
    echo "  ip        Mostrar IP"
    echo "  hide-notif Ocultar notificações"
    ;;
esac
