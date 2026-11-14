<script setup>
// Orquesta el mando: decide qué pantalla mostrar a partir del estado de la sesión
// y traduce la ruta (/controller/<rol>) en una petición de rol al backend.
import { computed, inject, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ROLES, roleStyle } from '../roles.js'
import { closedText, errorText } from '../messages.js'
import ChoiceView from '../components/ChoiceView.vue'
import CrewList from '../components/CrewList.vue'
import StatusCard from '../components/StatusCard.vue'
import EnterView from './EnterView.vue'
import RolePicker from './RolePicker.vue'

const session = inject('session')
const s = session.state
const route = useRoute()
const router = useRouter()

const message = ref('')
/** Rol pedido al backend y aún sin confirmar (evita repetir la petición). */
let requestedRole = null
/** Tras entrar o recuperar la sesión desde /controller/, llevar al jugador a la pantalla de su rol. */
let goToOwnRole = true

const routeRole = computed(() => route.meta.role ?? null)
const inRoom = computed(() => s.phase === 'lobby' || s.phase === 'playing')
// Durante la partida manda el rol confirmado; en el lobby, el de la ruta.
const activeRole = computed(() => (s.phase === 'playing' ? s.role : routeRole.value))
const showRoleScreen = computed(() => inRoom.value && Boolean(activeRole.value))
const roleInfo = computed(() => ROLES[activeRole.value] ?? null)
const decided = computed(
  () => s.view?.screen === 'choice' && s.choice.status === 'registered' && s.choice.eventId === s.view.eventId,
)

function goTo(name, { push = false } = {}) {
  const location = { name, query: s.code ? { room: s.code } : {} }
  return push ? router.push(location) : router.replace(location)
}

// La ruta de rol es la intención del jugador (botón en pantalla o etiqueta NFC del tablero).
watch(
  [routeRole, () => s.phase, () => s.role],
  ([wanted, phase, mine]) => {
    if (phase === 'playing') {
      // Los roles quedan fijos al empezar: la ruta se ajusta al rol real.
      if (mine && wanted !== mine) goTo(mine)
      return
    }
    if (phase !== 'lobby') return
    if (!wanted) {
      if (mine && goToOwnRole) goTo(mine)
      goToOwnRole = false
      return
    }
    goToOwnRole = false
    if (wanted === mine) {
      requestedRole = null
      message.value = ''
    } else if (requestedRole !== wanted) {
      requestedRole = wanted
      session.selectRole(wanted)
    }
  },
  { immediate: true },
)

// La URL refleja siempre la sala en la que está el jugador.
watch(
  () => s.code,
  (code) => {
    if (code && route.query.room !== code) router.replace({ name: route.name, query: { ...route.query, room: code } })
  },
)

watch(
  () => s.error?.seq,
  () => {
    const error = s.error
    if (!error) return
    if (error.requestType === 'choose') return // lo muestra la pantalla de decisión
    if (error.requestType === 'select_role') {
      const name = ROLES[requestedRole]?.name
      message.value = error.code === 'role_taken' && name ? `${name} ya está ocupado. Elige otro rol.` : errorText(error.code)
      requestedRole = null
      goTo('home')
      return
    }
    message.value = errorText(error.code)
  },
)

function join({ code, name }) {
  message.value = ''
  session.join(code, name)
}

function pickRole(role) {
  message.value = ''
  goTo(role, { push: true })
}

function changeRole() {
  message.value = ''
  goTo('home', { push: true })
}

function restart() {
  message.value = ''
  requestedRole = null
  goToOwnRole = true
  session.restart()
  // Se conserva la ruta de rol (útil en el tablero NFC) pero no la sala cerrada.
  router.replace({ name: route.name })
}

const footerText = computed(() => {
  if (!s.code) return 'NASA · SIMULADOR DE MISIÓN'
  return `SALA ${s.code}${s.name ? ` · ${s.name.toUpperCase()}` : ''}`
})
</script>

