const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const http = require('http');
const { Server } = require('socket.io');
const {
  default: makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
  fetchLatestBaileysVersion,
  makeCacheableSignalKeyStore,
} = require('@whiskeysockets/baileys');
const pino = require('pino');
const { Boom } = require('@hapi/boom');
const QRCode = require('qrcode');
const { AgentExecutor } = require('./agents/agent');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });
const PORT = process.env.PORT || 3000;
const logger = pino({ level: 'silent' });
const authDir = path.join(__dirname, 'auth');
const dataFile = path.join(__dirname, 'data.json');
if (!fs.existsSync(authDir)) fs.mkdirSync(authDir);

const defaultData = {
  prefix: '!', botName: 'WhatsApp Bot', ownerNumber: '',
  autoReply: true, scheduleEnabled: true,
  msgLimit: 2,
  msgLimitTime: 60,
  aiEnabled: false,
  aiProvider: 'openai',
  aiApiKey: '',
  aiModel: 'gpt-3.5-turbo',
  aiPrompt: 'Você é um assistente útil. Responda em português.',
  groupSettings: {
    welcomeEnabled: true, goodbyeEnabled: true,
    welcomeMessage: 'Bem-vindo ao grupo! 👋',
    goodbyeMessage: 'Até logo! 👋',
    antiLink: false, antiLinkMessage: 'Links não são permitidos!',
    antispam: false, muteAll: false,
  },
  commands: { ping: { response: 'Pong!', enabled: true, description: 'Verificar bot' } },
  autoReplies: { oi: 'Olá! Como posso ajudar?', 'bom dia': 'Bom dia! ☀️' },
};

function loadData() {
  if (!fs.existsSync(dataFile)) { fs.writeFileSync(dataFile, JSON.stringify(defaultData, null, 2)); return defaultData; }
  return JSON.parse(fs.readFileSync(dataFile, 'utf8'));
}
function saveData(data) { fs.writeFileSync(dataFile, JSON.stringify(data, null, 2)); }

app.use(cors()); app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

let sock = null, qrCode = null, connected = false, connectionStatus = 'disconnected';
let ngrokUrl = null;
const msgCounters = {};
let agentExecutor = null;

async function startWhatsApp() {
  try {
    const { state, saveCreds } = await useMultiFileAuthState(authDir);
    const { version } = await fetchLatestBaileysVersion();
    sock = makeWASocket({ version, logger, printQRInTerminal: false,
      auth: { creds: state.creds, keys: makeCacheableSignalKeyStore(state.keys, logger) },
      browser: ['WhatsApp Bot Web', 'Chrome', '4.0.0'],
    });
    agentExecutor = new AgentExecutor(sock, io);
    sock.ev.on('creds.update', saveCreds);
    sock.ev.on('connection.update', async (update) => {
      const { connection, lastDisconnect, qr } = update;
      if (qr) {
        qrCode = await QRCode.toDataURL(qr, { width: 300 });
        connectionStatus = 'waiting_qr';
        io.emit('qr', qrCode);
        io.emit('status', { connected: false, status: 'waiting_qr' });
      }
      if (connection === 'close') {
        const reason = new Boom(lastDisconnect?.error)?.output?.statusCode;
        if (reason !== DisconnectReason.loggedOut) {
          connectionStatus = 'reconnecting';
          io.emit('status', { connected: false, status: 'reconnecting' });
          setTimeout(() => startWhatsApp(), 3000);
        } else {
          connected = false; qrCode = null; connectionStatus = 'disconnected';
          io.emit('status', { connected: false, status: 'disconnected' });
          io.emit('qr', null);
        }
      }
      if (connection === 'open') {
        connected = true; qrCode = null; connectionStatus = 'connected';
        io.emit('status', { connected: true, status: 'connected' });
        io.emit('qr', null);
        console.log('✅ WhatsApp conectado!');
      }
    });
    sock.ev.on('messages.upsert', async ({ messages, type }) => {
      if (type !== 'notify') return;
      const msg = messages[0];
      if (!msg.key.fromMe && msg.message) await handleMessage(sock, msg);
    });
    sock.ev.on('group-participants.update', async (update) => {
      const data = loadData(); const gs = data.groupSettings || {};
      const { id, participants, action } = update;
      if (action === 'add' && gs.welcomeEnabled) {
        for (const p of participants) {
          await sock.sendMessage(id, { text: (gs.welcomeMessage || 'Bem-vindo!').replace('{user}', `@${p.split('@')[0]}`), mentions: [p] });
        }
      }
      if (action === 'remove' && gs.goodbyeEnabled) {
        for (const p of participants) {
          await sock.sendMessage(id, { text: (gs.goodbyeMessage || 'Até logo!').replace('{user}', `@${p.split('@')[0]}`), mentions: [p] });
        }
      }
    });
  } catch (err) { console.error('Erro WhatsApp:', err.message); }
}

