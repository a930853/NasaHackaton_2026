import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

// Puerto del backend en desarrollo. En Windows, Hyper-V/WSL a veces reservan el 3000:
// arrancad el backend con PORT=<otro> y Vite con BACKEND_PORT=<el mismo>.
const backendPort = process.env.BACKEND_PORT || 3000

// El mando se sirve en /controller/ (Nginx en producción, Vite en desarrollo).
export default defineConfig({
  base: '/controller/',
  plugins: [vue(), tailwindcss()],
  build: {
    outDir: '../dist/controller',
    emptyOutDir: true,
  },
  server: {
    host: true, // accesible desde móviles de la LAN durante el desarrollo
    proxy: {
      // Mismo origen que en producción: el código siempre usa location.host + /ws
      '/ws': { target: `ws://localhost:${backendPort}`, ws: true },
    },
  },
})
