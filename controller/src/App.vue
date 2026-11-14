<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { checkRoom, claimRole, getQuestionOptions, sendAnswer } from './api'

const router = useRouter()
const route = useRoute()

const roles = {
  ingeniero: {
    name: 'Ingeniero',
    subtitle: 'Sistemas y tecnología',
    code: 'ENG',
    color: '#f5b940',
    pale: '#fff3ce',
    dark: '#7b5100',
  },
  biologo: {
    name: 'Biólogo',
    subtitle: 'Vida y ecosistemas',
    code: 'BIO',
    color: '#57c98b',
    pale: '#dcf8e9',
    dark: '#17603d',
  },
  medico: {
    name: 'Médico',
    subtitle: 'Salud y bienestar',
    code: 'MED',
    color: '#f17474',
    pale: '#ffe1e1',
    dark: '#812d2d',
  },
  polivalente: {
    name: 'Polivalente',
    subtitle: 'Misión y coordinación',
    code: 'OPS',
    color: '#68aaf0',
    pale: '#dfedff',
    dark: '#235185',
  },
}

const isRoleScreen = computed(() => Boolean(route.meta.role))
const selectedRole = computed(() => roles[route.meta.role])
const roomId = computed(() => String(route.query.room || '').trim())
const availableRoles = ref(Object.keys(roles))
const options = ref([])
const loading = ref(false)
const responseSent = ref(false)
const errorMessage = ref('')
const roomChecked = ref(false)
const roomInput = ref('')

const roleList = computed(() =>
  Object.entries(roles).map(([id, role]) => ({
    id,
    ...role,
    available: availableRoles.value.includes(id),
  })),
)

async function loadRoom() {
  if (!roomId.value) {
    roomChecked.value = false
    return
  }

  if (roomId.value === '1') {
    errorMessage.value = ''
    availableRoles.value = Object.keys(roles)
    roomChecked.value = true
    return
  }

  loading.value = true
  errorMessage.value = ''
  try {
    const result = await checkRoom(roomId.value)
    if (!result.exists) {
      errorMessage.value = 'Esta sala no existe o ya no está disponible.'
      availableRoles.value = []
      return
    }
    availableRoles.value = result.availableRoles || result.rolesAvailable || []
  } catch (error) {
    errorMessage.value = error.message
  } finally {
    roomChecked.value = true
    loading.value = false
  }
}

async function submitRoom() {
  const room = roomInput.value.trim()
  if (!room) {
    errorMessage.value = 'Introduce el identificador de la sala para continuar.'
    return
  }

  errorMessage.value = ''
  await router.replace({ name: 'inicio', query: { room } })
}

async function loadQuestion() {
  loading.value = true
  errorMessage.value = ''
  try {
    const result = await getQuestionOptions(roomId.value)
    options.value = result.options || result.question?.options || []
  } catch (error) {
    errorMessage.value = error.message
  } finally {
    loading.value = false
  }
}

async function chooseRole(role) {
  if (!role.available) {
    errorMessage.value = `${role.name} ya está ocupado. Elige otro rol.`
    await router.replace({ name: 'inicio', query: { room: roomId.value } })
    return
  }

  loading.value = true
  errorMessage.value = ''
  try {
    await router.replace({ name: role.id, query: { room: roomId.value } })
  } catch (error) {
    errorMessage.value = error.message
    await loadRoom()
  } finally {
    loading.value = false
  }
}

async function selectAnswer(answer) {
  loading.value = true
  errorMessage.value = ''
  try {
    if (roomId.value === '1') {
      responseSent.value = true
      return
    }

    await sendAnswer(roomId.value, route.meta.role, answer)
    responseSent.value = true
  } catch (error) {
    errorMessage.value = error.message
  } finally {
    loading.value = false
  }
}

function showStartScreen() {
  responseSent.value = false
  options.value = []
  loadRoom()
}

async function showRoleScreen() {
  responseSent.value = false
  await loadRoom()
  if (errorMessage.value || !availableRoles.value.includes(route.meta.role)) {
    errorMessage.value = 'Este rol ya no está disponible. Elige otro rol.'
    await router.replace({ name: 'inicio', query: { room: roomId.value } })
    return
  }

  if (roomId.value === '1') {
    options.value = [
      { value: 'demo-a', label: 'Opción de prueba A' },
      { value: 'demo-b', label: 'Opción de prueba B' },
    ]
    return
  }

  try {
    loading.value = true
    await claimRole(roomId.value, route.meta.role)
    await loadQuestion()
  } catch (error) {
    errorMessage.value = error.message
    await router.replace({ name: 'inicio', query: { room: roomId.value } })
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  if (isRoleScreen.value) {
    showRoleScreen()
  } else {
    showStartScreen()
  }
})