async function handleMessage(sock, msg) {
  const data = loadData(); const from = msg.key.remoteJid;
  const isGroup = from.endsWith('@g.us');
  const sender = msg.key.participant || msg.key.remoteJid;
  const body = msg.message.conversation || msg.message.extendedTextMessage?.text || '';
  const gs = data.groupSettings || {};
  io.emit('message', { from, sender: sender.split('@')[0], body, time: new Date().toLocaleTimeString('pt-BR'), isGroup });

  if (isGroup) {
    if (gs.muteAll) return;
    if (gs.antiLink && body.match(/https?:\/\/|www\.|\.com|\.br|\.net|\.org|wa\.me|chat\.whatsapp/)) {
      try { await sock.sendMessage(from, { delete: msg.key }); await sock.sendMessage(from, { text: gs.antiLinkMessage || 'Links não são permitidos!' }); } catch (e) {}
      return;
    }
    if (gs.antispam) {
      const now = Date.now();
      if (global._lastMsg && global._lastMsg[sender] && (now - global._lastMsg[sender] < 3000)) {
        try { await sock.sendMessage(from, { delete: msg.key }); } catch (e) {}
        return;
      }
      global._lastMsg = global._lastMsg || {};
      global._lastMsg[sender] = now;
    }
  }

  // Rate limiting
  const data2 = loadData();
  const limit = data2.msgLimit || 2;
  const limitTime = (data2.msgLimitTime || 60) * 1000;
  const counterKey = isGroup ? from : sender;
  const now2 = Date.now();
  if (!msgCounters[counterKey]) msgCounters[counterKey] = [];
  msgCounters[counterKey] = msgCounters[counterKey].filter(t => now2 - t < limitTime);
  if (msgCounters[counterKey].length >= limit) {
    return;
  }
  msgCounters[counterKey].push(now2);

  if (!body.startsWith(data.prefix)) {
    if (data.aiEnabled && data.aiApiKey) {
      await handleAI(sock, from, body);
      return;
    }
    if (data.autoReply) {
      const lower = body.toLowerCase();
      for (const [key, value] of Object.entries(data.autoReplies)) {
        if (lower.includes(key.toLowerCase())) {
          await sock.sendMessage(from, { text: value });
          io.emit('bot_reply', { to: from, text: value });
          break;
        }
      }
    }
    return;
  }

  const [command] = body.slice(data.prefix.length).trim().split(/\s+/);
  const cmd = command.toLowerCase();

  if (cmd === 'ai' && data.aiEnabled && data.aiApiKey) {
    const question = body.slice(data.prefix.length + 3).trim();
    if (!question) { await sock.sendMessage(from, { text: 'Use: !ai sua pergunta' }); return; }
    await handleAI(sock, from, question);
    return;
  }

  if (cmd === 'agent' && data.aiEnabled && data.aiApiKey) {
    const args = body.slice(data.prefix.length + 6).trim();
    if (!args) {
      const agents = agentExecutor ? agentExecutor.getAvailableAgents() : [];
      const list = agents.map(a => `• *${a.name}* (${a.tools} tools) - ${a.description}`).join('\n');
      await sock.sendMessage(from, { text: `🤖 *Agentes disponíveis:*\n\n${list}\n\nUse: !agent [nome] [mensagem]` });
      return;
    }
    const spaceIdx = args.indexOf(' ');
    const agentName = spaceIdx > 0 ? args.slice(0, spaceIdx) : args;
    const agentMsg = spaceIdx > 0 ? args.slice(spaceIdx + 1).trim() : '';

    if (!agentMsg) {
      await sock.sendMessage(from, { text: 'Use: !agent [nome] [mensagem]' });
      return;
    }

    if (!agentExecutor) {
      await sock.sendMessage(from, { text: 'Agente não disponível. WhatsApp desconectado.' });
      return;
    }

    await sock.sendMessage(from, { text: '🔄 Processando com agente...' });
    try {
      const agentDef = agentExecutor.setAgent(from, agentName);
      const reply = await agentExecutor.run(from, agentMsg, async (messages, toolDefs) => {
        return await callAIWithTools(data.aiApiKey, data.aiProvider, messages, toolDefs);
      });
      await sock.sendMessage(from, { text: reply });
      io.emit('bot_reply', { to: from, text: reply });
    } catch (err) {
      await sock.sendMessage(from, { text: 'Erro no agente: ' + err.message });
    }
    return;
  }

  if (cmd === 'agents') {
    if (!agentExecutor) {
      await sock.sendMessage(from, { text: 'Sistema de agentes não disponível.' });
      return;
    }
    const agents = agentExecutor.getAvailableAgents();
    const list = agents.map(a => `• *${a.name}* - ${a.description}`).join('\n');
    await sock.sendMessage(from, { text: `🤖 *Agentes OpenCode:*\n\n${list}\n\nUse: !agent [nome] [mensagem]` });
    return;
  }

  if (isGroup && ['mute','unmute','antilink','welcome','goodbye'].includes(cmd)) {
    try {
      const groupMeta = await sock.groupMetadata(from);
      const admins = groupMeta.participants.filter(p => p.admin === 'admin' || p.admin === 'superadmin').map(p => p.id);
      if (!admins.includes(sender)) { await sock.sendMessage(from, { text: 'Apenas admins podem usar este comando.' }); return; }
    } catch (e) { return; }
    if (cmd === 'mute') { data.groupSettings.muteAll = true; saveData(data); await sock.sendMessage(from, { text: 'Bot silenciado.' }); return; }
    if (cmd === 'unmute') { data.groupSettings.muteAll = false; saveData(data); await sock.sendMessage(from, { text: 'Bot ativado.' }); return; }
    if (cmd === 'antilink') { data.groupSettings.antiLink = !data.groupSettings.antiLink; saveData(data); await sock.sendMessage(from, { text: `Anti-link ${data.groupSettings.antiLink ? 'ativado' : 'desativado'}.` }); return; }
    if (cmd === 'welcome') { data.groupSettings.welcomeEnabled = !data.groupSettings.welcomeEnabled; saveData(data); await sock.sendMessage(from, { text: `Welcome ${data.groupSettings.welcomeEnabled ? 'ativado' : 'desativado'}.` }); return; }
    if (cmd === 'goodbye') { data.groupSettings.goodbyeEnabled = !data.groupSettings.goodbyeEnabled; saveData(data); await sock.sendMessage(from, { text: `Goodbye ${data.groupSettings.goodbyeEnabled ? 'ativado' : 'desativado'}.` }); return; }
  }

  if (data.commands[cmd] && data.commands[cmd].enabled) {
    await sock.sendMessage(from, { text: data.commands[cmd].response });
    io.emit('bot_reply', { to: from, text: data.commands[cmd].response });
  }
}

