// Tipos de mensaje y validación de entrada. Contrato: docs/protocol.md

export const ROLES = ['engineer', 'biologist', 'doctor', 'generalist'];
export const MAX_PLAYERS = 4;

const isStr = (v, max = 64) => typeof v === 'string' && v.length > 0 && v.length <= max;

// Cada validador devuelve null si el mensaje es válido o un código de error.
const validators = {
  create_room: () => null,
  start_game: () => null,
  finish_game: () => null,
  join_room(m) {
    if (!isStr(m.code, 8)) return 'invalid_code';
    return isStr(m.name?.trim?.(), 24) ? null : 'invalid_name';
  },
  select_role: (m) => (ROLES.includes(m.role) ? null : 'invalid_role'),
  resume_player: (m) => (isStr(m.code, 8) && isStr(m.resumeToken, 128) ? null : 'invalid_token'),
  choose: (m) => (isStr(m.actionId) && isStr(m.eventId) && isStr(m.optionId) ? null : 'invalid_choice'),
  controller_view: (m) => (isStr(m.playerId) && m.view && typeof m.view === 'object' ? null : 'invalid_view'),
  choice_result: (m) =>
    isStr(m.playerId) && isStr(m.actionId) && typeof m.accepted === 'boolean' ? null : 'invalid_result',
};

/** Parsea un mensaje crudo. Devuelve { msg } o { error }. */
export function parse(raw) {
  let msg;
  try {
    msg = JSON.parse(raw);
  } catch {
    return { error: 'invalid_json' };
  }
  if (typeof msg !== 'object' || !isStr(msg?.type)) return { error: 'missing_type' };
  const check = Object.hasOwn(validators, msg.type) ? validators[msg.type] : null;
  if (!check) return { error: 'unknown_type' };
  const problem = check(msg);
  return problem ? { error: problem } : { msg };
}

export const send = (ws, msg) => {
  if (ws?.readyState === 1) ws.send(JSON.stringify(msg));
};

export const sendError = (ws, code, requestType) =>
  send(ws, { type: 'error', code, message: code, requestType });
