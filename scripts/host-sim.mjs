// Simulador del anfitrión (Godot) para probar el mando sin el juego.
// Crea una sala, muestra las URL para los móviles y responde a las decisiones
// siguiendo docs/protocol.md y docs/godot.md (idempotencia por actionId, rechazos…).
//
// Uso: desde `npm run dev` (raíz) o suelto: `node scripts/host-sim.mjs [puerto-backend] [puerto-mando]`
import { networkInterfaces } from 'node:os'
import { createInterface } from 'node:readline'
import { fileURLToPath } from 'node:url'

const EVENTS = [
  {
    id: 'solar-storm',
    title: 'Se aproxima una tormenta solar',
    prompt: '¿Qué propones?',
    options: [
      { id: 'shelter', label: 'Refugiar a la tripulación' },
      { id: 'continue', label: 'Continuar la actividad' },
    ],
    outcomes: {
      shelter: 'La tripulación está a salvo. Se pierde un día de trabajo: −10 energía.',
      continue: 'Se termina la tarea, pero la radiación afecta a la tripulación: −15 salud.',
    },
  },
  {
    id: 'oxygen-leak',
    title: 'Fuga de oxígeno en el módulo B',
    prompt: '¿Cómo actuamos?',
    options: [
      { id: 'seal', label: 'Sellar el módulo' },
      { id: 'repair', label: 'Reparar con una salida extravehicular' },
      { id: 'reroute', label: 'Desviar oxígeno de la reserva' },
    ],
    outcomes: {
      seal: 'Fuga contenida, pero perdemos el laboratorio del módulo B.',
      repair: 'Reparación completada tras una EVA arriesgada: −10 energía.',
      reroute: 'El oxígeno se estabiliza a costa de la reserva: −20 oxígeno de reserva.',
    },
  },
  {
    id: 'greenhouse',
    title: 'Cosecha en el invernadero',
    prompt: '¿Qué priorizamos?',
    options: [
      { id: 'food', label: 'Comida' },
      { id: 'oxygen', label: 'Producción de oxígeno' },
    ],
    outcomes: {
      food: 'Despensa llena para dos semanas: +20 comida.',
      oxygen: 'Las plantas generan más oxígeno: +10 oxígeno.',
    },
  },
]

const HELP = `Comandos del anfitrión simulado:
  start     iniciar la partida (todos los jugadores deben tener rol)
  ask       enviar un evento con opciones a todos los móviles
  resolve   resolver el evento actual con los votos recibidos
  wait      enviar una pantalla de espera a todos
  finish    terminar la partida (los móviles ven «sala cerrada»)
  new       cerrar la sala y crear otra nueva
  status    ver la sala y los jugadores
  help      esta ayuda`

// Adaptadores virtuales (WSL, VPN, máquinas virtuales…): los móviles no llegan por ellos.
const VIRTUAL = /vethernet|wsl|hyper-v|virtualbox|vbox|vmware|zerotier|tailscale|docker|loopback|virbr|veth|^br-/i

/** IPs de la LAN, la más probable primero (Wi-Fi/Ethernet reales antes que adaptadores virtuales). */
export function lanAddresses() {
  const rank = ({ name, address }) => {
    if (VIRTUAL.test(name)) return 3
    if (address.startsWith('192.168.56.')) return 2 // red host-only por defecto de VirtualBox
    return /wi-?fi|wlan|wireless/i.test(name) ? 0 : 1
  }
  return Object.entries(networkInterfaces())
    .flatMap(([name, list]) => (list ?? []).map((a) => ({ name, ...a })))
    .filter((a) => a.family === 'IPv4' && !a.internal && !a.address.startsWith('169.254.'))
    .sort((a, b) => rank(a) - rank(b))
    .map((a) => a.address)
}

/**
 * @param {{ backendPort: number, controllerPort: number, log?: (msg: string) => void }} options
 * @returns {{ command: (line: string) => void, stop: () => void }}
 */