// --- AI Handlers ---
async function handleAI(sock, from, prompt) {
  const data = loadData();
  try {
    await sock.sendMessage(from, { text: '🧠 Pensando...' });
    let reply = '';

    if (data.aiProvider === 'openai') {
      reply = await callOpenAI(data.aiApiKey, data.aiModel, data.aiPrompt, prompt);
    } else if (data.aiProvider === 'gemini') {
      reply = await callGemini(data.aiApiKey, data.aiModel, data.aiPrompt, prompt);
    } else if (data.aiProvider === 'mimo') {
      reply = await callMiMo(data.aiApiKey, data.aiModel, data.aiPrompt, prompt);
    } else if (data.aiProvider === 'deepseek') {
      reply = await callDeepSeek(data.aiApiKey, data.aiModel, data.aiPrompt, prompt);
    } else if (data.aiProvider === 'claude') {
      reply = await callClaude(data.aiApiKey, data.aiModel, data.aiPrompt, prompt);
    } else if (data.aiProvider === 'groq') {
      reply = await callGroq(data.aiApiKey, data.aiModel, data.aiPrompt, prompt);
    } else if (data.aiProvider === 'together') {
      reply = await callTogether(data.aiApiKey, data.aiModel, data.aiPrompt, prompt);
    } else if (data.aiProvider === 'nim') {
      reply = await callNIM(data.aiApiKey, data.aiModel, data.aiPrompt, prompt);
    }

    await sock.sendMessage(from, { text: reply || 'Erro ao obter resposta da IA.' });
    io.emit('bot_reply', { to: from, text: reply });
  } catch (err) {
    await sock.sendMessage(from, { text: 'Erro na IA: ' + err.message });
  }
}

