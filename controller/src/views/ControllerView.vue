<script setup>
// Orquesta el mando: decide qué pantalla mostrar a partir del estado de la sesión
// y traduce la ruta (/controller/<rol>) en una petición de rol al backend.
import { computed, inject, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ROLES, roleStyle } from '../roles.js'
import { closedText, errorText } from '../messages.js'
import ChoiceView from '../components/ChoiceView.vue'
import CrewList from '../components/CrewList.vue'
import ScreenHeading from '../components/ScreenHeading.vue'
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

</script>

<template>
  <main
    class="mission-screen relative flex min-h-dvh flex-col overflow-x-hidden"
    :class="[
      !showRoleScreen && s.phase === 'lobby' ? 'fixed-mobile-screen h-dvh min-h-0 overflow-hidden' : '',
      s.phase === 'enter' ? 'enter-layout' : '',
      showRoleScreen
        ? 'bg-[radial-gradient(circle_at_85%_4%,rgba(52,97,143,.38),transparent_30%)]'
        : 'bg-[radial-gradient(circle_at_85%_4%,rgba(32,75,120,.5),transparent_28%)]',
    ]"
    :style="roleStyle(roleInfo)"
  >
    <div v-if="s.phase !== 'enter' && !(s.phase === 'lobby' && !showRoleScreen)" class="mission-brand" aria-label="NASA">
      <svg viewBox="0 0 100 100" role="img" aria-hidden="true">
        <circle cx="50" cy="50" r="44" fill="#1262a8" />
        <path d="M12 61C34 48 59 38 88 17C64 45 39 62 13 73" fill="none" stroke="#ef3340" stroke-width="4" />
        <path d="M20 71C42 37 60 22 82 18C58 32 42 51 28 78" fill="none" stroke="#fff" stroke-width="1.5" />
        <text x="50" y="59" fill="#fff" font-family="Georgia, serif" font-size="21" font-weight="700" text-anchor="middle">NASA</text>
      </svg>
    </div>

    <p
      v-if="s.connection === 'offline' && s.phase !== 'connecting'"
      class="sticky top-0 z-10 bg-amber px-4 py-2.5 text-center font-mono text-xs text-navy"
      role="status"
    >
      Sin conexión con el centro de control. Reconectando…
    </p>

    <!-- Otro dispositivo ha recuperado esta misma sesión -->
    <section v-if="s.connection === 'replaced'" class="screen-w flex min-h-0 flex-1 flex-col justify-center py-12">
      <StatusCard mark="⇄" eyebrow="SESIÓN EN OTRO DISPOSITIVO" title="Tu sesión se ha abierto en otro dispositivo.">
        <button class="btn-primary" type="button" @click="session.takeOver()">Usar este dispositivo</button>
      </StatusCard>
    </section>

    <section
      v-else-if="s.phase === 'connecting' || s.phase === 'joining'"
      class="screen-w flex min-h-0 flex-1 flex-col justify-center gap-[clamp(20px,6vh,56px)] py-8 md:py-12"
    >
      <ScreenHeading>Únete a la <span class="text-amber">misión</span></ScreenHeading>
      <p class="notice" role="status">
        Conectando con el centro de control<span class="tracking-[3px] text-amber">...</span>
      </p>
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

    <section v-else-if="s.phase === 'closed'" class="screen-w flex min-h-0 flex-1 flex-col justify-center py-8 md:py-12">
      <StatusCard class="mission-status-card" mark="■" eyebrow="SALA CERRADA" :title="closedText(s.closedReason)">
        <button class="role-change-button" type="button" @click="restart">
          <span>Volver al inicio</span>
        </button>
      </StatusCard>
    </section>

    <RolePicker
      v-else-if="!showRoleScreen"
      :players="s.players"
      :player-id="s.playerId"
      :message="message"
      @pick="pickRole"
    />

    <section v-else class="screen-w flex min-h-0 flex-1 flex-col overflow-hidden" aria-labelledby="role-title">
      <header class="mission-header flex items-center justify-between">
        <div>
          <p class="eyebrow text-(--role-color)">TU MISIÓN</p>
          <h1 id="role-title" class="text-[clamp(34px,4.5vw,58px)] leading-[.98] font-bold tracking-[-.055em]">
            {{ roleInfo.name }}
          </h1>
        </div>
        <span class="rounded-[5px] border border-line px-2.5 py-1.5 font-mono text-xs tracking-[.15em] text-muted">
          {{ s.code }}
        </span>
      </header>

      <p v-if="message" class="notice-error mt-4" role="alert">{{ message }}</p>

      <div v-if="s.phase === 'lobby'" class="mt-[clamp(16px,3vh,32px)]">
        <StatusCard
          v-if="s.role !== activeRole"
          mark="…"
          eyebrow="RESERVANDO ROL"
          title="Reservando tu puesto en la tripulación"
        />
        <StatusCard
          v-else
          class="role-status-card"
          mark=""
          eyebrow="ROL RESERVADO"
          title="Esperando a que el centro de control inicie la misión"
        >
          <CrewList class="mx-auto mt-6 text-left" :players="s.players" :player-id="s.playerId" />
          <button class="btn-secondary role-change-button" type="button" @click="changeRole">
            <span>Cambiar de rol</span>
          </button>
        </StatusCard>
      </div>

      <template v-else>
        <ChoiceView
          v-if="s.view?.screen === 'choice' && !decided"
          :view="s.view"
          :choice="s.choice"
          @choose="session.choose"
        />
        <div v-else class="mt-[clamp(16px,3vh,32px)]">
          <StatusCard
            v-if="!s.view"
            class="mission-status-card"
            eyebrow="MISIÓN EN CURSO"
            title="La misión está comenzando"
            text="Atento a la pantalla principal."
          />
          <StatusCard
            v-else-if="decided"
            class="mission-status-card"
            mark="✓"
            eyebrow="DECISIÓN REGISTRADA"
            title="Tu decisión ha llegado al centro de control."
            text="Esperando al resto de la tripulación…"
          />
          <StatusCard
            v-else-if="s.view.screen === 'result'"
            class="mission-status-card"
            mark="★"
            eyebrow="RESULTADO"
            :title="s.view.title || 'Resultado'"
            :text="s.view.text"
          />
          <StatusCard
            v-else
            class="mission-status-card"
            eyebrow="EN ESPERA"
            :title="s.view.title || 'Esperando…'"
            :text="s.view.text"
          />
        </div>
      </template>
    </section>

    <footer class="screen-w flex items-center pt-1.5 pb-2 font-mono text-[9px] tracking-[.08em] text-dim">
      <span>{{ footerText }}</span>
    </footer>
  </main>
</template>
