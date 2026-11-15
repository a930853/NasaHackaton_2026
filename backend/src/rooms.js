// Modelo en memoria: salas, jugadores, roles y credenciales.
import { randomBytes, randomInt } from 'node:crypto';
import { MAX_PLAYERS } from './protocol.js';

/**
 * @typedef {{ id: string, name: string, role: string|null, commander: boolean, resumeToken: string,
 *             connection: import('ws').WebSocket|null, connected: boolean, lastView: object|null }} Player
 * @typedef {{ code: string, status: 'lobby'|'playing'|'finished', hostConnection: import('ws').WebSocket,
 *             hostToken: string, players: Map<string, Player>, nextPlayer: number }} Room
 */

/** @type {Map<string, Room>} */
export const rooms = new Map();

const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sin 0/O ni 1/I
const token = () => randomBytes(24).toString('base64url');

function newCode() {
  let code;
  do {
    code = Array.from({ length: 4 }, () => CODE_CHARS[randomInt(CODE_CHARS.length)]).join('');
  } while (rooms.has(code));
  return code;
}

export function createRoom(hostConnection) {
  const room = {
    code: newCode(),
    status: 'lobby',
    hostConnection,
    hostToken: token(),
    players: new Map(),
    nextPlayer: 1,
  };
  rooms.set(room.code, room);
  return room;
}

/** Devuelve { player } o { error }. */
export function addPlayer(room, name, connection) {
  if (room.status !== 'lobby') return { error: 'game_already_started' };
  if (room.players.size >= MAX_PLAYERS) return { error: 'room_full' };
  const player = {
    id: `p${room.nextPlayer++}`,
    name: name.trim(),
    role: null,
    commander: room.players.size === 0,
    resumeToken: token(),
    connection,
    connected: true,
    lastView: null,
  };
  room.players.set(player.id, player);
  return { player };
}

/** Devuelve {} o { error }. */
export function selectRole(room, player, role) {
  if (room.status !== 'lobby') return { error: 'not_in_lobby' };
  for (const p of room.players.values()) {
    if (p !== player && p.role === role) return { error: 'role_taken' };
  }
  player.role = role;
  return {};
}

/** Saca a un jugador del lobby. Si era el Comandante, pasa a serlo el siguiente por orden de llegada. */
export function removePlayer(room, player) {
  if (room.status !== 'lobby') return { error: 'not_in_lobby' };
  room.players.delete(player.id);
  if (player.commander) {
    const next = room.players.values().next().value;
    if (next) next.commander = true;
  }
  return {};
}

export function findByResumeToken(room, resumeToken) {
  for (const p of room.players.values()) if (p.resumeToken === resumeToken) return p;
  return null;
}

/** Vista pública de los jugadores: nunca incluye tokens ni conexiones. */
export function publicPlayers(room) {
  return [...room.players.values()].map(({ id, name, role, commander, connected }) => ({
    id, name, role, commander, connected,
  }));
}

export function closeRoom(code) {
  rooms.delete(code);
}
