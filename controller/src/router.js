import { createRouter, createWebHistory } from 'vue-router'
import App from './App.vue'

const roleRoute = (name) => ({
  path: `/${name}`,
  name,
  component: App,
  meta: { role: name },
})

export default createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', name: 'inicio', component: App },
    roleRoute('ingeniero'),
    roleRoute('biologo'),
    roleRoute('medico'),
    roleRoute('polivalente'),
  ],
})