async function callOpenAI(apiKey, model, systemPrompt, userPrompt) {
  const axios = require('axios');
  const res = await axios.post('https://api.openai.com/v1/chat/completions', {
    model: model || 'gpt-3.5-turbo',
    messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: userPrompt }],
    max_tokens: 500,
  }, { headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' } });
  return res.data.choices[0].message.content;
}

async function callGemini(apiKey, model, systemPrompt, userPrompt) {
  const axios = require('axios');
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const res = await axios.post(`https://generativelanguage.googleapis.com/v1beta/models/${model || 'gemini-2.0-flash'}:generateContent?key=${apiKey}`, {
        contents: [{ parts: [{ text: userPrompt }] }],
        systemInstruction: systemPrompt ? { parts: [{ text: systemPrompt }] } : undefined,
      });
      return res.data.candidates?.[0]?.content?.parts?.[0]?.text || 'Sem resposta';
    } catch (err) {
      if (err.response?.status === 429) {
        const msg = err.response?.data?.error?.message || '';
        const match = msg.match(/retry in ([\d.]+)/);
        const wait = match ? Math.ceil(parseFloat(match[1])) : 30;
        if (attempt === 0) {
          await new Promise(r => setTimeout(r, wait * 1000));
          continue;
        }
        throw new Error(`Quota Gemini excedida. Tente novamente em ${wait}s ou use outra API key.`);
      }
      throw err;
    }
  }
}

async function callMiMo(apiKey, model, systemPrompt, userPrompt) {
  const axios = require('axios');
  const res = await axios.post('https://api.siliconflow.cn/v1/chat/completions', {
    model: model || 'Qwen/MiMo-7B-RL',
    messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: userPrompt }],
    max_tokens: 500,
  }, { headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' } });
  return res.data.choices[0].message.content;
}

async function callDeepSeek(apiKey, model, systemPrompt, userPrompt) {
  const axios = require('axios');
  const res = await axios.post('https://api.deepseek.com/v1/chat/completions', {
    model: model || 'deepseek-chat',
    messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: userPrompt }],
    max_tokens: 500,
  }, { headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' } });
  return res.data.choices[0].message.content;
}

