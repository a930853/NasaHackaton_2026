<script setup>
// Orquesta el mando: decide qué pantalla mostrar a partir del estado de la sesión
// y traduce la ruta (/controller/<rol>) en una petición de rol al backend.
import { computed, inject, onBeforeUnmount, onMounted, ref, watch } from 'vue'
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

const preGameTrack = '/controller/audio/Chill_MN.mp3'
const gameTrack = '/controller/audio/Chill_Space2026.mp3'
let music = null
let musicUnlocked = false

function syncMusic() {
  if (!music) return
  const nextTrack = s.phase === 'playing' ? gameTrack : preGameTrack
  if (music.src !== new URL(nextTrack, window.location.href).href) {
    music.src = nextTrack
    music.load()
  }
  if (musicUnlocked) music.play().catch(() => {})
}

function unlockMusic() {
  musicUnlocked = true
  syncMusic()
}

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
      message.value = error.code === 'role_taken' && name ? `The ${name} role is taken. Pick another one.` : errorText(error.code)
      requestedRole = null
      goTo('home')
      return
    }
    message.value = errorText(error.code)
  },
)

watch(() => s.phase, syncMusic)

onMounted(() => {
  music = new Audio()
  music.loop = true
  music.volume = 1
  window.addEventListener('pointerdown', unlockMusic, { once: true })
  window.addEventListener('keydown', unlockMusic, { once: true })
  syncMusic()
})

onBeforeUnmount(() => {
  window.removeEventListener('pointerdown', unlockMusic)
  window.removeEventListener('keydown', unlockMusic)
  music?.pause()
  music = null
})

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

const footerText = computed(() => {
  if (!s.code) return 'NASA · MISSION SIMULATOR'
  return `ROOM ${s.code}${s.name ? ` · ${s.name.toUpperCase()}` : ''}`
})

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
    class="flex min-h-dvh flex-col overflow-x-hidden"
    :class="!showRoleScreen && s.phase === 'lobby' ? 'fixed-mobile-screen h-dvh min-h-0 overflow-hidden' : ''"
    :style="roleStyle(roleInfo)"
  >
    <p
      v-if="s.connection === 'offline' && s.phase !== 'connecting'"
      class="sticky top-0 z-10 border-b-[3px] border-outline bg-amber px-4 py-2.5 text-center font-mono text-xs font-medium text-outline"
      role="status"
    >
      No connection to Mission Control. Reconnecting…
    </p>

    <!-- Otro dispositivo ha recuperado esta misma sesión -->
    <section v-if="s.connection === 'replaced'" class="screen-w flex min-h-0 flex-1 flex-col justify-center py-12">
      <StatusCard mark="⇄" eyebrow="OPENED ON ANOTHER DEVICE" title="Your session was opened on another device.">
        <button class="btn-primary" type="button" @click="session.takeOver()">Use this device</button>
      </StatusCard>
    </section>

    <section
      v-else-if="s.phase === 'connecting' || s.phase === 'joining'"
      class="screen-w flex min-h-0 flex-1 flex-col justify-center gap-[clamp(20px,6vh,56px)] py-8 md:py-12"
    >
      <ScreenHeading>Join the <span class="text-amber">mission</span></ScreenHeading>
      <p class="notice text-outline" role="status">
        Connecting to Mission Control<span class="tracking-[3px]">...</span>
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
      <StatusCard mark="■" eyebrow="ROOM CLOSED" :title="closedText(s.closedReason)">
        <button class="btn-primary" type="button" @click="restart">Back to start</button>
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
      <header class="hull-plate mt-[clamp(14px,3vh,30px)] flex items-center justify-between gap-3">
        <div class="flex items-center gap-3">
          <!-- Casco del color del rol, como los astronautas del juego -->
          <span
            class="size-10 shrink-0 rounded-full border-[3px] border-outline bg-(--role-color) shadow-[inset_-5px_-5px_0_rgb(26_32_48/.25)]"
            aria-hidden="true"
          />
          <div>
            <p class="mb-0.5 font-mono text-[11px] font-medium tracking-[.14em] text-outline/75">
              YOUR MISSION<span v-if="s.commander"> · COMMANDER</span>
            </p>
            <h1 id="role-title" class="text-[clamp(28px,4.5vw,50px)] leading-[.98] font-bold tracking-[-.04em]">
              {{ roleInfo.name }}
            </h1>
          </div>
        </div>
        <span class="rounded-[10px] border-[3px] border-outline bg-navy px-2.5 py-1.5 font-mono text-xs tracking-[.15em] text-neon-cyan">
          {{ s.code }}
        </span>
      </header>

      <p v-if="message" class="notice-error mt-4" role="alert">{{ message }}</p>

      <div v-if="s.phase === 'lobby'" class="mt-[clamp(16px,3vh,32px)]">
        <StatusCard
          v-if="s.role !== activeRole"
          mark="…"
          eyebrow="SAVING YOUR ROLE"
          title="Saving your place on the crew"
        />
        <StatusCard
          v-else
          mark="✓"
          eyebrow="ROLE SAVED"
          title="Waiting for Mission Control to start"
          text="Look at the main screen: the mission starts when the whole crew is ready."
        >
          <CrewList class="mx-auto mt-6 text-left" :players="s.players" :player-id="s.playerId" />
          <button class="btn-secondary" type="button" @click="changeRole">Change role</button>
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
            eyebrow="MISSION RUNNING"
            title="The mission is starting"
            text="Watch the main screen."
          />
          <StatusCard
            v-else-if="decided"
            mark="✓"
            eyebrow="CHOICE SAVED"
            title="Your choice reached Mission Control."
            text="Waiting for the rest of the crew…"
          />
          <StatusCard
            v-else-if="s.view.screen === 'result'"
            mark="★"
            eyebrow="RESULT"
            :title="s.view.title || 'Result'"
            :text="s.view.text"
          />
          <StatusCard v-else eyebrow="PLEASE WAIT" :title="s.view.title || 'Waiting…'" :text="s.view.text" />
        </div>
      </template>
    </section>

    <footer class="screen-w flex items-center gap-2 pt-[18px] pb-6 font-mono text-[10px] font-medium tracking-[.08em] text-dim">
      <span class="hud-light h-2.5 w-2.5" aria-hidden="true" />
      <span>{{ footerText }}</span>
    </footer>
  </main>
</template>
