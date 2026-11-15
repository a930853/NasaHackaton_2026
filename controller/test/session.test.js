// Pruebas del store de sesión contra el backend real (backend/src/server.js).
// Godot se simula con un WebSocket que actúa de anfitrión.
import { test, before, after } from 'node:test'
import assert from 'node:assert/strict'
import { createApp } from '../../backend/src/server.js'
import { createSession, memoryStorage } from '../src/stores/session.js'

let server, wss, url
const cleanup = []

before(async () => {
  ;({ server, wss } = createApp())
  await new Promise((r) => server.listen(0, r))
  url = `ws://127.0.0.1:${server.address().port}/ws`
})

after(async () => {
  cleanup.forEach((fn) => fn())
  wss.close()
  server.closeAllConnections()
  await new Promise((r) => server.close(r))
})

/** Espera a que se cumpla una condición sobre el estado reactivo. */
async function until(check, label = 'condición', ms = 2000) {
  const t0 = Date.now()
  while (!check()) {
    if (Date.now() - t0 > ms) throw new Error(`timeout esperando ${label}`)
    await new Promise((r) => setTimeout(r, 10))
  }
}

/** Anfitrión (Godot) mínimo con cola de mensajes. */
async function host() {
  const ws = new WebSocket(url)
  const inbox = []
  ws.onmessage = (e) => inbox.push(JSON.parse(e.data))
  await new Promise((r) => (ws.onopen = r))
  cleanup.push(() => ws.close())
  const h = {
    send: (m) => ws.send(JSON.stringify(m)),
    async next(type) {
      let i
      await until(() => (i = inbox.findIndex((m) => m.type === type)) >= 0, type)
      return inbox.splice(i, 1)[0]
    },
    close: () => ws.close(),
  }
  h.send({ type: 'create_room' })
  h.code = (await h.next('room_created')).code
  return h
}

function mando(storage = memoryStorage()) {
  const s = createSession({ url, storage, minDelay: 20, maxDelay: 50 })
  cleanup.push(() => s.destroy())
  return s
}

async function joinedPlayer(h, name, role, storage) {
  const s = mando(storage)
  s.start()
  await until(() => s.state.phase === 'enter', 'pantalla de entrada')
  s.join(h.code.toLowerCase(), `  ${name} `)
  await until(() => s.state.phase === 'lobby', 'lobby')
  if (role) {
    s.selectRole(role)
    await until(() => s.state.role === role, `rol ${role}`)
  }
  return s
}

const choiceView = (eventId) => ({
  screen: 'choice', eventId, title: 'Tormenta solar', prompt: '¿Qué hacemos?',
  options: [{ id: 'shelter', label: 'Refugio' }, { id: 'continue', label: 'Continuar' }],
})

const resultView = { screen: 'result', canContinue: true, title: 'It worked!', text: 'Todos a salvo.' }

test('entrar, elegir rol, recibir opciones y pasar a la vista de resultado', async () => {
  const h = await host()
  const s = await joinedPlayer(h, 'Ana', 'engineer')
  assert.equal(s.state.code, h.code)
  assert.equal(s.state.name, 'Ana')

  h.send({ type: 'start_game' })
  await until(() => s.state.phase === 'playing', 'playing')

  h.send({ type: 'controller_view', playerId: s.state.playerId, view: choiceView('storm#1') })
  await until(() => s.state.view?.eventId === 'storm#1', 'vista')

  s.choose('shelter')
  assert.equal(s.state.choice.status, 'sending')
  s.choose('continue') // doble pulsación: se ignora mientras se envía
  const got = await h.next('choose')
  assert.deepEqual([got.playerId, got.role, got.optionId], [s.state.playerId, 'engineer', 'shelter'])

  // Node no reenvía choice_result: el mando avanza con la siguiente controller_view.
  h.send({ type: 'choice_result', playerId: got.playerId, actionId: got.actionId, accepted: true })
  h.send({ type: 'controller_view', playerId: got.playerId, view: resultView })
  await until(() => s.state.view?.screen === 'result', 'resultado')
  assert.equal(s.state.choice.status, 'idle')
})

test('una pregunta nueva de Godot deja volver a elegir', async () => {
  const h = await host()
  const s = await joinedPlayer(h, 'Luis', 'doctor')
  h.send({ type: 'start_game' })
  h.send({ type: 'controller_view', playerId: s.state.playerId, view: choiceView('e1') })
  await until(() => s.state.view?.eventId === 'e1', 'vista')

  s.choose('continue')
  const got = await h.next('choose')
  h.send({ type: 'choice_result', playerId: got.playerId, actionId: got.actionId, accepted: false, reason: 'event_closed' })
  h.send({ type: 'controller_view', playerId: got.playerId, view: choiceView('e2') })
  await until(() => s.state.view?.eventId === 'e2', 'vista nueva')
  assert.equal(s.state.choice.status, 'idle')

  s.choose('shelter')
  const again = await h.next('choose')
  assert.equal(again.eventId, 'e2')
  assert.notEqual(again.actionId, got.actionId) // pulsación nueva → actionId nuevo
})