async function callClaude(apiKey, model, systemPrompt, userPrompt) {
  const axios = require('axios');
  const res = await axios.post('https://api.anthropic.com/v1/messages', {
    model: model || 'claude-3-haiku-20240307',
    max_tokens: 500,
    system: systemPrompt,
    messages: [{ role: 'user', content: userPrompt }],
  }, { headers: { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'Content-Type': 'application/json' } });
  return res.data.content[0].text;
}

async function callGroq(apiKey, model, systemPrompt, userPrompt) {
  const axios = require('axios');
  const res = await axios.post('https://api.groq.com/openai/v1/chat/completions', {
    model: model || 'llama-3.3-70b-versatile',
    messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: userPrompt }],
    max_tokens: 500,
  }, { headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' } });
  return res.data.choices[0].message.content;
}

async function callTogether(apiKey, model, systemPrompt, userPrompt) {
  const axios = require('axios');
  const res = await axios.post('https://api.together.xyz/v1/chat/completions', {
    model: model || 'meta-llama/Meta-Llama-3-8B-Instruct-Turbo',
    messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: userPrompt }],
    max_tokens: 500,
  }, { headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' } });
  return res.data.choices[0].message.content;
}

async function callNIM(apiKey, model, systemPrompt, userPrompt) {
  const axios = require('axios');
  const res = await axios.post('https://integrate.api.nvidia.com/v1/chat/completions', {
    model: model || 'meta/llama-3.3-70b-instruct',
    messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: userPrompt }],
    max_tokens: 500,
  }, { headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' } });
  return res.data.choices[0].message.content;
}

async function callAIWithTools(apiKey, provider, messages, tools) {
  const axios = require('axios');

  const providers = {
    openai: { url: 'https://api.openai.com/v1/chat/completions', model: 'gpt-4o-mini', auth: `Bearer ${apiKey}` },
    mimo: { url: 'https://api.siliconflow.cn/v1/chat/completions', model: 'Qwen/MiMo-7B-RL', auth: `Bearer ${apiKey}` },
    deepseek: { url: 'https://api.deepseek.com/v1/chat/completions', model: 'deepseek-chat', auth: `Bearer ${apiKey}` },
    groq: { url: 'https://api.groq.com/openai/v1/chat/completions', model: 'llama-3.3-70b-versatile', auth: `Bearer ${apiKey}` },
    together: { url: 'https://api.together.xyz/v1/chat/completions', model: 'meta-llama/Meta-Llama-3-70B-Instruct-Turbo', auth: `Bearer ${apiKey}` },
    claude: { url: 'https://api.anthropic.com/v1/messages', model: 'claude-3-haiku-20240307', auth: apiKey },
    gemini: { url: 'https://generativelanguage.googleapis.com/v1beta', model: 'gemini-pro', auth: apiKey },
    nim: { url: 'https://integrate.api.nvidia.com/v1/chat/completions', model: 'meta/llama-3.3-70b-instruct', auth: `Bearer ${apiKey}` },
  };

  const p = providers[provider];
  if (!p) throw new Error(`Provider '${provider}' não suporta ferramentas`);

  if (provider === 'claude') {
    const systemMsg = messages.find(m => m.role === 'system');
    const otherMsgs = messages.filter(m => m.role !== 'system');
    const claudeTools = tools ? tools.map(t => ({
      name: t.function.name,
      description: t.function.description,
      input_schema: t.function.parameters,
    })) : [];

    const body = {
      model: p.model,
      max_tokens: 2048,
      system: systemMsg ? systemMsg.content : '',
      messages: otherMsgs.map(m => {
        if (m.role === 'tool') return { role: 'user', content: `Tool result (${m.tool_call_id}): ${m.content}` };
        if (m.tool_calls) return { role: 'assistant', content: null, tool_use: m.tool_calls.map(tc => ({ id: tc.id, name: tc.function.name, input: typeof tc.function.arguments === 'string' ? JSON.parse(tc.function.arguments) : tc.function.arguments })) };
        return { role: m.role, content: m.content };
      }),
    };
    if (claudeTools.length > 0) body.tools = claudeTools;

    const res = await axios.post(p.url, body, {
      headers: { 'x-api-key': p.auth, 'anthropic-version': '2023-06-01', 'Content-Type': 'application/json' },
    });

    const block = res.data.content[0];
    if (block.type === 'tool_use') {
      return { content: null, tool_calls: [{ id: block.id, type: 'function', function: { name: block.name, arguments: JSON.stringify(block.input) } }] };
    }
    return { content: block.text };
  }

  const body = {
    model: p.model,
    messages,
    max_tokens: 2048,
  };
  if (tools && tools.length > 0) {
    body.tools = tools;
    body.tool_choice = 'auto';
  }

  const res = await axios.post(p.url, body, {
    headers: { 'Authorization': p.auth, 'Content-Type': 'application/json' },
  });

  const choice = res.data.choices[0];
  return choice.message;
}

