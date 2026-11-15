// Estado de la sesión del mando y su sincronización con el backend. Contrato: docs/protocol.md
//
// Las pantallas solo leen `state` y llaman a las acciones; nunca tocan el WebSocket.
import { reactive } from 'vue'
import { createSocket } from '../net/socket.js'

const SESSION_KEY = 'nasa.controller.session' // { code, resumeToken, playerId, pending, decided }
const NAME_KEY = 'nasa.controller.name'

export const normalizeCode = (value) => String(value ?? '').trim().toUpperCase().slice(0, 8)

export function memoryStorage() {
  const data = new Map()
  return {
    getItem: (k) => (data.has(k) ? data.get(k) : null),
    setItem: (k, v) => data.set(k, String(v)),
    removeItem: (k) => data.delete(k),
  }
}

/** localStorage si está disponible (puede fallar en modo privado); si no, memoria. */
export function browserStorage() {
  try {
    const s = globalThis.localStorage
    s.setItem('__probe', '1')
    s.removeItem('__probe')
    return s
  } catch {
    return memoryStorage()
  }
}

// crypto.randomUUID no existe fuera de contextos seguros (http en la LAN); getRandomValues sí.
function randomId() {
  const bytes = new Uint8Array(8)
  globalThis.crypto.getRandomValues(bytes)
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('')
}

const idleChoice = () => ({ status: 'idle', eventId: null, optionId: null, reason: null })

/**
 * @param {{ url: string, storage?: Storage, WebSocketImpl?: typeof WebSocket, minDelay?: number, maxDelay?: number }} options
 */
