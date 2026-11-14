// Servidor HTTP (Express) + WebSocket (/ws). Contrato: docs/protocol.md
import { createServer } from 'node:http';
import { fileURLToPath } from 'node:url';
import express from 'express';
import { WebSocketServer } from 'ws';
import { parse, send, sendError } from './protocol.js';
import {
  rooms, createRoom, addPlayer, selectRole, findByResumeToken, publicPlayers, closeRoom,
} from './rooms.js';

const HEARTBEAT_MS = 15_000;

/** Crea el servidor sin arrancarlo (los tests lo levantan en un puerto libre). */
export function createApp() {
  const app = express();
  app.get('/api/health', (_req, res) => res.json({ ok: true, rooms: rooms.size }));

  const server = createServer(app);
  const wss = new WebSocketServer({ server, path: '/ws' });

  // ---------- helpers de difusión ----------
  const lobbyState = (room) => ({
    type: 'lobby_state', code: room.code, status: room.status, players: publicPlayers(room),
  });

  function broadcastLobby(room) {
    const msg = lobbyState(room);
    send(room.hostConnection, msg);
    for (const p of room.players.values()) if (p.connected) send(p.connection, msg);
  }

  function closeRoomAndNotify(room, reason) {
    for (const p of room.players.values()) {
      send(p.connection, { type: 'room_closed', reason });
      p.connection = null;
      p.connected = false;
    }
    closeRoom(room.code);
  }

  // ---------- handlers por tipo (ctx = { kind: 'host'|'player'|null, room, player }) ----------
  const handlers = {
    create_room(ws, ctx) {
      if (ctx.room) return sendError(ws, 'already_registered', 'create_room');
      const room = createRoom(ws);
      Object.assign(ctx, { kind: 'host', room });
      send(ws, { type: 'room_created', code: room.code, hostToken: room.hostToken });
      send(ws, lobbyState(room));
    },

    join_room(ws, ctx, msg) {
      if (ctx.room) return sendError(ws, 'already_registered', 'join_room');
      const room = rooms.get(msg.code.toUpperCase());
      if (!room) return sendError(ws, 'room_not_found', 'join_room');
      const { player, error } = addPlayer(room, msg.name, ws);
      if (error) return sendError(ws, error, 'join_room');
      Object.assign(ctx, { kind: 'player', room, player });
      send(ws, { type: 'joined', code: room.code, playerId: player.id, resumeToken: player.resumeToken });
      broadcastLobby(room);
    },

    resume_player(ws, ctx, msg) {
      if (ctx.room) return sendError(ws, 'already_registered', 'resume_player');
      const room = rooms.get(msg.code.toUpperCase());
      if (!room) return sendError(ws, 'room_not_found', 'resume_player');
      const player = findByResumeToken(room, msg.resumeToken);
      if (!player) return sendError(ws, 'invalid_token', 'resume_player');
      const old = player.connection;
      player.connection = ws;
      player.connected = true;
      Object.assign(ctx, { kind: 'player', room, player });
      if (old && old !== ws) old.close(4000, 'replaced');
      send(ws, { type: 'joined', code: room.code, playerId: player.id, resumeToken: player.resumeToken });
      send(ws, lobbyState(room));
      if (player.lastView) send(ws, { type: 'controller_view', view: player.lastView });
      broadcastLobby(room);
    },

    select_role(ws, ctx, msg) {
      if (ctx.kind !== 'player') return sendError(ws, 'not_player', 'select_role');
      const { error } = selectRole(ctx.room, ctx.player, msg.role);
      if (error) return sendError(ws, error, 'select_role');
      broadcastLobby(ctx.room);
    },

    start_game(ws, ctx) {
      if (ctx.kind !== 'host') return sendError(ws, 'not_host', 'start_game');
      const { room } = ctx;
      if (room.status !== 'lobby') return sendError(ws, 'not_in_lobby', 'start_game');
      if (room.players.size === 0) return sendError(ws, 'no_players', 'start_game');
      if ([...room.players.values()].some((p) => !p.role)) return sendError(ws, 'players_without_role', 'start_game');
      room.status = 'playing';
      const msg = { type: 'game_started', players: publicPlayers(room) };
      send(room.hostConnection, msg);
      for (const p of room.players.values()) if (p.connected) send(p.connection, msg);
    },

    controller_view(ws, ctx, msg) {
      if (ctx.kind !== 'host') return sendError(ws, 'not_host', 'controller_view');
      const player = ctx.room.players.get(msg.playerId);
      if (!player) return sendError(ws, 'unknown_player', 'controller_view');
      player.lastView = msg.view;
      if (player.connected) send(player.connection, { type: 'controller_view', view: msg.view });
    },

    choose(ws, ctx, msg) {
      if (ctx.kind !== 'player') return sendError(ws, 'not_player', 'choose');
      const { room, player } = ctx;
      if (room.status !== 'playing') return sendError(ws, 'not_playing', 'choose');
      // La identidad sale de la conexión, nunca del mensaje.
      send(room.hostConnection, {
        type: 'choose', playerId: player.id, role: player.role,
        actionId: msg.actionId, eventId: msg.eventId, optionId: msg.optionId,
      });
    },

    choice_result(ws, ctx, msg) {
      if (ctx.kind !== 'host') return sendError(ws, 'not_host', 'choice_result');
      const player = ctx.room.players.get(msg.playerId);
      if (!player) return sendError(ws, 'unknown_player', 'choice_result');
    },

    finish_game(ws, ctx) {
      if (ctx.kind !== 'host') return sendError(ws, 'not_host', 'finish_game');
      ctx.room.status = 'finished';
      closeRoomAndNotify(ctx.room, 'game_finished');
    },
  };

  // ---------- conexiones ----------
  wss.on('connection', (ws) => {
    const ctx = { kind: null, room: null, player: null };
    ws.isAlive = true;
    ws.on('pong', () => { ws.isAlive = true; });

    ws.on('message', (raw) => {
      const { msg, error } = parse(raw.toString());
      if (error) return sendError(ws, error, undefined);
      handlers[msg.type](ws, ctx, msg);
    });

    ws.on('close', () => {
      const { kind, room, player } = ctx;
      if (kind === 'host' && rooms.has(room.code)) {
        closeRoomAndNotify(room, 'host_disconnected');
      } else if (kind === 'player' && player.connection === ws) {
        // Se conservan jugador y rol; solo se marca como desconectado.
        player.connection = null;
        player.connected = false;
        if (rooms.has(room.code)) broadcastLobby(room);
      }
    });

    ws.on('error', () => {});
  });

  // Heartbeat: detecta conexiones muertas (móviles que cambian de red o bloquean la pantalla).
  const heartbeat = setInterval(() => {
    for (const ws of wss.clients) {
      if (!ws.isAlive) { ws.terminate(); continue; }
      ws.isAlive = false;
      ws.ping();
    }
  }, HEARTBEAT_MS);
  wss.on('close', () => clearInterval(heartbeat));

  return { app, server, wss };
}

// Arranque directo: `node src/server.js`
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const port = Number(process.env.PORT) || 3000;
  createApp().server.listen(port, () => console.log(`[backend] escuchando en :${port}`));
}
