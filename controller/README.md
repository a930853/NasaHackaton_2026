# Web Controller

Vue 3 + Vite + Tailwind CSS 4 app (JavaScript) used by each player on their phone. It connects to the backend over the `/ws` WebSocket.

```bash
npm install
npm run dev     # http://localhost:5173/controller/ (backend must be running)
npm test        # store tests against the real backend
npm run build   # generates ../dist/controller/
```

Routes: `/controller/` (choose a role on screen) and `/controller/<engineer|biologist|doctor|generalist>` (direct entry to a role, e.g. from the NFC board). `?room=K7MP` preloads a room code.

Full documentation (architecture, states, session recovery, styling and deployment): [`docs/en/controller.md`](../docs/en/controller.md). Message contract: [`docs/en/protocol.md`](../docs/en/protocol.md). Spanish documentation remains available at [`docs/es/controller.md`](../docs/es/controller.md).
