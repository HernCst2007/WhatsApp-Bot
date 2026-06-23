# WhatsApp Bot

Bot para WhatsApp multiplataforma compatível com termux, painel web de gerenciamento. Suporte a comandos, auto-replies, grupos, IA e subagentes com ferramentas.

## Pre-requisitos

- [Git](https://git-scm.com/)
- WhatsApp instalado no celular

> Node.js e ngrok sao instalados automaticamente pelo script de setup.

## Instalacao

### Instalacao Rapida

**Termux (Android):**
```bash
git clone https://github.com/HernCst2007/WhatsApp-Bot.git /sdcard/WhatsApp-Bot
cd /sdcard/WhatsApp-Bot
bash setup.sh
```

**Windows:**
```cmd
git clone https://github.com/HernCst2007/WhatsApp-Bot.git C:\WhatsApp-Bot
cd C:\WhatsApp-Bot
setup.bat
```

O setup instala automaticamente:
- Node.js (v18+)
- Dependencias do projeto
- Binario ngrok (para acesso externo)

### Gerenciador Termux

```bash
bash boot/bot-start.sh start         # Iniciar
bash boot/bot-start.sh start-ngrok   # Iniciar com ngrok
bash boot/bot-start.sh stop          # Parar
bash boot/bot-start.sh restart       # Reiniciar
bash boot/bot-start.sh status        # Ver status
bash boot/bot-start.sh ip            # Mostrar IP
```

### Auto-Start no Boot (Termux)

```bash
mkdir -p ~/.termux/boot
cp boot/00-whatsapp-bot.sh ~/.termux/boot/
chmod +x ~/.termux/boot/00-whatsapp-bot.sh
```

## Conectar ao WhatsApp

1. No painel web, clique em **Conectar**
2. Escaneie o QR Code com o WhatsApp
3. Aguarde a conexao ser estabelecida

## Painel Web

Acesse `http://localhost:3000`

### Comandos

- Adicione comandos personalizados com nome e resposta
- Ative/desative com um clique
- Importacao/exportacao em massa

### Auto-Replies

- Respostas automaticas para palavras-chave
- Importacao via wordlist (formato: `gatilho|resposta`)

### Grupos

- **Welcome**: Mensagem de boas-vindas ao entrar
- **Goodbye**: Mensagem ao sair do grupo
- **Anti-Link**: Bloqueia links automaticamente
- **Anti-Spam**: Bloqueia mensagens repetidas
- **Mute**: Silencia o bot no grupo

### Configuracoes

- Nome do bot e prefixo dos comandos
- Limite de mensagens por contato/grupo
- Auto-reply ligado/desligado

## Inteligencia Artificial

Suporte a multiplos providers com seletor de modelos no painel:

| Provider | Modelos Suportados |
|----------|-------------------|
| OpenAI | gpt-4o, gpt-4o-mini, gpt-4-turbo, gpt-3.5-turbo |
| Google Gemini | gemini-2.0-flash, gemini-2.5-flash, gemini-2.5-pro |
| MiMo (Xiaomi) | Qwen/MiMo-7B-RL |
| DeepSeek | deepseek-chat, deepseek-reasoner |
| Claude | claude-3-5-sonnet, claude-3-haiku, claude-3-opus |
| Groq | llama-3.3-70b, llama-3.1-8b, mixtral-8x7b |
| Together AI | Llama-3-70B, Llama-3-8B, Mixtral-8x7B |
| NVIDIA NIM | llama-3.3-70b, deepseek-r1, nemotron-70b |

Configure no painel: ative IA, escolha o provider, insira a API Key e selecione o modelo.

### Comandos de IA

| Comando | Descricao |
|---------|-----------|
| !ai [pergunta] | Chat com a IA |
| !agent [nome] [msg] | Executar subagente com ferramentas |
| !agents | Listar agentes disponiveis |

## Subagentes (OpenCode)

Sistema de subagentes inspirado no [OpenCode](https://github.com/anomalyco/opencode), com ferramentas para automacao:

### Agentes Disponiveis

| Agente | Descricao | Ferramentas |
|--------|-----------|-------------|
| **build** | Desenvolvimento completo | Enviar mensagens, gerenciar comandos, config, scripts |
| **plan** | Apenas analise e consulta | Consultar grupos, config, comandos |
| **general** | Perguntas rapidas | Sem ferramentas |

### Ferramentas do Agente Build

- `send_message` - Enviar mensagem para contato/grupo
- `get_groups` - Listar grupos
- `get_group_info` - Info detalhada do grupo
- `get_config` - Ver configuracoes
- `update_config` - Alterar configuracoes
- `add_command` / `remove_command` - Gerenciar comandos
- `add_autoreply` / `remove_autoreply` - Gerenciar auto-replies
- `run_script` - Executar scripts no servidor

### Exemplo de Uso

```
!agent build Envie "Bot online!" para o grupo
!agent plan Quais grupos estao ativos?
!agent build Adicione o comando uptime com resposta "Estou online!"
```

## Comandos do Bot

### Gerais

| Comando | Descricao |
|---------|-----------|
| !ping | Verificar se o bot esta ativo |
| !ai [pergunta] | Perguntar para a IA |
| !agent [nome] [msg] | Executar subagente |
| !agents | Listar agentes |

### Grupo (so admin)

| Comando | Descricao |
|---------|-----------|
| !welcome | Ativar/desativar boas-vindas |
| !goodbye | Ativar/desativar despedida |
| !antilink | Bloquear links no grupo |
| !mute | Silenciar o bot |
| !unmute | Ativar o bot |

## Wordlist (Importacao em Massa)

Crie um arquivo `wordlist.txt` com o formato:

```
gatilho1|resposta
gatilho2|resposta
```

Importe pelo painel web em **Wordlist > Importar**.

## API Endpoints

| Rota | Metodo | Descricao |
|------|--------|-----------|
| `/status` | GET | Status da conexao |
| `/config` | GET | Configuracoes atuais |
| `/settings` | POST | Salvar configuracoes |
| `/commands` | GET | Listar comandos |
| `/commands/add` | POST | Adicionar comando |
| `/autoreplies` | GET | Listar auto-replies |
| `/groups` | GET | Listar grupos |
| `/agents` | GET | Listar agentes |
| `/agents/status` | GET | Status do sistema de agentes |

## Estrutura do Projeto

```
WhatsApp-Bot/
├── README.md
├── setup.sh                # Setup completo (Termux/Linux)
├── setup.bat               # Setup completo (Windows)
├── start.bat               # Inicio rapido (Windows)
├── start.sh                # Inicio rapido (Termux)
├── bot.bat                 # Gerenciador (Windows)
├── boot/
│   ├── 00-whatsapp-bot.sh  # Auto-start no boot
│   └── bot-start.sh        # Gerenciador (Termux)
├── ngrok-tool/
│   ├── ngrok               # Binario ngrok (Linux ARM64)
│   ├── windows/
│   │   └── ngrok.exe       # Binario ngrok (Windows AMD64)
│   └── install.sh          # Configuracao do token
└── server/
    ├── server.js           # Servidor + Bot
    ├── agents/
    │   ├── agent.js        # Sistema de subagentes
    │   └── tools.js        # Ferramentas WhatsApp
    ├── data.json           # Configuracoes (gitignored)
    ├── data.json.example   # Template de configuracao
    ├── package.json
    └── public/
        └── index.html      # Painel web
```

## Acesso Externo (Ngrok)

Ngrok esta incluso no projeto - sem necessidade de instalacao externa.

### Configurar Token (obrigatorio para uso online)

1. Crie conta em https://dashboard.ngrok.com/signup
2. Copie o token em https://dashboard.ngrok.com/get-started/your-authtoken
3. Execute:
   ```bash
   bash ngrok-tool/install.sh
   # Siga as instrucoes para configurar o token
   ```

### Iniciar com Ngrok

**Termux:**
```bash
bash start.sh --ngrok
```

**Windows:**
```cmd
start.bat --ngrok
```

**Gerenciador Termux:**
```bash
bash boot/bot-start.sh start-ngrok
```

**Gerenciador Windows:**
```cmd
bot.bat start-ngrok
```

**Manual:**
```bash
./ngrok-tool/ngrok http 3000
```

Acesse o painel ngrok em http://localhost:4040 para ver as URLs publicas.

## Tecnologias

- **Backend**: Node.js, Express, Socket.IO
- **WhatsApp**: Baileys
- **Painel Web**: HTML, CSS, JavaScript
- **IA**: OpenAI, Gemini, MiMo, DeepSeek, Claude, Groq, Together, NVIDIA NIM
- **Agentes**: Sistema inspirado no OpenCode com tool calling

## Licenca

MIT
