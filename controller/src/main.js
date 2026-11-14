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
import './styles.css'

createApp(App).use(router).mount('#app')
