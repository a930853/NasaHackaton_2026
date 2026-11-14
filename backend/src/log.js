// Log de mensajes en bruto, para depurar el protocolo.
// Se activa con LOG_MESSAGES=1. Cada línea indica el sentido y con quién se habla:
//
//   ← host K7MP   {"type":"start_game"}          mensaje recibido
//   → K7MP/p1     {"type":"game_started",...}    mensaje enviado
//
// Ojo: muestra también los tokens. Solo para desarrollo.

const enabled = process.env.LOG_MESSAGES === '1';

/** Nombre legible de una conexión a partir de su contexto (ver server.js). */
function who(ws) {
  const ctx = ws.ctx;
  if (ctx?.kind === 'host') return `host ${ctx.room.code}`;
  if (ctx?.kind === 'player') return `${ctx.room.code}/${ctx.player.id}`;
  return 'sin registrar';
}

/**
 * @param {'in' | 'out'} direction  'in' = recibido, 'out' = enviado
 * @param {import('ws').WebSocket} ws
 * @param {string} text  el mensaje tal cual viaja (JSON)
 */
export function logMessage(direction, ws, text) {
  if (!enabled) return;
  const arrow = direction === 'in' ? '←' : '→';
  console.log(`${arrow} ${who(ws).padEnd(14)} ${text}`);
}
