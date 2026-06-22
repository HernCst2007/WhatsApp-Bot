const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const DATA_FILE = path.join(__dirname, '..', 'data.json');

function loadData() {
  if (!fs.existsSync(DATA_FILE)) return {};
  return JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
}

function saveData(data) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
}

const tools = {
  send_message: {
    description: 'Enviar mensagem para um contato ou grupo do WhatsApp',
    parameters: {
      type: 'object',
      properties: {
        to: { type: 'string', description: 'JID do destinatário (ex: 5511999999999@g.us ou 5511999999999@s.whatsapp.net)' },
        text: { type: 'string', description: 'Texto da mensagem a ser enviada' },
      },
      required: ['to', 'text'],
    },
    async execute(sock, params) {
      if (!sock) return { success: false, error: 'WhatsApp não conectado' };
      try {
        await sock.sendMessage(params.to, { text: params.text });
        return { success: true, sent_to: params.to };
      } catch (err) {
        return { success: false, error: err.message };
      }
    },
  },

  get_groups: {
    description: 'Listar todos os grupos que o bot participa',
    parameters: { type: 'object', properties: {} },
    async execute(sock) {
      if (!sock) return { success: false, error: 'WhatsApp não conectado' };
      try {
        const groups = await sock.groupFetchAllParticipating();
        return {
          success: true,
          groups: Object.entries(groups).map(([id, g]) => ({
            id,
            name: g.subject,
            participants: g.participants.length,
          })),
        };
      } catch (err) {
        return { success: false, error: err.message };
      }
    },
  },

  get_group_info: {
    description: 'Obter informações detalhadas de um grupo',
    parameters: {
      type: 'object',
      properties: {
        group_id: { type: 'string', description: 'ID do grupo' },
      },
      required: ['group_id'],
    },
    async execute(sock, params) {
      if (!sock) return { success: false, error: 'WhatsApp não conectado' };
      try {
        const meta = await sock.groupMetadata(params.group_id);
        return {
          success: true,
          id: params.group_id,
          name: meta.subject,
          description: meta.desc,
          participants: meta.participants.map(p => ({
            id: p.id,
            admin: p.admin || 'member',
          })),
          owner: meta.owner,
        };
      } catch (err) {
        return { success: false, error: err.message };
      }
    },
  },

  get_config: {
    description: 'Obter configurações atuais do bot',
    parameters: { type: 'object', properties: {} },
    async execute() {
      const data = loadData();
      return {
        success: true,
        config: {
          prefix: data.prefix,
          botName: data.botName,
          aiEnabled: data.aiEnabled,
          aiProvider: data.aiProvider,
          autoReply: data.autoReply,
          msgLimit: data.msgLimit,
          msgLimitTime: data.msgLimitTime,
          groupSettings: data.groupSettings,
          commandsCount: Object.keys(data.commands || {}).length,
          autoRepliesCount: Object.keys(data.autoReplies || {}).length,
        },
      };
    },
  },

  update_config: {
    description: 'Atualizar configurações do bot',
    parameters: {
      type: 'object',
      properties: {
        settings: { type: 'object', description: 'Objeto com as configurações a atualizar' },
      },
      required: ['settings'],
    },
    async execute(_, params) {
      const data = loadData();
      Object.assign(data, params.settings);
      saveData(data);
      return { success: true, updated: Object.keys(params.settings) };
    },
  },

  add_command: {
    description: 'Adicionar um novo comando personalizado ao bot',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Nome do comando (sem o prefixo)' },
        response: { type: 'string', description: 'Resposta do comando' },
        description: { type: 'string', description: 'Descrição do comando' },
      },
      required: ['name', 'response'],
    },
    async execute(_, params) {
      const data = loadData();
      data.commands = data.commands || {};
      data.commands[params.name.toLowerCase()] = {
        response: params.response,
        enabled: true,
        description: params.description || '',
      };
      saveData(data);
      return { success: true, command: params.name };
    },
  },

  remove_command: {
    description: 'Remover um comando personalizado',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Nome do comando a remover' },
      },
      required: ['name'],
    },
    async execute(_, params) {
      const data = loadData();
      if (data.commands && data.commands[params.name]) {
        delete data.commands[params.name];
        saveData(data);
        return { success: true, removed: params.name };
      }
      return { success: false, error: 'Comando não encontrado' };
    },
  },

  add_autoreply: {
    description: 'Adicionar uma resposta automática',
    parameters: {
      type: 'object',
      properties: {
        trigger: { type: 'string', description: 'Gatilho (palavra/frase que ativa)' },
        response: { type: 'string', description: 'Resposta automática' },
      },
      required: ['trigger', 'response'],
    },
    async execute(_, params) {
      const data = loadData();
      data.autoReplies = data.autoReplies || {};
      data.autoReplies[params.trigger.toLowerCase()] = params.response;
      saveData(data);
      return { success: true, trigger: params.trigger };
    },
  },

  remove_autoreply: {
    description: 'Remover uma resposta automática',
    parameters: {
      type: 'object',
      properties: {
        trigger: { type: 'string', description: 'Gatilho a remover' },
      },
      required: ['trigger'],
    },
    async execute(_, params) {
      const data = loadData();
      if (data.autoReplies && data.autoReplies[params.trigger]) {
        delete data.autoReplies[params.trigger];
        saveData(data);
        return { success: true, removed: params.trigger };
      }
      return { success: false, error: 'Gatilho não encontrado' };
    },
  },

  run_script: {
    description: 'Executar um script bash/shell no servidor (USE COM CUIDADO)',
    parameters: {
      type: 'object',
      properties: {
        command: { type: 'string', description: 'Comando a executar' },
        timeout: { type: 'number', description: 'Timeout em segundos (padrão: 10)' },
      },
      required: ['command'],
    },
    async execute(_, params) {
      try {
        const timeout = (params.timeout || 10) * 1000;
        const output = execSync(params.command, {
          timeout,
          encoding: 'utf8',
          maxBuffer: 1024 * 512,
        });
        return { success: true, output: output.trim().slice(0, 2000) };
      } catch (err) {
        return { success: false, error: err.message.slice(0, 1000) };
      }
    },
  },

  list_commands: {
    description: 'Listar todos os comandos configurados no bot',
    parameters: { type: 'object', properties: {} },
    async execute() {
      const data = loadData();
      const commands = data.commands || {};
      return {
        success: true,
        commands: Object.entries(commands).map(([name, cmd]) => ({
          name,
          response: cmd.response,
          enabled: cmd.enabled,
          description: cmd.description,
        })),
      };
    },
  },

  list_autoreplies: {
    description: 'Listar todas as respostas automáticas configuradas',
    parameters: { type: 'object', properties: {} },
    async execute() {
      const data = loadData();
      const replies = data.autoReplies || {};
      return {
        success: true,
        autoReplies: Object.entries(replies).map(([trigger, response]) => ({
          trigger,
          response,
        })),
      };
    },
  },
};

module.exports = { tools };
