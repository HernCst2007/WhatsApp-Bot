#!/bin/bash
# Configuracao do ngrok (Token)
# Uso: bash ngrok-tool/install.sh

SCRIPT_DIR="$(dirname "$0")"
NGROK_BIN="$SCRIPT_DIR/ngrok"

echo "============================="
echo "  Configuracao do ngrok"
echo "============================"
echo ""

# Verificar binario
if [ ! -x "$NGROK_BIN" ]; then
  echo "[ERRO] Binario ngrok nao encontrado em ngrok-tool/"
  echo "       Baixe manualmente de https://ngrok.com/download"
  exit 1
fi

echo "Binario: $NGROK_BIN"
echo "Versao: $($NGROK_BIN version 2>/dev/null || echo 'desconhecida')"
echo ""

# Verificar se ja tem token
AUTHTOKEN_FILE="$HOME/.config/ngrok/ngrok.yml"
if [ -f "$AUTHTOKEN_FILE" ] && grep -q "authtoken:" "$AUTHTOKEN_FILE" 2>/dev/null; then
  echo "Token ja configurado!"
  echo ""
  echo "Para reconfigurar, execute:"
  echo "  $NGROK_BIN config add-authtoken SEU_TOKEN"
  echo ""
  exit 0
fi

echo "Para usar o ngrok, configure seu token:"
echo ""
echo "  1. Crie conta: https://dashboard.ngrok.com/signup"
echo "  2. Copie o token: https://dashboard.ngrok.com/get-started/your-authtoken"
echo "  3. Execute: $NGROK_BIN config add-authtoken SEU_TOKEN"
echo ""
echo "Uso:"
echo "  bash start.sh --ngrok     # Iniciar bot com ngrok"
echo "  $NGROK_BIN http 3000      # Expor porta 3000 manualmente"
echo ""
