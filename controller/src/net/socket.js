// Único punto de contacto con el WebSocket del backend. Contrato: docs/es/protocol.md

/** URL del WebSocket a partir del servidor que sirvió la página (sin IPs fijas). */
export function wsUrl(loc = globalThis.location) {
  const proto = loc.protocol === 'https:' ? 'wss' : 'ws'
  return `${proto}://${loc.host}/ws`
}

/** Código de cierre con el que Node sustituye una conexión por otra más reciente del mismo jugador. */
export const CLOSE_REPLACED = 4000

/**
 * Socket con reconexión automática (backoff exponencial).
 * Solo reconecta si el cierre no fue intencionado ni por sustitución (otro dispositivo tomó la sesión).
 */
export function createSocket({
  url,
  onOpen,
  onMessage,
  onClose,
  WebSocketImpl = globalThis.WebSocket,
  minDelay = 500,
  maxDelay = 5000,
}) {
  let ws = null
  let delay = minDelay
  let stopped = true
  let timer = null

  function detach() {
    if (!ws) return
    ws.onopen = ws.onmessage = ws.onclose = ws.onerror = null
    ws.close()
    ws = null
  }

  function open() {
    clearTimeout(timer)
    ws = new WebSocketImpl(url)
    ws.onopen = () => {
      delay = minDelay
      onOpen?.()
    }
    ws.onmessage = (event) => {
      let msg
      try {
        msg = JSON.parse(event.data)
      } catch {
        return
      }
      if (msg && typeof msg.type === 'string') onMessage?.(msg)
    }
    ws.onclose = (event) => {
      ws = null
      const replaced = event.code === CLOSE_REPLACED
      onClose?.({ code: event.code, replaced })
      if (!stopped && !replaced) {
        timer = setTimeout(open, delay)
        delay = Math.min(delay * 2, maxDelay)
      }
    }
    ws.onerror = () => {} // el cierre posterior gestiona la reconexión
  }

  return {
    connect() {
      stopped = false
      if (!ws) open()
    },
    /** Cierra la conexión actual (sin avisar) y abre una nueva desde cero. */
    reconnect() {
      stopped = false
      detach()
      delay = minDelay
      open()
    },
    close() {
      stopped = true
      clearTimeout(timer)
      detach()
    },
    /** Devuelve false si no hay conexión abierta (el mensaje no se envía). */
    send(msg) {
      if (ws?.readyState !== 1) return false
      ws.send(JSON.stringify(msg))
      return true
    },
  }
}
