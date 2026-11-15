// Entorno de desarrollo con un solo comando (`npm run dev`): backend, mando (Vite) y landing (Vite).
//
// Se entra por la landing (http://localhost:5173/): reenvía /controller al Vite del mando y /ws al
// backend, y sirve /game/ desde dist/game, así que todo sale del mismo origen, como en producción.
//
// - Busca puertos libres: en Windows, Hyper-V/WSL a veces reservan el 3000.
// - Activa el log de mensajes del backend (LOG_MESSAGES=1). Para quitarlo: LOG_MESSAGES=0.
// - Si uno de los dos procesos termina, cierra el otro.
import { spawn } from 'node:child_process'
import { existsSync } from 'node:fs'
import { createServer } from 'node:net'
import { createInterface } from 'node:readline'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')

// ---------- salida con prefijo de color por proceso ----------

const color = (code) => (text) => (process.stdout.isTTY ? `\x1b[${code}m${text}\x1b[0m` : text)
const tags = {
  dev: color('90')('[dev]       '),
  backend: color('36')('[backend]   '),
  controller: color('32')('[controller]'),
  landing: color('35')('[landing]   '),
}
const say = (tag, text) => console.log(`${tags[tag]} ${text}`)

// ---------- puertos ----------

/** Devuelve el primer puerto de la lista en el que se puede escuchar (0 = uno libre cualquiera). */
async function freePort(candidates) {
  for (const port of candidates) {
    const got = await new Promise((resolve) => {
      const server = createServer()
      server.once('error', () => resolve(null))
      server.listen(port, () => {
        const { port: real } = server.address()
        server.close(() => resolve(real))
      })
    })
    if (got) return got
  }
  throw new Error('No hay puertos libres')
}

// ---------- procesos hijos ----------

const children = []
let shuttingDown = false

/** Lanza `node <args>` y reenvía su salida con el prefijo `tag`. */
function run(tag, args, { cwd, env }) {
  const child = spawn(process.execPath, args, {
    cwd,
    env: { ...process.env, FORCE_COLOR: '1', ...env },
    stdio: ['ignore', 'pipe', 'pipe'],
  })
  for (const stream of [child.stdout, child.stderr]) {
    createInterface({ input: stream }).on('line', (line) => say(tag, line))
  }
  child.on('exit', (code) => {
    if (shuttingDown) return
    say('dev', `${tag} terminó (código ${code}). Cerrando todo.`)
    shutdown(code ?? 1)
  })
  children.push(child)
}

function shutdown(code = 0) {
  if (shuttingDown) return
  shuttingDown = true
  for (const child of children) child.kill()
  setTimeout(() => process.exit(code), 200)
}
process.on('SIGINT', () => shutdown(0))
process.on('SIGTERM', () => shutdown(0))

// ---------- arranque ----------

for (const dir of ['backend', 'controller', 'landing']) {
  if (!existsSync(join(root, dir, 'node_modules'))) {
    say('dev', `Faltan dependencias en ${dir}/. Ejecuta "npm install" en la raíz.`)
    process.exit(1)
  }
}

const preferred = Number(process.env.PORT) || 3000
const backendPort = await freePort([preferred, 8787, 0])
if (backendPort !== preferred) say('dev', `El puerto ${preferred} no está disponible; el backend usará el ${backendPort}.`)
const landingPort = await freePort([5173, 5175, 5177, 0])
const controllerPort = await freePort([5174, 5176, 5178, 0])

run('backend', ['--watch', 'src/server.js'], {
  cwd: join(root, 'backend'),
  env: { PORT: String(backendPort), LOG_MESSAGES: process.env.LOG_MESSAGES ?? '1' },
})

// Se llama a Vite con node directamente (sin npx) para que al cerrar no quede un proceso huérfano.
run('controller', [join(root, 'controller', 'node_modules', 'vite', 'bin', 'vite.js'), '--port', String(controllerPort), '--strictPort'], {
  cwd: join(root, 'controller'),
  env: { BACKEND_PORT: String(backendPort) },
})

run('landing', [join(root, 'landing', 'node_modules', 'vite', 'bin', 'vite.js'), '--port', String(landingPort), '--strictPort'], {
  cwd: join(root, 'landing'),
  env: { BACKEND_PORT: String(backendPort), CONTROLLER_PORT: String(controllerPort) },
})

say('dev', `Entrada:  http://localhost:${landingPort}/  (landing; /game/ sirve la última exportación de dist/game)`)
say('dev', `Mando:    http://localhost:${landingPort}/controller/  (desde el móvil, con la IP del PC)`)
say('dev', `Backend:  http://localhost:${backendPort}  (WebSocket en /ws a través de la entrada)`)