<template>
  <main class="app-shell" :class="{ 'role-mode': showRoleScreen }" :style="roleStyle(roleInfo)">
    <p v-if="s.connection === 'offline' && s.phase !== 'connecting'" class="connection-banner" role="status">
      Sin conexión con el centro de control. Reconectando…
    </p>

    <!-- Otro dispositivo ha recuperado esta misma sesión -->
    <section v-if="s.connection === 'replaced'" class="screen">
      <div class="start-content">
        <StatusCard mark="⇄" eyebrow="SESIÓN EN OTRO DISPOSITIVO" title="Tu sesión se ha abierto en otro dispositivo.">
          <button class="primary-button" type="button" @click="session.takeOver()">Usar este dispositivo</button>
        </StatusCard>
      </div>
    </section>

    <section v-else-if="s.phase === 'connecting' || s.phase === 'joining'" class="screen start-screen">
      <div class="start-content">
        <div class="welcome">
          <p class="eyebrow">NASA · CENTRO DE CONTROL</p>
          <h1>Únete a la <span>misión</span></h1>
        </div>
        <p class="server-message" role="status">Conectando con el centro de control<span class="loading-dots">...</span></p>
      </div>
    </section>

    <EnterView
      v-else-if="s.phase === 'enter'"
      :initial-code="s.prefillCode"
      :initial-name="s.name"
      :role="ROLES[routeRole] ?? null"
      :message="message"
      :busy="s.connection !== 'online'"
      @join="join"
    />

    <section v-else-if="s.phase === 'closed'" class="screen">
      <div class="start-content">
        <StatusCard mark="■" eyebrow="SALA CERRADA" :title="closedText(s.closedReason)">
          <button class="primary-button" type="button" @click="restart">Volver al inicio</button>
        </StatusCard>
      </div>
    </section>

    <RolePicker
      v-else-if="!showRoleScreen"
      :players="s.players"
      :player-id="s.playerId"
      :message="message"
      @pick="pickRole"
    />

    <section v-else class="screen role-screen" aria-labelledby="role-title">
      <header class="role-header">
        <div class="role-title">
          <div>
            <p class="eyebrow">TU MISIÓN</p>
            <h1 id="role-title">{{ roleInfo.name }}</h1>
          </div>
        </div>
        <span class="room-badge">{{ s.code }}</span>
      </header>

      <p v-if="message" class="server-message error-message" role="alert">{{ message }}</p>

      <template v-if="s.phase === 'lobby'">
        <StatusCard
          v-if="s.role !== activeRole"
          mark="…"
          eyebrow="RESERVANDO ROL"
          title="Reservando tu puesto en la tripulación"
        />
        <StatusCard
          v-else
          mark="✓"
          eyebrow="ROL RESERVADO"
          title="Esperando a que el centro de control inicie la misión"
          text="Mira la pantalla principal: la misión empezará en cuanto esté lista la tripulación."
        >
          <CrewList :players="s.players" :player-id="s.playerId" />
          <button class="secondary-button" type="button" @click="changeRole">Cambiar de rol</button>
        </StatusCard>
      </template>

      <template v-else>
        <StatusCard
          v-if="!s.view"
          eyebrow="MISIÓN EN CURSO"
          title="La misión está comenzando"
          text="Atento a la pantalla principal."
        />
        <StatusCard
          v-else-if="decided"
          mark="✓"
          eyebrow="DECISIÓN REGISTRADA"
          title="Tu decisión ha llegado al centro de control."
          text="Esperando al resto de la tripulación…"
        />
        <ChoiceView v-else-if="s.view.screen === 'choice'" :view="s.view" :choice="s.choice" @choose="session.choose" />
        <StatusCard
          v-else-if="s.view.screen === 'result'"
          mark="★"
          eyebrow="RESULTADO"
          :title="s.view.title || 'Resultado'"
          :text="s.view.text"
        />
        <StatusCard v-else eyebrow="EN ESPERA" :title="s.view.title || 'Esperando…'" :text="s.view.text" />
      </template>
    </section>

    <footer class="kid-footer screen-footer">
      <span class="status-dot" :class="{ offline: s.connection !== 'online' }" aria-hidden="true" />
      <span>{{ footerText }}</span>
    </footer>
  </main>
</template>
