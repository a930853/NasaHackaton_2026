import { createRouter, createWebHistory } from 'vue-router'
import { ROLE_IDS } from './roles.js'
import ControllerView from './views/ControllerView.vue'

// La ruta expresa la INTENCIÓN del jugador: /controller/ para elegir rol en pantalla,
// /controller/<rol> para entrar directamente con ese rol (botón o etiqueta NFC del tablero).
// El rol real lo confirma el backend (lobby_state). ?room=<código> precarga la sala.
export default createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: '/', name: 'home', component: ControllerView },
    ...ROLE_IDS.map((role) => ({ path: `/${role}`, name: role, component: ControllerView, meta: { role } })),
    { path: '/:pathMatch(.*)*', redirect: (to) => ({ name: 'home', query: to.query }) },
  ],
})
