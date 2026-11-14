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
  'entry-control min-w-0 px-4 py-[clamp(10px,2vh,15px)] font-mono text-[clamp(14px,2vw,16px)] text-ink focus:outline-2 focus:outline-amber/25'
</script>

<template>
  <section class="enter-screen screen-w flex min-h-0 flex-1 flex-col" aria-labelledby="enter-title">
    <div class="enter-content flex min-h-0 flex-1 flex-col justify-center gap-[clamp(8px,2vh,18px)] py-[clamp(8px,2vh,24px)]">
      <div class="enter-header">
        <div class="mission-brand" aria-label="NASA">
          <svg viewBox="0 0 100 100" role="img" aria-hidden="true">
            <circle cx="50" cy="50" r="44" fill="#1262a8" />
            <path d="M12 61C34 48 59 38 88 17C64 45 39 62 13 73" fill="none" stroke="#ef3340" stroke-width="4" />
            <path d="M20 71C42 37 60 22 82 18C58 32 42 51 28 78" fill="none" stroke="#fff" stroke-width="1.5" />
            <text x="50" y="59" fill="#fff" font-family="Georgia, serif" font-size="21" font-weight="700" text-anchor="middle">NASA</text>
          </svg>
        </div>
        <ScreenHeading id="enter-title">
          Únete a la <span class="text-amber">misión</span>
          <template #hint>
            <template v-if="role">
              Entrarás como <strong :style="{ color: role.color }">{{ role.name }}</strong>.
            </template>
            <template v-else>Introduce el código de sala y tu nombre para comenzar.</template>
          </template>
        </ScreenHeading>
      </div>

      <form class="entry-form mx-auto flex w-full max-w-[620px] flex-col gap-2.5" @submit.prevent="submit">
        <label for="room-code" class="text-[clamp(12px,1.5vw,14px)] font-semibold text-soft">Código de sala</label>
        <input
          id="room-code"
          v-model="code"
          :class="[input, 'entry-code tracking-[.2em] uppercase']"
          type="text"
          name="room"
          autocomplete="off"
          autocapitalize="characters"
          spellcheck="false"
          placeholder="Ej. K7MP"
          maxlength="8"
          required
        >
        <label for="player-name" class="mt-2 text-[clamp(12px,1.5vw,14px)] font-semibold text-soft">Tu nombre</label>
        <input
          id="player-name"
          v-model="name"
          :class="[input, 'entry-name']"
          type="text"
          name="name"
          autocomplete="nickname"
          placeholder="Ej. Ana"
          maxlength="24"
          required
        >
        <button type="submit" class="entry-submit" :disabled="busy">
          <span>Entrar en la sala <span aria-hidden="true">→</span></span>
        </button>
        <p class="notice">El código aparece en la pantalla principal.</p>
      </form>

      <p v-if="message" class="notice-error" role="alert">{{ message }}</p>
    </div>
  </section>
</template>
