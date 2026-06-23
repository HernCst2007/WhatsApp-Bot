#!/bin/bash
# Gerenciador do WhatsApp Bot (Termux)

PROJDIR=/sdcard/WhatsApp-Bot

get_ip() {
  hostname -I 2>/dev/null | awk '{print $1}'
}

kill_all() {
  pkill -f "node server.js" 2>/dev/null
  pkill -f "cloudflared" 2>/dev/null
  sleep 1
}

start_tunnel() {
  if ! command -v cloudflared &> /dev/null; then
    echo "Instalando cloudflared..."
    pkg install -y cloudflared
  fi
  TUNNEL_LOG=$(mktemp)
  cloudflared tunnel --url http://localhost:3000 > "$TUNNEL_LOG" 2>&1 &
  TUNNEL_PID=$!
  TUNNEL_URL=""
  for i in $(seq 1 15); do
    sleep 1
    TUNNEL_URL=$(grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | head -1)
    if [ -n "$TUNNEL_URL" ]; then break; fi
  done
  rm -f "$TUNNEL_LOG"
  if [ -n "$TUNNEL_URL" ]; then
    echo ""
    echo "============================="
    echo "  Tunnel Externo"
    echo "============================="
    echo ""
    echo "Link: $TUNNEL_URL"
    echo ""
  else
    echo "[AVISO] Tunnel iniciado, mas o link ainda nao apareceu."
  fi
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
      if pgrep -f "cloudflared" > /dev/null; then
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