export function startHost({ backendPort, controllerPort, log = console.log }) {
  let ws = null
  let stopped = false
  let code = ''
  let status = 'lobby'
  let players = []
  let eventSeq = 0
  let current = null // { id, tpl, decisions: Map<playerId, optionId>, closed }
  const results = new Map() // actionId -> { playerId, accepted, reason } (idempotencia)

  const send = (msg) => ws?.readyState === 1 && ws.send(JSON.stringify(msg))
  const withRole = () => players.filter((p) => p.role)
  const viewAll = (view) => players.forEach((p) => send({ type: 'controller_view', playerId: p.id, view }))
  const describe = (p) => `${p.name} (${p.role ?? 'sin rol'}${p.connected ? '' : ', desconectado'})`

  function printRoom() {
    const ips = lanAddresses()
    const base = (host) => `http://${host}:${controllerPort}/controller/`
    log(`Sala creada: ${code}`)
    log(`  Móvil (misma red): ${ips.length ? `${base(ips[0])}?room=${code}` : '(sin IP de LAN)'}`)
    log(`  Entrada por rol:   ${base(ips[0] ?? 'localhost')}engineer  (también biologist, doctor, generalist)`)
    log(`  En este PC:        ${base('localhost')}?room=${code}`)
    if (ips.length > 1) log(`  Otras IPs, si la primera no funciona: ${ips.slice(1).join(', ')}`)
    log('Escribe "help" para ver los comandos.')
  }

  function connect() {
    ws = new WebSocket(`ws://localhost:${backendPort}/ws`)
    ws.onopen = () => send({ type: 'create_room' })
    ws.onmessage = (event) => handle(JSON.parse(event.data))
    ws.onclose = () => {
      if (stopped) return
      log('Conexión con el backend perdida; reintentando…')
      setTimeout(connect, 1000)
    }
    ws.onerror = () => {}
  }

  function resetRoom() {
    status = 'lobby'
    players = []
    current = null
    results.clear()
  }

  function resolve() {
    if (!current || current.closed) return log('No hay ningún evento abierto.')
    current.closed = true
    const tally = new Map()
    for (const optionId of current.decisions.values()) tally.set(optionId, (tally.get(optionId) ?? 0) + 1)
    // Empate: el simulador elige la primera opción empatada (el juego real abriría una segunda votación).
    let winner = null
    for (const option of current.tpl.options) {
      if ((tally.get(option.id) ?? 0) > (tally.get(winner?.id) ?? 0)) winner = option
    }
    if (!winner) {
      log('Evento cerrado sin votos.')
      return viewAll({ screen: 'waiting', title: 'Evento cerrado sin decisión' })
    }
    const votes = [...tally].map(([id, n]) => `${id}=${n}`).join(', ')
    log(`Resuelto ${current.id}: gana "${winner.label}" (${votes})`)
    viewAll({ screen: 'result', title: winner.label, text: current.tpl.outcomes[winner.id] })
  }

  function onChoose(m) {
    const reply = (accepted, reason) => {
      results.set(m.actionId, { playerId: m.playerId, accepted, reason })
      send({ type: 'choice_result', playerId: m.playerId, actionId: m.actionId, accepted, ...(reason && { reason }) })
    }
    // 1. Duplicado: misma respuesta, sin repetir efectos.
    const previous = results.get(m.actionId)
    if (previous) {
      log(`choose duplicado ${m.actionId} → se repite la respuesta`)
      return send({ type: 'choice_result', playerId: m.playerId, actionId: m.actionId, accepted: previous.accepted, ...(previous.reason && { reason: previous.reason }) })
    }
    const who = players.find((p) => p.id === m.playerId)?.name ?? m.playerId
    if (!current || current.id !== m.eventId || current.closed) {
      log(`${who}: elección de un evento cerrado → event_closed`)
      return reply(false, 'event_closed')
    }
    if (!current.tpl.options.some((o) => o.id === m.optionId)) return reply(false, 'invalid_option')
    if (current.decisions.has(m.playerId)) return reply(false, 'already_decided')

    current.decisions.set(m.playerId, m.optionId)
    reply(true)
    log(`${who} elige "${m.optionId}" (${current.decisions.size}/${withRole().length})`)
    const pending = withRole().filter((p) => p.connected && !current.decisions.has(p.id))
    if (pending.length === 0) resolve()
  }

  function handle(m) {
    switch (m.type) {
      case 'room_created':
        code = m.code
        resetRoom()
        printRoom()
        break
      case 'lobby_state': {
        const before = JSON.stringify(players)
        players = m.players
        status = m.status
        if (before !== JSON.stringify(players)) {
          log(`Tripulación: ${players.length ? players.map(describe).join(', ') : '(nadie todavía)'}`)
        }
        break
      }
      case 'game_started':
        players = m.players
        status = 'playing'
        log('Partida iniciada. Escribe "ask" para enviar un evento.')
        viewAll({ screen: 'waiting', title: 'Preparando la misión', text: 'Mira la pantalla principal.' })
        break
      case 'choose':
        onChoose(m)
        break
      case 'error':
        log(`Error del backend: ${m.code}${m.requestType ? ` (${m.requestType})` : ''}`)
        break
    }
  }

  const commands = {
    help: () => log(HELP),
    status: () => log(`Sala ${code || '—'} · ${status} · ${players.map(describe).join(', ') || 'sin jugadores'}`),
    start: () => send({ type: 'start_game' }),
    ask() {
      if (status !== 'playing') return log('Primero "start".')
      const tpl = EVENTS[eventSeq % EVENTS.length]
      current = { id: `${tpl.id}#${++eventSeq}`, tpl, decisions: new Map(), closed: false }
      log(`Evento ${current.id}: ${tpl.title}`)
      viewAll({ screen: 'choice', eventId: current.id, title: tpl.title, prompt: tpl.prompt, options: tpl.options })
    },
    resolve,
    wait: () => viewAll({ screen: 'waiting', title: 'Esperando instrucciones del centro de control' }),
    finish() {
      send({ type: 'finish_game' })
      log('Partida terminada. Escribe "new" para crear otra sala.')
    },
    new() {
      log('Creando sala nueva…')
      ws.onclose = null
      ws.close()
      connect()
    },
  }

  connect()

  return {
    command(line) {
      const name = line.trim().toLowerCase()
      if (!name) return
      if (Object.hasOwn(commands, name)) commands[name]()
      else log(`Comando desconocido: "${name}". Escribe "help".`)
    },
    stop() {
      stopped = true
      ws?.close()
    },
  }
}

// Ejecución directa: node scripts/host-sim.mjs [puerto-backend] [puerto-mando]
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const backendPort = Number(process.argv[2]) || 3000
  const controllerPort = Number(process.argv[3]) || 5173
  const host = startHost({ backendPort, controllerPort })
  createInterface({ input: process.stdin }).on('line', host.command)
}
