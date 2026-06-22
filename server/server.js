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

async function startWhatsApp() {
  try {
    const { state, saveCreds } = await useMultiFileAuthState(authDir);
    const { version } = await fetchLatestBaileysVersion();
    sock = makeWASocket({ version, logger, printQRInTerminal: false,
      auth: { creds: state.creds, keys: makeCacheableSignalKeyStore(state.keys, logger) },
      browser: ['WhatsApp Bot Web', 'Chrome', '4.0.0'],
    });
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

  if (!body.startsWith(data.prefix)) {
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

app.get('/ngrok', (req, res) => res.json({ url: ngrokUrl }));
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
