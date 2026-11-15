<script setup>
// Orquesta el mando: decide qué pantalla mostrar a partir del estado de la sesión
// y traduce la ruta (/controller/<rol>) en una petición de rol al backend.
import { computed, inject, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ROLES, roleStyle } from '../roles.js'
import { closedText, errorText } from '../messages.js'
import ChoiceView from '../components/ChoiceView.vue'
import CrewList from '../components/CrewList.vue'
import DevicePlate from '../components/DevicePlate.vue'
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

const preGameTrack = '/controller/audio/Chill_Space2026.mp3'
const gameTrack = '/controller/audio/Chill_MN.mp3'
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

// Placa de arriba: con rol, quién eres; sin rol, el nombre del juego.
const plateTitle = computed(() => (showRoleScreen.value && roleInfo.value ? roleInfo.value.name : 'Mars Mission'))
const plateSubtitle = computed(() => {
  if (!s.name || !s.code) return 'Crew controller'
  return s.commander ? `${s.name}, crew commander` : s.name
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
  <main class="flex min-h-dvh flex-col justify-center py-5" :style="roleStyle(roleInfo)">
    <div class="device">
      <span class="screw top-2.5 left-3" aria-hidden="true" />
      <span class="screw top-2.5 right-3" aria-hidden="true" />
      <DevicePlate :title="plateTitle" :subtitle="plateSubtitle" :code="s.code" />

      <p v-if="s.connection === 'offline' && s.phase !== 'connecting'" class="alert" role="status">
        Lost the link to the main screen. Trying again…
      </p>

      <!-- Otro dispositivo ha recuperado esta misma sesión -->
      <StatusCard
        v-if="s.connection === 'replaced'"
        title="Opened somewhere else"
        text="Your place on the crew is open on another device."
      >
        <template #actions>
          <button class="key text-center" type="button" @click="session.takeOver()">Use this device</button>
        </template>
      </StatusCard>

      <StatusCard
        v-else-if="s.phase === 'connecting' || s.phase === 'joining'"
        title="Connecting…"
        text="Getting in touch with the main screen."
      />

      <EnterView
        v-else-if="s.phase === 'enter'"
        :initial-code="s.prefillCode"
        :initial-name="s.name"
        :role="ROLES[routeRole] ?? null"
        :message="message"
        :busy="s.connection !== 'online'"
        @join="join"
      />

      <StatusCard v-else-if="s.phase === 'closed'" title="Room closed" :text="closedText(s.closedReason)">
        <template #actions>
          <button class="key text-center" type="button" @click="restart">Join another room</button>
        </template>
      </StatusCard>

      <RolePicker
        v-else-if="!showRoleScreen"
        :players="s.players"
        :player-id="s.playerId"
        :message="message"
        @pick="pickRole"
      />

      <section v-else class="flex flex-1 flex-col gap-5" aria-label="Your mission">
        <p v-if="message" class="alert" role="alert">{{ message }}</p>

        <template v-if="s.phase === 'lobby'">
          <StatusCard v-if="s.role !== activeRole" title="Saving your job…" />
          <StatusCard
            v-else
            title="You are in!"
            text="The mission starts when the whole crew is ready. Look at the main screen."
          >
            <CrewList :players="s.players" :player-id="s.playerId" />
            <template #actions>
              <button class="key key-quiet text-center" type="button" @click="changeRole">Change job</button>
            </template>
          </StatusCard>
        </template>

        <template v-else>
          <ChoiceView
            v-if="s.view?.screen === 'choice' && !decided"
            :view="s.view"
            :choice="s.choice"
            @choose="session.choose"
          />
          <StatusCard v-else-if="!s.view" title="Lift-off!" text="The mission is starting. Watch the main screen." />
          <StatusCard v-else-if="decided" title="Vote sent!" text="Waiting for the rest of the crew…" />
          <StatusCard v-else-if="s.view.screen === 'result'" :title="s.view.title || 'Result'" :text="s.view.text">
            <template v-if="s.view.canContinue !== false" #actions>
              <button
                class="key text-center"
                type="button"
                :disabled="s.continueStatus === 'sending'"
                :aria-pressed="s.continueStatus === 'sending'"
                @click="session.continueMission()"
              >
                {{ s.continueStatus === 'sending' ? 'Waiting for the crew…' : 'Continue' }}
              </button>
            </template>
          </StatusCard>
          <StatusCard v-else :title="s.view.title || 'Please wait'" :text="s.view.text" />
        </template>
      </section>

      <span class="screw bottom-2.5 left-3" aria-hidden="true" />
      <span class="screw right-3 bottom-2.5" aria-hidden="true" />
    </div>
  </main>
</template>
