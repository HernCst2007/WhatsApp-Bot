const { tools } = require('./tools');

const agentDefinitions = {
  build: {
    id: 'build',
    name: 'Build',
    description: 'Agente de desenvolvimento completo. Pode enviar mensagens, gerenciar comandos, configurações e executar scripts.',
    system: `Você é um agente de IA especializado em gerenciar um WhatsApp Bot.
Você tem acesso a ferramentas para:
- Enviar mensagens para contatos e grupos
- Gerenciar comandos do bot (adicionar, remover, listar)
- Gerenciar respostas automáticas
- Alterar configurações do bot
- Consultar grupos e informações do WhatsApp
- Executar scripts no servidor

Responda SEMPRE em português brasileiro.
Ao usar ferramentas, seja conciso e direto.
Quando executar scripts, tome cuidado - apenas comandos seguros e curtos.
Se não souber algo, diga que não tem certeza.`,
    mode: 'primary',
    tools: ['send_message', 'get_groups', 'get_group_info', 'get_config', 'update_config',
            'add_command', 'remove_command', 'list_commands', 'add_autoreply', 'remove_autoreply',
            'list_autoreplies', 'run_script'],
  },

  plan: {
    id: 'plan',
    name: 'Plan',
    description: 'Agente de planejamento e análise. Apenas consulta informações, sem executar ações.',
    system: `Você é um agente de planejamento e análise para um WhatsApp Bot.
Você pode APENAS consultar informações:
- Ver configurações do bot
- Listar comandos e respostas automáticas
- Ver grupos e informações
NÃO pode enviar mensagens, alterar configurações ou executar scripts.
Analise os dados e forneça recomendações claras.
Responda SEMPRE em português brasileiro.`,
    mode: 'primary',
    tools: ['get_groups', 'get_group_info', 'get_config', 'list_commands', 'list_autoreplies'],
  },

  general: {
    id: 'general',
    name: 'General',
    description: 'Agente geral para tarefas simples e perguntas rápidas.',
    system: `Você é um assistente geral para um WhatsApp Bot.
Responda perguntas e forneça informações úteis sobre o bot.
Responda SEMPRE em português brasileiro e de forma concisa.
Máximo de 3 frases por resposta.`,
    mode: 'subagent',
    tools: [],
  },
};

class AgentSession {
  constructor(agentId) {
    this.agentId = agentId;
    this.agent = agentDefinitions[agentId] || agentDefinitions.general;
    this.messages = [];
  }

  addUserMessage(text) {
    this.messages.push({ role: 'user', content: text });
  }

  addAssistantMessage(text) {
    this.messages.push({ role: 'assistant', content: text });
  }

  addToolResult(toolName, result) {
    this.messages.push({
      role: 'tool',
      tool_name: toolName,
      content: JSON.stringify(result),
    });
  }

  getHistory() {
    return [...this.messages];
  }

  clear() {
    this.messages = [];
  }
}

class AgentExecutor {
  constructor(sock, io) {
    this.sock = sock;
    this.io = io;
    this.sessions = new Map();
  }

  getSession(chatKey) {
    if (!this.sessions.has(chatKey)) {
      this.sessions.set(chatKey, new AgentSession('build'));
    }
    return this.sessions.get(chatKey);
  }

  setAgent(chatKey, agentId) {
    const session = this.getSession(chatKey);
    session.agentId = agentId;
    session.agent = agentDefinitions[agentId] || agentDefinitions.general;
    session.clear();
    return session.agent;
  }

  getAvailableAgents() {
    return Object.values(agentDefinitions).map(a => ({
      id: a.id,
      name: a.name,
      description: a.description,
      mode: a.mode,
      tools: a.tools.length,
    }));
  }

  buildMessages(session, userMessage) {
    const agentDef = session.agent;
    const messages = [
      { role: 'system', content: agentDef.system },
      ...session.getHistory(),
      { role: 'user', content: userMessage },
    ];
    return messages;
  }

  getToolDefinitions(agentId) {
    const agentDef = agentDefinitions[agentId];
    if (!agentDef || !agentDef.tools) return [];

    return agentDef.tools
      .filter(name => tools[name])
      .map(name => ({
        type: 'function',
        function: {
          name,
          description: tools[name].description,
          parameters: tools[name].parameters,
        },
      }));
  }

  async executeTool(toolName, params) {
    const tool = tools[toolName];
    if (!tool) return { success: false, error: `Tool '${toolName}' not found` };
    return await tool.execute(this.sock, params);
  }

  async run(chatKey, userMessage, providerCall) {
    const session = this.getSession(chatKey);
    session.addUserMessage(userMessage);

    const toolDefs = this.getToolDefinitions(session.agentId);
    const messages = this.buildMessages(session, userMessage);

    let finalResponse = '';
    let iterations = 0;
    const MAX_ITERATIONS = 5;

    while (iterations < MAX_ITERATIONS) {
      iterations++;

      const result = await providerCall(messages, toolDefs.length > 0 ? toolDefs : undefined);

      if (!result || !result.content) {
        finalResponse = 'Erro ao processar resposta da IA.';
        break;
      }

      if (result.tool_calls && result.tool_calls.length > 0) {
        session.addAssistantMessage(JSON.stringify(result.tool_calls));

        for (const toolCall of result.tool_calls) {
          const toolName = toolCall.function.name;
          let params = {};
          try {
            params = typeof toolCall.function.arguments === 'string'
              ? JSON.parse(toolCall.function.arguments)
              : toolCall.function.arguments;
          } catch (e) {
            params = {};
          }

          const toolResult = await this.executeTool(toolName, params);
          session.addToolResult(toolName, toolResult);

          messages.push(
            { role: 'assistant', content: null, tool_calls: [{ id: toolCall.id, type: 'function', function: toolCall.function }] },
            { role: 'tool', tool_call_id: toolCall.id, content: JSON.stringify(toolResult) }
          );
        }
      } else {
        finalResponse = result.content;
        session.addAssistantMessage(finalResponse);
        break;
      }
    }

    if (!finalResponse) {
      finalResponse = 'Processamento concluído sem resposta final.';
    }

    return finalResponse;
  }

  clearSession(chatKey) {
    const session = this.sessions.get(chatKey);
    if (session) session.clear();
  }
}

module.exports = { AgentExecutor, agentDefinitions, AgentSession };