test('al recargar con una elección sin confirmar, se reenvía el mismo actionId', async () => {
  const h = await host()
  const storage = memoryStorage()
  const s1 = await joinedPlayer(h, 'Eva', 'biologist', storage)
  h.send({ type: 'start_game' })
  h.send({ type: 'controller_view', playerId: s1.state.playerId, view: choiceView('e7') })
  await until(() => s1.state.view?.eventId === 'e7', 'vista')

  s1.choose('shelter')
  const first = await h.next('choose')
  s1.destroy() // el móvil se recarga antes de recibir la confirmación

  const s2 = mando(storage)
  s2.start()
  await until(() => s2.state.phase === 'playing', 'sesión recuperada')
  assert.equal(s2.state.role, 'biologist')
  const resent = await h.next('choose')
  assert.equal(resent.actionId, first.actionId)
  assert.equal(s2.state.choice.status, 'sending')
})

test('la última vista se restaura tras recargar', async () => {
  const h = await host()
  const storage = memoryStorage()
  const s1 = await joinedPlayer(h, 'Leo', 'generalist', storage)
  h.send({ type: 'start_game' })
  h.send({ type: 'controller_view', playerId: s1.state.playerId, view: choiceView('e9') })
  await until(() => s1.state.view?.eventId === 'e9', 'vista')
  s1.choose('continue')
  const got = await h.next('choose')
  h.send({ type: 'choice_result', playerId: got.playerId, actionId: got.actionId, accepted: true })
  h.send({ type: 'controller_view', playerId: got.playerId, view: resultView })
  await until(() => s1.state.view?.screen === 'result', 'resultado')
  s1.destroy()

  const s2 = mando(storage)
  s2.start()
  await until(() => s2.state.view?.screen === 'result', 'vista restaurada')
  assert.equal(s2.state.view.text, resultView.text)
  assert.equal(s2.state.choice.status, 'idle') // no se reenvía ninguna elección
})

test('salir de la sala en el lobby vuelve a la entrada y olvida las credenciales', async () => {
  const h = await host()
  const storage = memoryStorage()
  const s = await joinedPlayer(h, 'Ana', 'engineer', storage)
  s.leaveRoom()
  await until(() => s.state.phase === 'enter', 'vuelta a la entrada')
  assert.equal(storage.getItem('nasa.controller.session'), null)
  assert.equal(s.state.role, null)
  assert.equal(s.state.prefillCode, h.code) // el código sigue puesto por si quiere volver
  const lobby = await h.next('lobby_state')
  assert.ok(lobby)
})

test('rol ocupado: el error llega al store y el rol no cambia', async () => {
  const h = await host()
  await joinedPlayer(h, 'Ana', 'engineer')
  const s = await joinedPlayer(h, 'Luis')
  s.selectRole('engineer')
  await until(() => s.state.error?.code === 'role_taken', 'role_taken')
  assert.equal(s.state.role, null)
})

test('sala inexistente: se queda en la pantalla de entrada con error', async () => {
  const s = mando()
  s.start()
  await until(() => s.state.phase === 'enter', 'enter')
  s.join('ZZZZ', 'Ana')
  await until(() => s.state.error?.code === 'room_not_found', 'room_not_found')
  assert.equal(s.state.phase, 'enter')
})

test('un código distinto en la URL descarta la sesión guardada', async () => {
  const h = await host()
  const storage = memoryStorage()
  ;(await joinedPlayer(h, 'Ana', 'engineer', storage)).destroy()

  const s = mando(storage)
  s.start({ room: 'OTRA' })
  await until(() => s.state.phase === 'enter', 'enter')
  assert.equal(s.state.prefillCode, 'OTRA')
})

test('si el anfitrión se va, la sala se cierra y se olvidan las credenciales', async () => {
  const h = await host()
  const storage = memoryStorage()
  const s = await joinedPlayer(h, 'Ana', 'engineer', storage)
  h.close()
  await until(() => s.state.phase === 'closed', 'closed')
  assert.equal(s.state.closedReason, 'host_disconnected')
  assert.equal(storage.getItem('nasa.controller.session'), null)

  s.restart()
  await until(() => s.state.phase === 'enter', 'vuelta a la entrada')
})

test('se reconecta solo tras perder la conexión y recupera la sesión', async () => {
  const h = await host()
  const s = await joinedPlayer(h, 'Ana', 'engineer')
  const before = s.state.playerId
  // Corte de red: el servidor corta la conexión más reciente, que es la de este jugador.
  const conns = [...wss.clients]
  conns[conns.length - 1].terminate()
  await until(() => s.state.connection === 'offline', 'offline')
  await until(() => s.state.connection === 'online' && s.state.role === 'engineer', 'reconexión')
  assert.equal(s.state.playerId, before)
})
