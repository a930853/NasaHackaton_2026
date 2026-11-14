<script setup>
// Entrada a la sala: código (precargado desde ?room=) y nombre.
import { ref, watch } from 'vue'
import ScreenHeading from '../components/ScreenHeading.vue'

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

const input =
  'min-w-0 rounded-[12px] border-[3px] border-line bg-panel px-4 py-[14px] font-mono text-base text-ink placeholder:text-muted/60 focus:border-amber focus:outline-none focus:shadow-[0_0_14px_rgb(255_168_38/.5)]'
</script>

<template>
  <section class="screen-w flex min-h-0 flex-1 flex-col" aria-labelledby="enter-title">
    <div class="flex min-h-0 flex-1 flex-col justify-center gap-[clamp(20px,6vh,56px)] py-5 md:py-12">
      <ScreenHeading id="enter-title">
        Join the <span class="text-amber">mission</span>
        <template #hint>
          <template v-if="role">
            You will join as the <strong :style="{ color: role.color }">{{ role.name }}</strong>.
          </template>
          <template v-else>Type the room code and your name to start.</template>
        </template>
      </ScreenHeading>

      <form class="screen-panel flex w-full max-w-[620px] flex-col gap-2.5 p-6" @submit.prevent="submit">
        <label for="room-code" class="text-sm font-semibold text-soft">Room code</label>
        <input
          id="room-code"
          v-model="code"
          :class="[input, 'tracking-[.2em] uppercase']"
          type="text"
          name="room"
          autocomplete="off"
          autocapitalize="characters"
          spellcheck="false"
          placeholder="e.g. K7MP"
          maxlength="8"
          required
        >
        <label for="player-name" class="mt-2 text-sm font-semibold text-soft">Your name</label>
        <input
          id="player-name"
          v-model="name"
          :class="input"
          type="text"
          name="name"
          autocomplete="nickname"
          placeholder="e.g. Ana"
          maxlength="24"
          required
        >
        <button type="submit" class="btn-primary" :disabled="busy">
          Join the room <span aria-hidden="true">→</span>
        </button>
        <p class="notice">The code is on the main screen.</p>
      </form>

      <p v-if="message" class="notice-error" role="alert">{{ message }}</p>
    </div>
  </section>
</template>
