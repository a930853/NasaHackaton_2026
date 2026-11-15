import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { WebSocket } from 'ws';
import { createApp } from '../src/server.js';

let server, wss, base, wsUrl;
const open = [];

before(async () => {
  ({ server, wss } = createApp());
  await new Promise((r) => server.listen(0, r));
  const { port } = server.address();
  base = `http://127.0.0.1:${port}`;
  wsUrl = `ws://127.0.0.1:${port}/ws`;
});

after(async () => {
  open.forEach((c) => c.ws.terminate());
  wss.close(); // también detiene el heartbeat
  server.closeAllConnections();
  await new Promise((r) => server.close(r));
});

/** Cliente de prueba con cola de mensajes. */
async function client() {
  const ws = new WebSocket(wsUrl);
  const queue = [];
  const waiters = [];
  ws.on('message', (raw) => {
    const msg = JSON.parse(raw.toString());
    const i = waiters.findIndex((w) => w.pred(msg));
    if (i >= 0) waiters.splice(i, 1)[0].resolve(msg);
    else queue.push(msg);
  });
  await new Promise((r) => ws.once('open', r));
  const c = {
    ws,
    send: (m) => ws.send(JSON.stringify(m)),
    next(type, ms = 1000) {
      const pred = (m) => m.type === type;
      const i = queue.findIndex(pred);
      if (i >= 0) return Promise.resolve(queue.splice(i, 1)[0]);
      return new Promise((resolve, reject) => {
        const w = { pred, resolve };
        waiters.push(w);
        setTimeout(() => reject(new Error(`timeout esperando ${type}`)), ms).unref();
      });
    },
    /** Comprueba que NO llega un mensaje de ese tipo. */
    async none(type, ms = 150) {
      await new Promise((r) => setTimeout(r, ms));
      assert.equal(queue.find((m) => m.type === type), undefined, `llegó ${type} inesperado`);
    },
  };
  open.push(c);
  return c;
}

async function host() {
  const h = await client();
  h.send({ type: 'create_room' });
  const { code } = await h.next('room_created');
  return { h, code };
}

async function player(code, name, role) {
  const p = await client();
  p.send({ type: 'join_room', code, name });
  const joined = await p.next('joined');
  if (role) {
    p.send({ type: 'select_role', role });
    await p.next('lobby_state');
  }
  return { p, joined };
}

test('GET /api/health responde ok', async () => {
  const res = await fetch(`${base}/api/health`);
  assert.equal(res.status, 200);
  assert.equal((await res.json()).ok, true);
});

test('crear sala devuelve código de 4 caracteres y hostToken', async () => {
  const h = await client();
  h.send({ type: 'create_room' });
  const msg = await h.next('room_created');
  assert.match(msg.code, /^[A-Z2-9]{4}$/);
  assert.ok(msg.hostToken.length > 20);
});

test('no entran cinco jugadores', async () => {
  const { code } = await host();
  for (let i = 1; i <= 4; i++) await player(code, `J${i}`);
  const fifth = await client();
  fifth.send({ type: 'join_room', code, name: 'J5' });
  assert.equal((await fifth.next('error')).code, 'room_full');
});

test('el primer jugador recibe la capacidad de Comandante y puede elegir rol', async () => {
  const { code } = await host();
  const first = await player(code, 'Ana');
  const initialLobby = await first.p.next('lobby_state');
  const mine = initialLobby.players.find((p) => p.id === first.joined.playerId);
  assert.equal(mine.role, null);
  assert.equal(mine.commander, true);

  first.p.send({ type: 'select_role', role: 'engineer' });
  const lobby = await first.p.next('lobby_state');
  assert.equal(lobby.players.find((p) => p.id === first.joined.playerId).role, 'engineer');
});

test('el primer jugador conserva su comandante al elegir un rol principal', async () => {
  const { code } = await host();
  const first = await player(code, 'Ana');
  await first.p.next('lobby_state'); // lobby inicial, todavía sin rol
  first.p.send({ type: 'select_role', role: 'engineer' });
  const lobby = await first.p.next('lobby_state');
  const mine = lobby.players.find((p) => p.id === first.joined.playerId);
  assert.equal(mine.role, 'engineer');
  assert.equal(mine.commander, true);
});

test('salir del lobby libera el rol, invalida el token y avisa al resto', async () => {
  const { h, code } = await host();
  const ana = await player(code, 'Ana', 'engineer');
  const luis = await player(code, 'Luis', 'doctor');
  ana.p.send({ type: 'leave_room' });
  await ana.p.next('left_room');
  // En la cola hay lobby_state anteriores: se espera al que ya no tiene a Ana.
  let lobby;
  do lobby = await luis.p.next('lobby_state'); while (lobby.players.length !== 1);
  assert.deepEqual(lobby.players.map((p) => p.name), ['Luis']);
  assert.equal(lobby.players[0].commander, true); // el Comandante pasa al siguiente

  // El rol queda libre y el token ya no vale.
  luis.p.send({ type: 'select_role', role: 'engineer' });
  let hostView;
  do hostView = await h.next('lobby_state'); while (hostView.players[0]?.role !== 'engineer');
  assert.equal(hostView.players.length, 1);
  const again = await client();
  again.send({ type: 'resume_player', code, resumeToken: ana.joined.resumeToken });
  assert.equal((await again.next('error')).code, 'invalid_token');
});

test('tras salir, la misma conexión puede entrar en otra sala', async () => {
  const first = await host();
  const second = await host();
  const ana = await player(first.code, 'Ana');
  ana.p.send({ type: 'leave_room' });
  await ana.p.next('left_room');
  ana.p.send({ type: 'join_room', code: second.code, name: 'Ana' });
  assert.equal((await ana.p.next('joined')).code, second.code);
});

