#!/bin/bash
# Gerenciador do WhatsApp Bot (Termux)

PROJDIR=/sdcard/WhatsApp-Bot
NGROK_SRC="$PROJDIR/ngrok-tool/ngrok"

get_ip() {
  hostname -I 2>/dev/null | awk '{print $1}'
}

kill_all() {
  pkill -f "node server.js" 2>/dev/null
  pkill -f "ngrok" 2>/dev/null
  sleep 1
}

start_ngrok() {
  if [ -f "$NGROK_SRC" ]; then
    NGROK_BIN="$HOME/.local/bin/ngrok"
    mkdir -p "$HOME/.local/bin"
    cp "$NGROK_SRC" "$NGROK_BIN"
    chmod +x "$NGROK_BIN"
    RESOLV_CONF="$PROJDIR/ngrok-tool/etc/resolv.conf"
    PROOT_BIN=$(command -v proot 2>/dev/null)
    if [ -n "$PROOT_BIN" ] && [ -f "$RESOLV_CONF" ]; then
      proot -b "$RESOLV_CONF:/etc/resolv.conf" "$NGROK_BIN" http 3000 &>/dev/null &
    else
      "$NGROK_BIN" http 3000 &>/dev/null &
    fi
    NGROK_PID=$!
    sleep 4
    NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$NGROK_URL" ]; then
      echo "Ngrok: ${NGROK_URL}"
    fi
  else
    echo "[AVISO] Binario ngrok nao encontrado em ngrok-tool/"
  fi
}

case "$1" in
  start)
    kill_all
    cd "$PROJDIR/server"
    if [ ! -d "node_modules" ]; then
      echo "Instalando dependencias..."
      npm install
    fi
    setsid node server.js < /dev/null > /dev/null 2>&1 &
    sleep 2
    IP=$(get_ip)
    echo "Bot iniciado!"
    echo "http://${IP}:3000"
    ;;
  start-ngrok)
    kill_all
    cd "$PROJDIR/server"
    if [ ! -d "node_modules" ]; then
      echo "Instalando dependencias..."
      npm install
    fi
    setsid node server.js < /dev/null > /dev/null 2>&1 &
    sleep 2
    IP=$(get_ip)
    echo "Bot iniciado!"
    echo "http://${IP}:3000"
    start_ngrok
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
      if pgrep -f "ngrok" > /dev/null; then
        echo "Ngrok: rodando"
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
    echo "Uso: bash ~/WhatsApp-Bot/boot/bot-start.sh [comando]"
    echo ""
    echo "Comandos:"
    echo "  start         Iniciar bot"
    echo "  start-ngrok   Iniciar bot + ngrok"
    echo "  stop          Parar bot"
    echo "  restart       Reiniciar bot"
    echo "  status        Ver status"
    echo "  ip            Mostrar IP"
    echo "  hide-notif    Ocultar notificacoes"
    ;;
esac
