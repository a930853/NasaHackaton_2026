import { createApp } from 'vue'
// Fuentes empaquetadas: la demo funciona en la LAN sin Internet.
import '@fontsource/space-grotesk/400.css'
import '@fontsource/space-grotesk/500.css'
import '@fontsource/space-grotesk/600.css'
import '@fontsource/space-grotesk/700.css'
import '@fontsource/dm-mono/400.css'
import '@fontsource/dm-mono/500.css'
import App from './App.vue'
import router from './router'
import { wsUrl } from './net/socket.js'
import { createSession } from './stores/session.js'
import './styles.css'

const session = createSession({ url: wsUrl() })

createApp(App).use(router).provide('session', session).mount('#app')

// Conecta cuando el router conoce la URL inicial (para leer ?room=).
router.isReady().then(() => session.start({ room: router.currentRoute.value.query.room }))