export function createSession({ url, storage = browserStorage(), WebSocketImpl, minDelay, maxDelay } = {}) {
  const read = (key) => {
    try {
      return JSON.parse(storage.getItem(key))
    } catch {
      return null
    }
  }
  const write = (key, value) => {
    try {
      if (value == null) storage.removeItem(key)
      else storage.setItem(key, JSON.stringify(value))
    } catch {
      /* almacenamiento no disponible: la sesión sigue en memoria */
    }
  }

  /** Lo que sobrevive a una recarga: credenciales, elección pendiente y última decisión aceptada. */
  let saved = read(SESSION_KEY)
  const persist = () => write(SESSION_KEY, saved)
  let errorSeq = 0

  const state = reactive({
    /** connecting | online | offline | replaced */
    connection: 'connecting',
    /** connecting | enter | joining | lobby | playing | closed */
    phase: 'connecting',
    prefillCode: '',
    name: read(NAME_KEY) ?? '',
    code: '',
    playerId: '',
    role: null,
    commander: false,
    players: [],
    roomStatus: null,
    /** Última controller_view recibida */
    view: null,
    /** Estado de la pulsación: idle | sending | registered | rejected */
    choice: idleChoice(),
    /** Último error: { code, requestType, seq }. `seq` cambia en cada error para poder observarlo. */
    error: null,
    closedReason: null,
  })

  const socket = createSocket({ url, WebSocketImpl, minDelay, maxDelay, onOpen, onMessage, onClose })

  // ---------- helpers ----------

  function setError(code, requestType = null) {
    state.error = { code, requestType, seq: ++errorSeq }
  }

  function applyPlayers(players) {
    state.players = players
    const mine = players.find((p) => p.id === state.playerId)
    state.role = mine?.role ?? null
    state.commander = mine?.commander === true
  }

  function sendChoose(pending) {
    socket.send({ type: 'choose', actionId: pending.actionId, eventId: pending.eventId, optionId: pending.optionId })
  }

  /** Olvida la sala (credenciales incluidas). El nombre se conserva para la próxima vez. */
  function forget() {
    saved = null
    write(SESSION_KEY, null)
    Object.assign(state, {
      code: '', playerId: '', role: null, commander: false, players: [], roomStatus: null, view: null, choice: idleChoice(),
    })
  }

  function setView(view) {
    state.view = view
    const pending = saved?.pending
    if (view?.screen === 'choice') {
      // Había una elección sin confirmar para este evento: se reenvía con el MISMO actionId.
      if (pending && pending.eventId === view.eventId) {
        state.choice = { status: 'sending', eventId: pending.eventId, optionId: pending.optionId, reason: null }
        sendChoose(pending)
        return
      }
      if (pending && pending.eventId !== view.eventId) {
        saved.pending = null
        persist()
      }
      const decided = saved?.decided
      if (decided && decided.eventId === view.eventId) {
        state.choice = { status: 'registered', ...decided, reason: null }
        return
      }
      if (state.choice.eventId !== view.eventId) state.choice = idleChoice()
      return
    }
    // Otra pantalla: una elección pendiente de un evento anterior ya no tiene sentido.
    if (pending) {
      saved.pending = null
      persist()
    }
    state.choice = idleChoice()
  }

  // ---------- eventos del socket ----------

  function onOpen() {
    state.connection = 'online'
    if (saved?.code && saved?.resumeToken) {
      if (state.phase === 'connecting' || state.phase === 'enter') state.phase = 'joining'
      socket.send({ type: 'resume_player', code: saved.code, resumeToken: saved.resumeToken })
    } else if (state.phase === 'connecting' || state.phase === 'joining') {
      state.phase = 'enter'
    }
  }

  function onClose({ replaced }) {
    state.connection = replaced ? 'replaced' : 'offline'
  }

  const handlers = {
    joined(m) {
      state.code = m.code
      state.playerId = m.playerId
      const keep = saved?.code === m.code ? saved : {}
      saved = { ...keep, code: m.code, resumeToken: m.resumeToken, playerId: m.playerId }
      persist()
      if (state.phase === 'joining' || state.phase === 'enter') state.phase = 'lobby'
    },
    lobby_state(m) {
      applyPlayers(m.players)
      state.roomStatus = m.status
      if (state.phase !== 'closed') state.phase = m.status === 'lobby' ? 'lobby' : 'playing'
    },
    game_started(m) {
      applyPlayers(m.players)
      state.roomStatus = 'playing'
      state.phase = 'playing'
      state.view = null
    },
    controller_view(m) {
      setView(m.view)
    },
    choice_result(m) {
      const pending = saved?.pending
      if (!pending || pending.actionId !== m.actionId) return // respuesta a algo que ya no esperamos
      saved.pending = null
      if (m.accepted) {
        saved.decided = { eventId: pending.eventId, optionId: pending.optionId }
        state.choice = { status: 'registered', eventId: pending.eventId, optionId: pending.optionId, reason: null }
      } else {
        state.choice = {
          status: 'rejected', eventId: pending.eventId, optionId: pending.optionId, reason: m.reason || 'rejected',
        }
      }
      persist()
    },
    room_closed(m) {
      forget()
      state.phase = 'closed'
      state.closedReason = m.reason ?? null
    },
    error(m) {
      setError(m.code, m.requestType ?? null)
      if (m.requestType === 'resume_player') {
        forget()
        state.phase = 'enter'
      } else if (m.requestType === 'join_room') {
        state.phase = 'enter'
      } else if (m.requestType === 'choose' && saved?.pending) {
        const { eventId, optionId } = saved.pending
        saved.pending = null
        persist()
        state.choice = { status: 'rejected', eventId, optionId, reason: m.code }
      }
    },
  }

  function onMessage(msg) {
    if (Object.hasOwn(handlers, msg.type)) handlers[msg.type](msg)
  }

  // ---------- acciones ----------

  return {
    state,

    /** Arranca la conexión. Si llega un código por URL distinto del guardado, se descarta la sesión guardada. */
    start({ room } = {}) {
      const code = normalizeCode(room)
      if (code) {
        state.prefillCode = code
        if (saved?.code && saved.code !== code) forget()
      }
      socket.connect()
    },

    join(code, name) {
      const cleanCode = normalizeCode(code)
      const cleanName = String(name ?? '').trim()
      state.name = cleanName
      state.prefillCode = cleanCode
      write(NAME_KEY, cleanName)
      if (!socket.send({ type: 'join_room', code: cleanCode, name: cleanName })) return setError('offline', 'join_room')
      state.phase = 'joining'
    },

    selectRole(role) {
      if (!socket.send({ type: 'select_role', role })) setError('offline', 'select_role')
    },

    choose(optionId) {
      const view = state.view
      if (view?.screen !== 'choice') return
      if (state.choice.status === 'sending' || state.choice.status === 'registered') return
      const pending = { actionId: `${state.playerId}-${randomId()}`, eventId: view.eventId, optionId }
      saved = { ...saved, pending }
      persist()
      state.choice = { status: 'sending', eventId: view.eventId, optionId, reason: null }
      sendChoose(pending) // si no hay conexión, se reenviará al recuperar la sesión
    },

    /** Tras cerrarse la sala: conexión nueva y vuelta a la pantalla de entrada. */
    restart() {
      forget()
      state.phase = 'connecting'
      state.closedReason = null
      state.error = null
      socket.reconnect()
    },

    /** Recupera la sesión en este dispositivo cuando otro la había tomado. */
    takeOver() {
      state.connection = 'connecting'
      socket.reconnect()
    },

    /** Cierra la conexión sin olvidar la sesión (útil en tests). */
    destroy() {
      socket.close()
    },
  }
}
