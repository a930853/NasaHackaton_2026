import { createReadStream, existsSync, statSync } from 'node:fs'
import { extname, join, normalize, resolve } from 'node:path'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

// Puertos en desarrollo (los fija scripts/dev.mjs). En producción todo lo sirve Nginx.
const backendPort = process.env.BACKEND_PORT || 3000
const controllerPort = process.env.CONTROLLER_PORT || 5174

const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.ico': 'image/x-icon',
  '.woff2': 'font/woff2', '.mp3': 'audio/mpeg', '.wasm': 'application/wasm', '.pck': 'application/octet-stream',
}

/** Solo en desarrollo: /game/ sirve la última exportación web de Godot (dist/game), como Nginx. */
function gameExport() {
  const dir = resolve(__dirname, '../dist/game')
  return {
    name: 'game-export',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        const path = decodeURIComponent((req.url || '/').split('?')[0])
        if (path === '/game') { res.writeHead(301, { Location: '/game/' }); return res.end() }
        if (!path.startsWith('/game/')) return next()
        let file = normalize(join(dir, path.slice('/game/'.length)))
        if (!file.startsWith(dir)) return next() // sin salir de la carpeta
        if (existsSync(file) && statSync(file).isDirectory()) file = join(file, 'index.html')
        if (!existsSync(file)) return next()
        res.writeHead(200, { 'Content-Type': TYPES[extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-cache' })
        createReadStream(file).pipe(res)
      })
    },
  }
}

// La landing se sirve en / (Nginx en producción). En desarrollo este Vite es la entrada:
// reenvía el mando, el WebSocket y la API para que todo salga del mismo origen, como en producción.
export default defineConfig({
  base: '/',
  plugins: [vue(), tailwindcss(), gameExport()],
  build: {
    outDir: '../dist/landing',
    emptyOutDir: true,
  },
  server: {
    host: true, // accesible desde móviles de la LAN durante el desarrollo
    proxy: {
      '/controller': { target: `http://localhost:${controllerPort}`, ws: true },
      '/ws': { target: `ws://localhost:${backendPort}`, ws: true },
      '/api': { target: `http://localhost:${backendPort}` },
    },
  },
})