test('con la partida empezada no se puede salir de la sala', async () => {
  const { h, code } = await host();
  const ana = await player(code, 'Ana', 'engineer');
  h.send({ type: 'start_game' });
  await ana.p.next('game_started');
  ana.p.send({ type: 'leave_room' });
  assert.equal((await ana.p.next('error')).code, 'not_in_lobby');
});

test('no se reserva el mismo rol dos veces', async () => {
  const { code } = await host();
  await player(code, 'Ana', 'engineer');
  const { p } = await player(code, 'Luis');
  p.send({ type: 'select_role', role: 'engineer' });
  assert.equal((await p.next('error')).code, 'role_taken');
});

test('dos salas reciben solo sus propias decisiones', async () => {
  const a = await host();
  const b = await host();
  const pa = await player(a.code, 'A', 'engineer');
  await player(b.code, 'B', 'doctor');
  a.h.send({ type: 'start_game' });
  b.h.send({ type: 'start_game' });
  await a.h.next('game_started');
  await b.h.next('game_started');

  pa.p.send({ type: 'choose', actionId: 'x1', eventId: 'e1', optionId: 'o1' });
  const got = await a.h.next('choose');
  assert.equal(got.playerId, pa.joined.playerId);
  assert.equal(got.role, 'engineer');
  await b.h.none('choose');
});

test('el mando puede pedir continuar y Node añade su identidad', async () => {
  const { h, code } = await host();
  const p = await player(code, 'Ana', 'engineer');
  h.send({ type: 'start_game' });
  await h.next('game_started');

  p.p.send({ type: 'continue', actionId: 'p1-continue-1' });
  const got = await h.next('continue');
  assert.deepEqual(
    { playerId: got.playerId, role: got.role, actionId: got.actionId },
    { playerId: p.joined.playerId, role: 'engineer', actionId: 'p1-continue-1' },
  );
});

test('un móvil no puede suplantar a otro con playerId', async () => {
  const { h, code } = await host();
  const p1 = await player(code, 'A', 'engineer');
  const p2 = await player(code, 'B', 'doctor');
  h.send({ type: 'start_game' });
  await h.next('game_started');
  p2.p.send({ type: 'choose', playerId: p1.joined.playerId, actionId: 'x', eventId: 'e', optionId: 'o' });
  const got = await h.next('choose');
  assert.equal(got.playerId, p2.joined.playerId);
});

test('el flujo host → móvil: controller_view sin reenviar choice_result', async () => {
  const { h, code } = await host();
  const { p, joined } = await player(code, 'A', 'engineer');
  h.send({ type: 'start_game' });
  await p.next('game_started');
  h.send({ type: 'controller_view', playerId: joined.playerId, view: { screen: 'choice', eventId: 'e1', options: [] } });
  assert.equal((await p.next('controller_view')).view.eventId, 'e1');
  h.send({ type: 'choice_result', playerId: joined.playerId, actionId: 'a1', accepted: true });
  await p.none('choice_result');
});

test('un móvil no puede iniciar la partida ni enviar vistas', async () => {
  const { code } = await host();
  const { p } = await player(code, 'A', 'engineer');
  p.send({ type: 'start_game' });
  assert.equal((await p.next('error')).code, 'not_host');
});

test('start_game exige que todos tengan rol', async () => {
  const { h, code } = await host();
  await player(code, 'A');
  h.send({ type: 'start_game' });
  assert.equal((await h.next('error')).code, 'players_without_role');
});

test('un móvil reconecta con resumeToken y recupera rol y última vista', async () => {
  const { h, code } = await host();
  const { p, joined } = await player(code, 'A', 'biologist');
  h.send({ type: 'start_game' });
  await p.next('game_started');
  h.send({ type: 'controller_view', playerId: joined.playerId, view: { screen: 'choice', eventId: 'e7' } });
  await p.next('controller_view');

  p.ws.terminate();
  const lobby = await h.next('lobby_state'); // consume el estado previo
  assert.ok(lobby);
  let st;
  do { st = await h.next('lobby_state'); } while (st.players[0].connected);
  assert.equal(st.players[0].role, 'biologist'); // rol reservado

  const p2 = await client();
  p2.send({ type: 'resume_player', code, resumeToken: joined.resumeToken });
  assert.equal((await p2.next('joined')).playerId, joined.playerId);
  assert.equal((await p2.next('lobby_state')).players[0].role, 'biologist');
  assert.equal((await p2.next('controller_view')).view.eventId, 'e7');
});

test('resume_player con token inválido se rechaza', async () => {
  const { code } = await host();
  const c = await client();
  c.send({ type: 'resume_player', code, resumeToken: 'nope' });
  assert.equal((await c.next('error')).code, 'invalid_token');
});

test('el cierre del anfitrión se comunica a los mandos', async () => {
  const { h, code } = await host();
  const { p } = await player(code, 'A', 'doctor');
  h.ws.close();
  const msg = await p.next('room_closed');
  assert.equal(msg.reason, 'host_disconnected');
  const late = await client();
  late.send({ type: 'join_room', code, name: 'Tarde' });
  assert.equal((await late.next('error')).code, 'room_not_found');
});

test('mensajes inválidos devuelven error sin tirar la conexión', async () => {
  const c = await client();
  c.ws.send('no es json');
  assert.equal((await c.next('error')).code, 'invalid_json');
  c.send({ type: 'inventado' });
  assert.equal((await c.next('error')).code, 'unknown_type');
  c.send({ type: 'create_room' });
  assert.ok(await c.next('room_created'));
});
