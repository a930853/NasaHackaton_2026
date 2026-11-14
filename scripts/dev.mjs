// Entorno de desarrollo: backend + mando (Vite) + anfitrión simulado, con un solo comando.
//
//   npm run dev              todo, con el simulador de Godot en esta terminal
//   npm run dev -- --no-host sin simulador (cuando el anfitrión es el Godot real)
//
// Busca puertos libres: en Windows, Hyper-V/WSL a veces reservan el 3000.
import { spawn } from 'node:child_process'
import { existsSync } from 'node:fs'
import { createServer } from 'node:net'
import { createInterface } from 'node:readline'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import { startHost } from './host-sim.mjs'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const withHost = !process.argv.includes('--no-host')

const color = (code) => (text) => (process.stdout.isTTY ? `\x1b[${code}m${text}\x1b[0m` : text)
const tags = {
  dev: color('90')('[dev]       '),
  backend: color('36')('[backend]   '),
  controller: color('32')('[controller]'),
  host: color('35')('[host]      '),
}
const say = (tag, text) => String(text).split(/\r?\n/).forEach((line) => console.log(`${tags[tag]} ${line}`))

/** Devuelve el primer puerto en el que se puede escuchar (0 = uno libre cualquiera). */
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

const children = []

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
  return child
}

let shuttingDown = false
let host = null
function shutdown(code = 0) {
  if (shuttingDown) return
  shuttingDown = true
  host?.stop()
  for (const child of children) child.kill()
  setTimeout(() => process.exit(code), 200)
}
process.on('SIGINT', () => shutdown(0))
process.on('SIGTERM', () => shutdown(0))

async function waitForBackend(port, ms = 15000) {
  const t0 = Date.now()
  while (Date.now() - t0 < ms) {
    try {
      const res = await fetch(`http://localhost:${port}/api/health`)
      if (res.ok) return
    } catch {
      /* aún arrancando */
    }
    await new Promise((r) => setTimeout(r, 200))
  }
  throw new Error('El backend no responde en /api/health')
}

// ---------- arranque ----------

for (const dir of ['backend', 'controller']) {
  if (!existsSync(join(root, dir, 'node_modules'))) {
    say('dev', `Faltan dependencias en ${dir}/. Ejecuta "npm install" en la raíz.`)
    process.exit(1)
  }
}

const preferred = Number(process.env.PORT) || 3000
const backendPort = await freePort([preferred, 8787, 0])
if (backendPort !== preferred) say('dev', `El puerto ${preferred} no está disponible; el backend usará el ${backendPort}.`)
const controllerPort = await freePort([5173, 5174, 5175, 0])

run('backend', ['--watch', 'src/server.js'], { cwd: join(root, 'backend'), env: { PORT: String(backendPort) } })
run('controller', [join(root, 'controller', 'node_modules', 'vite', 'bin', 'vite.js'), '--port', String(controllerPort), '--strictPort'], {
  cwd: join(root, 'controller'),
  env: { BACKEND_PORT: String(backendPort) },
})

try {
  await waitForBackend(backendPort)
} catch (error) {
  say('dev', error.message)
  shutdown(1)
}

if (withHost && !shuttingDown) {
  host = startHost({ backendPort, controllerPort, log: (msg) => say('host', msg) })
  createInterface({ input: process.stdin }).on('line', (line) => host.command(line))
} else if (!shuttingDown) {
  say('dev', `Mando en http://localhost:${controllerPort}/controller/ · backend en :${backendPort}`)
}