// --- API Routes ---
io.on('connection', (socket) => { socket.emit('status', { connected, status: connectionStatus }); socket.emit('ngrok', ngrokUrl); if (qrCode) socket.emit('qr', qrCode); });

app.get('/status', (req, res) => res.json({ connected, status: connectionStatus, hasQR: !!qrCode, ngrok: ngrokUrl }));
app.get('/qr', (req, res) => res.json({ qr: qrCode }));
app.post('/connect', (req, res) => { if (connected) return res.json({ success: true }); if (!sock) startWhatsApp(); res.json({ success: true }); });
app.post('/disconnect', (req, res) => { if (sock) { sock.end(); sock = null; } connected = false; qrCode = null; connectionStatus = 'disconnected'; io.emit('status', { connected: false, status: 'disconnected' }); res.json({ success: true }); });
app.get('/config', (req, res) => res.json(loadData()));
app.post('/settings', (req, res) => { const data = loadData(); Object.assign(data, req.body); saveData(data); res.json({ success: true }); });

app.get('/commands', (req, res) => res.json(loadData().commands));
app.post('/commands/add', (req, res) => { const data = loadData(); data.commands[req.body.name] = { response: req.body.response, enabled: true, description: req.body.description || '' }; saveData(data); res.json({ success: true }); });
app.post('/commands/delete', (req, res) => { const data = loadData(); delete data.commands[req.body.name]; saveData(data); res.json({ success: true }); });
app.post('/commands/toggle', (req, res) => { const data = loadData(); if (data.commands[req.body.name]) { data.commands[req.body.name].enabled = !data.commands[req.body.name].enabled; saveData(data); res.json({ success: true }); } });

app.get('/autoreplies', (req, res) => res.json(loadData().autoReplies));
app.post('/autoreplies/add', (req, res) => { const data = loadData(); data.autoReplies[req.body.trigger] = req.body.response; saveData(data); res.json({ success: true }); });
app.post('/autoreplies/delete', (req, res) => { const data = loadData(); delete data.autoReplies[req.body.trigger]; saveData(data); res.json({ success: true }); });

app.get('/groups', async (req, res) => { if (!sock) return res.json([]); try { const groups = await sock.groupFetchAllParticipating(); res.json(Object.entries(groups).map(([id, g]) => ({ id, name: g.subject, participants: g.participants.length }))); } catch (e) { res.json([]); } });
app.get('/groupsettings', (req, res) => res.json(loadData().groupSettings || {}));
app.post('/groupsettings', (req, res) => { const data = loadData(); data.groupSettings = { ...data.groupSettings, ...req.body }; saveData(data); res.json({ success: true }); });

// --- Bulk Import/Export ---
app.get('/autoreplies/export', (req, res) => {
  const data = loadData();
  const ars = data.autoReplies || {};
  const text = Object.entries(ars).map(([k, v]) => `${k}|${v}`).join('\n');
  res.setHeader('Content-Type', 'text/plain');
  res.setHeader('Content-Disposition', 'attachment; filename="auto-replies.txt"');
  res.send(text || 'Nenhum auto-reply configurado');
});

