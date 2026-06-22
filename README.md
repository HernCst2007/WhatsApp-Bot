# WhatsApp Bot v2

Bot para WhatsApp com painel web completo. Sem APK necessário.

## Início rápido

```bash
cd ~/whatsapp-bot/server
npm install
node server.js
```

Acesse no navegador: **http://localhost:3000**

## Funcionalidades

- **Painel Web** - Gerencie tudo pelo navegador
- **Comandos** - Crie comandos personalizados
- **Auto-Replies** - Respostas automáticas
- **Grupos** - Welcome, goodbye, antilink, antispam, mute
- **Chat ao Vivo** - Veja mensagens em tempo real
- **Ngrok** - Acesse de qualquer lugar (4G, outro celular)

## Acesso Externo (Ngrok)

```bash
# Instalar ngrok
pkg install ngrok

# No painel web, clique em "Ativar Ngrok"
# Ou manualmente:
ngrok http 3000
```

## Comandos do Bot

| Comando | Descrição |
|---------|-----------|
| !ping | Verificar bot |
| !addcmd [nome] [resposta] | Criar comando |
| !delcmd [nome] | Remover comando |
| !addreply [gatilho] [resposta] | Criar auto-reply |
| !delreply [gatilho] | Remover auto-reply |

### Comandos de Grupo (só admin)

| Comando | Descrição |
|---------|-----------|
| !welcome | Ativar/desativar boas-vindas |
| !goodbye | Ativar/desativar despedida |
| !antilink | Bloquear links |
| !mute / !unmute | Silenciar/ativar bot |

## Estrutura

```
whatsapp-bot/
├── start.sh          # Script de início
├── README.md
└── server/
    ├── server.js     # Bot + API + Socket.IO
    ├── data.json     # Configurações (editável pelo painel)
    ├── package.json
    └── public/
        └── index.html # Painel web completo
```

## Tecnologias

- **Node.js** + Baileys (WhatsApp)
- **Express** + Socket.IO (servidor + tempo real)
- **HTML/CSS/JS** (painel web mobile-first)
