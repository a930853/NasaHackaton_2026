# Mando web

App Vue 3 + Vite + Tailwind CSS que usa cada jugador en su móvil. Se conecta al backend por el WebSocket `/ws`.

```bash
npm install
npm run dev     # http://localhost:5173/controller/  (necesita el backend en marcha)
npm test        # tests del store contra el backend real
npm run build   # genera ../dist/controller/
```

Rutas: `/controller/` (elegir rol en pantalla) y `/controller/<engineer|biologist|doctor|generalist>` (entrada directa a un rol, p. ej. desde el tablero NFC). `?room=K7MP` precarga el código de sala.

Documentación completa (arquitectura, estados, recuperación de sesión, estilos y despliegue): [`docs/controller.md`](../docs/controller.md). Contrato de mensajes: [`docs/protocol.md`](../docs/protocol.md).