watch(
  () => [route.name, route.query.room],
  () => {
    if (isRoleScreen.value) {
      showRoleScreen()
    } else {
      showStartScreen()
    }
  },
)
</script>

<template>
  <main
    class="app-shell"
    :class="{ 'role-mode': isRoleScreen }"
    :style="selectedRole ? { '--role-color': selectedRole.color, '--role-pale': selectedRole.pale, '--role-dark': selectedRole.dark } : {}"
  >
    <section v-if="!isRoleScreen" class="screen start-screen" aria-labelledby="start-title">
      <div class="start-content">
        <div v-if="roomId" class="welcome">
          <div>
            <p class="eyebrow">NASA · CENTRO DE CONTROL</p>
            <h1 id="start-title">¿Qué quieres ser <span>hoy?</span></h1>
            <p class="hint">Selecciona tu especialidad para comenzar.</p>
          </div>
        </div>
        <div v-else class="welcome">
          <div>
            <p class="eyebrow">NASA · CENTRO DE CONTROL</p>
            <h1 id="start-title">Únete a la <span>misión</span></h1>
            <p class="hint">Introduce el código de sala para comenzar.</p>
          </div>
        </div>

        <form v-if="!roomId" class="room-form" @submit.prevent="submitRoom">
          <label for="room-code">Código de sala</label>
          <div class="room-form-row">
            <input
              id="room-code"
              v-model="roomInput"
              type="text"
              name="room"
              autocomplete="off"
              placeholder="Ej. K7MP"
              maxlength="20"
              required
            >
            <button type="submit">Entrar en la sala <span aria-hidden="true">→</span></button>
          </div>
          <p class="room-help">Introduce el código que aparece en la pantalla principal.</p>
        </form>
        <p v-if="loading" class="server-message">Conectando con el centro de control...</p>
        <p v-if="errorMessage" class="server-message error-message">{{ errorMessage }}</p>

        <div v-if="roomChecked && !loading && !errorMessage" class="role-grid" aria-label="Elige tu rol">
          <button
            v-for="role in roleList"
            :key="role.id"
            class="role-button"
            :class="{ disabled: !role.available }"
            :style="{ '--button-color': role.color, '--button-pale': role.pale, '--button-dark': role.dark }"
            :disabled="!role.available"
            type="button"
            @click="chooseRole(role)"
          >
            <span class="role-code" aria-hidden="true">{{ role.code }}</span>
            <span class="role-button-copy">
              <strong>{{ role.name }}</strong>
              <small>{{ role.available ? role.subtitle : 'No disponible' }}</small>
            </span>
            <span class="button-go" aria-hidden="true">{{ role.available ? '→' : '—' }}</span>
          </button>
        </div>
      </div>
    </section>

    <section v-else class="screen role-screen" aria-labelledby="role-title">
      <header class="role-header">
        <div class="role-title">
          <div>
            <p class="eyebrow">TU MISIÓN</p>
            <h1 id="role-title">{{ selectedRole.name }}</h1>
          </div>
        </div>
      </header>

      <p v-if="errorMessage" class="server-message error-message">{{ errorMessage }}</p>
      <div v-if="!responseSent" class="answer-area">
        <div class="question-note">
          <span aria-hidden="true">01</span>
          <div>
            <strong>RESPUESTA DE TRIPULACIÓN</strong>
            <span>Selecciona una de las opciones recibidas.</span>
          </div>
        </div>
        <div v-if="loading" class="server-message">Recibiendo opciones...</div>
        <div v-else class="answer-grid" aria-label="Opciones de respuesta">
          <button
            v-for="(option, index) in options"
            :key="index"
            class="answer-button"
            type="button"
            @click="selectAnswer(option.value ?? option.id ?? option)"
          >
            <span class="answer-number">{{ index + 1 }}</span>
            <span>{{ option.label ?? option.text ?? option }}</span>
            <span class="answer-check" aria-hidden="true">→</span>
          </button>
        </div>
      </div>
      <div v-else class="waiting-screen" role="status" aria-live="polite">
        <div class="waiting-mark" aria-hidden="true">✓</div>
        <p class="eyebrow">RESPUESTA ENVIADA</p>
        <h2>Respuesta recibida por el centro de control.</h2>
        <p>Esperando la siguiente pregunta de la misión<span class="loading-dots">...</span></p>
      </div>
    </section>
  </main>
</template>
