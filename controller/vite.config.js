import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

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
      '/ws': { target: 'ws://localhost:3000', ws: true },
    },
  },
})