app.post('/autoreplies/import', (req, res) => {
  const { text, mode } = req.body; // mode: 'append' or 'replace'
  if (!text) return res.status(400).json({ success: false, error: 'Texto vazio' });
  const data = loadData();
  const lines = text.split('\n').filter(l => l.trim());
  let added = 0;
  for (const line of lines) {
    const parts = line.split('|');
    if (parts.length >= 2) {
      const trigger = parts[0].trim().toLowerCase();
      const response = parts.slice(1).join('|').trim();
      if (trigger && response) {
        if (mode === 'replace') data.autoReplies = data.autoReplies || {};
        data.autoReplies[trigger] = response;
        added++;
      }
    }
  }
  saveData(data);
  res.json({ success: true, added });
});

app.get('/commands/export', (req, res) => {
  const data = loadData();
  const cmds = data.commands || {};
  const text = Object.entries(cmds).map(([k, v]) => `${k}|${v.response}|${v.description || ''}`).join('\n');
  res.setHeader('Content-Type', 'text/plain');
  res.setHeader('Content-Disposition', 'attachment; filename="commands.txt"');
  res.send(text || 'Nenhum comando configurado');
});

app.post('/commands/import', (req, res) => {
  const { text, mode } = req.body;
  if (!text) return res.status(400).json({ success: false, error: 'Texto vazio' });
  const data = loadData();
  const lines = text.split('\n').filter(l => l.trim());
  let added = 0;
  for (const line of lines) {
    const parts = line.split('|');
    if (parts.length >= 2) {
      const name = parts[0].trim().toLowerCase();
      const response = parts[1].trim();
      const description = parts[2]?.trim() || '';
      if (name && response) {
        if (mode === 'replace') data.commands = data.commands || {};
        data.commands[name] = { response, enabled: true, description };
        added++;
      }
    }
  }
  saveData(data);
  res.json({ success: true, added });
});

app.post('/autoreplies/clear', (req, res) => {
  const data = loadData();
  data.autoReplies = {};
  saveData(data);
  res.json({ success: true });
});

app.post('/commands/clear', (req, res) => {
  const data = loadData();
  data.commands = {};
  saveData(data);
  res.json({ success: true });
});

app.get('/ngrok', (req, res) => res.json({ url: ngrokUrl }));

// --- Agent Routes ---
app.get('/agents', (req, res) => {
  if (!agentExecutor) return res.json({ agents: [], error: 'Agent system not initialized' });
  res.json({ agents: agentExecutor.getAvailableAgents() });
});

app.get('/agents/status', (req, res) => {
  res.json({
    initialized: !!agentExecutor,
    sessions: agentExecutor ? agentExecutor.sessions.size : 0,
  });
});

app.post('/agents/clear/:chatKey', (req, res) => {
  if (!agentExecutor) return res.json({ success: false });
  agentExecutor.clearSession(req.params.chatKey);
  res.json({ success: true });
});
app.post('/ngrok/start', async (req, res) => {
  try {
    const { execSync } = require('child_process');
    const output = execSync('ngrok http 3000 --log=stdout 2>&1 & sleep 3 && curl -s http://127.0.0.1:4040/api/tunnels', { timeout: 10000 }).toString();
    const tunnels = JSON.parse(output);
    ngrokUrl = tunnels.tunnels[0]?.public_url || null;
    io.emit('ngrok', ngrokUrl);
    res.json({ success: true, url: ngrokUrl });
  } catch (e) {
    res.json({ success: false, error: 'Ngrok não instalado. Rode: pkg install ngrok' });
  }
});

process.on('uncaughtException', (err) => console.error('Erro:', err.message));

server.listen(PORT, '0.0.0.0', () => {
  console.log(`\n🚀 Servidor: http://localhost:${PORT}`);
  console.log(`📱 Painel web: abra no navegador\n`);
  loadData();
});
