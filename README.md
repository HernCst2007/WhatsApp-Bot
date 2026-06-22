# WhatsApp Bot

Bot para WhatsApp com painel web de gerenciamento. Suporte a comandos, auto-replies, grupos e IA.

## Pré-requisitos

- [Node.js](https://nodejs.org/) (v18+)
- [Git](https://git-scm.com/)
- WhatsApp instalado no celular

## Instalação

### 1. Clone o repositório

```bash
git clone https://github.com/HernCst2007/WhatsApp-Bot.git
cd WhatsApp-Bot
```

### 2. Instale as dependências do servidor

```bash
cd server
npm install
```

### 3. Inicie o servidor

```bash
node server.js
```

### 4. Acesse o painel web

Abra o navegador e acesse:

```
http://localhost:3000
```

## Conectar ao WhatsApp

1. No painel web, clique em **Conectar**
2. Escaneie o QR Code com o WhatsApp
3. Aguarde a conexão ser estabelecida

## Gerenciamento pelo Painel

### Comandos

- Adicione comandos personalizados com nome e resposta
- Ative/desative com um clique

### Auto-Replies

- Configure respostas automáticas para palavras-chave
- Importação em massa via wordlist (formato: `gatilho|resposta`)

### Grupos

- **Welcome**: Mensagem de boas-vindas ao entrar
- **Goodbye**: Mensagem ao sair do grupo
- **Anti-Link**: Bloqueia links automaticamente
- **Anti-Spam**: Bloqueia mensagens repetidas
- **Mute**: Silencia o bot no grupo

### Inteligência Artificial

Configure uma das IAs suportadas para responder automaticamente:

| Provider | Modelo |
|----------|--------|
| OpenAI | GPT-4, GPT-3.5-turbo |
| Google Gemini | gemini-pro |
| MiMo | MiMo-7B-RL |
| DeepSeek | deepseek-chat |
| Claude | claude-3-haiku |
| Groq | Llama 3.3 70B |
| Together AI | Llama 3 8B |

### Configurações

- Nome do bot
- Prefixo dos comandos
- Limite de mensagens por contato/grupo
- Auto-reply ligado/desligado

## Comandos do Bot

### Comandos Gerais

| Comando | Descrição |
|---------|-----------|
| !ping | Verificar se o bot está ativo |
| !ai [pergunta] | Perguntar para a IA |

### Comandos de Grupo (só admin)

| Comando | Descrição |
|---------|-----------|
| !welcome | Ativar/desativar boas-vindas |
| !goodbye | Ativar/desativar despedida |
| !antilink | Bloquear links no grupo |
| !mute | Silenciar o bot |
| !unmute | Ativar o bot |

### Gerenciamento via Chat

| Comando | Descrição |
|---------|-----------|
| !addcmd [nome] [resposta] | Criar comando |
| !delcmd [nome] | Remover comando |
| !addreply [gatilho] [resposta] | Criar auto-reply |
| !delreply [gatilho] | Remover auto-reply |

## Wordlist (Importação em Massa)

Crie um arquivo `wordlist.txt` com o formato:

```
gatilho1|resposta
gatilho2|resposta
gatilho3|resposta
```

Exemplo:

```
oi|Não estou disponível no momento!
bom dia|Não estou disponível no momento!
obrigado|De nada!
```

Importe pelo painel web em **Wordlist > Importar**.

## Acesso Externo (Ngrok)

Para acessar o painel de qualquer lugar:

```bash
# Instale o ngrok
# https://ngrok.com/download

# Inicie o túnel
ngrok http 3000
```

Ou pelo painel web, clique em **Ativar Ngrok**.

## Estrutura do Projeto

```
WhatsApp-Bot/
├── README.md
├── start.sh                    # Início rápido
├── boot/
│   ├── 00-whatsapp-bot.sh     # Auto-start no boot
│   └── bot-start.sh           # Gerenciador
└── server/
    ├── server.js               # Servidor + Bot
    ├── data.json               # Configurações
    ├── wordlist.txt            # 612 gatilhos
    ├── package.json
    └── public/
        └── index.html          # Painel web
```

## Servidor de Boot (Auto-Start)

Para o bot iniciar automaticamente ao ligar o celular (Termux):

```bash
# Copie o script de boot
mkdir -p ~/.termux/boot
cp boot/00-whatsapp-bot.sh ~/.termux/boot/
chmod +x ~/.termux/boot/00-whatsapp-bot.sh
```

## Gerenciador

```bash
# Iniciar
bash boot/bot-start.sh start

# Parar
bash boot/bot-start.sh stop

# Reiniciar
bash boot/bot-start.sh restart

# Ver status
bash boot/bot-start.sh status

# Ver IP
bash boot/bot-start.sh ip
```

## Tecnologias

- **Backend**: Node.js, Express, Socket.IO
- **WhatsApp**: Baileys
- **Painel Web**: HTML, CSS, JavaScript
- **IA**: OpenAI, Gemini, MiMo, DeepSeek, Claude, Groq, Together

## Licença

MIT
