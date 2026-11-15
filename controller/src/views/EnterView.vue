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
  <section class="flex flex-1 flex-col gap-5" aria-labelledby="enter-title">
    <form class="flex flex-col gap-5" @submit.prevent="submit">
      <div class="screen screen-padding flex flex-col gap-4">
        <div>
          <h1 id="enter-title" class="text-[clamp(22px,6.5vw,28px)] leading-tight font-bold">Join the crew</h1>
          <p class="mt-1 text-glass-dim">
            <template v-if="role">You will be the <strong :style="{ color: role.color }">{{ role.name }}</strong>.</template>
            <template v-else>The room code is on the main screen.</template>
          </p>
        </div>

        <label class="flex flex-col gap-1.5">
          <span class="font-bold">Room code</span>
          <input
            v-model="code"
            class="field display tracking-[.18em] uppercase"
            type="text"
            name="room"
            autocomplete="off"
            autocapitalize="characters"
            spellcheck="false"
            placeholder="K7MP"
            maxlength="8"
            required
          >
        </label>
        <label class="flex flex-col gap-1.5">
          <span class="font-bold">Your name</span>
          <input
            v-model="name"
            class="field"
            type="text"
            name="name"
            autocomplete="nickname"
            placeholder="Ana"
            maxlength="24"
            required
          >
      </label>

      </div>

      <button type="submit" class="key text-center text-lg" :disabled="busy">
        {{ busy ? 'Connecting…' : 'Join the room' }}
      </button>
    </form>

    <p v-if="message" class="alert" role="alert">{{ message }}</p>
  </section>
</template>
