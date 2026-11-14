<script setup>
// Entrada a la sala: código (precargado desde ?room=) y nombre.
import { ref, watch } from 'vue'

const props = defineProps({
  initialCode: { type: String, default: '' },
  initialName: { type: String, default: '' },
  /** Rol de la ruta (entrada directa por botón o NFC), si lo hay */
  role: { type: Object, default: null },
  message: { type: String, default: '' },
  busy: { type: Boolean, default: false },
})
const emit = defineEmits(['join'])

const code = ref(props.initialCode)
const name = ref(props.initialName)
watch(() => props.initialCode, (value) => { if (value) code.value = value })

function submit() {
  emit('join', { code: code.value, name: name.value })
}
</script>

<template>
  <section class="screen start-screen" aria-labelledby="enter-title">
    <div class="start-content">
      <div class="welcome">
        <p class="eyebrow">NASA · CENTRO DE CONTROL</p>
        <h1 id="enter-title">Únete a la <span>misión</span></h1>
        <p v-if="role" class="hint">
          Entrarás como <strong :style="{ color: role.color }">{{ role.name }}</strong>.
        </p>
        <p v-else class="hint">Introduce el código de sala y tu nombre para comenzar.</p>
      </div>

      <form class="room-form" @submit.prevent="submit">
        <label for="room-code">Código de sala</label>
        <input
          id="room-code"
          v-model="code"
          class="code-input"
          type="text"
          name="room"
          autocomplete="off"
          autocapitalize="characters"
          spellcheck="false"
          placeholder="Ej. K7MP"
          maxlength="8"
          required
        >
        <label for="player-name">Tu nombre</label>
        <input
          id="player-name"
          v-model="name"
          type="text"
          name="name"
          autocomplete="nickname"
          placeholder="Ej. Ana"
          maxlength="24"
          required
        >
        <button type="submit" :disabled="busy">Entrar en la sala <span aria-hidden="true">→</span></button>
        <p class="room-help">El código aparece en la pantalla principal.</p>
      </form>

      <p v-if="message" class="server-message error-message" role="alert">{{ message }}</p>
    </div>
  </section>
</template>
