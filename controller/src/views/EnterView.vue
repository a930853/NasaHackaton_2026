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
  'min-w-0 rounded-[5px] border border-line-strong bg-panel px-4 py-[15px] font-mono text-base text-ink focus:border-amber focus:outline-2 focus:outline-amber/25'
</script>

<template>
  <section class="screen-w flex min-h-0 flex-1 flex-col" aria-labelledby="enter-title">
    <div class="flex min-h-0 flex-1 flex-col justify-center gap-[clamp(20px,6vh,56px)] py-5 md:py-12">
      <ScreenHeading id="enter-title">
        Únete a la <span class="text-amber">misión</span>
        <template #hint>
          <template v-if="role">
            Entrarás como <strong :style="{ color: role.color }">{{ role.name }}</strong>.
          </template>
          <template v-else>Introduce el código de sala y tu nombre para comenzar.</template>
        </template>
      </ScreenHeading>

      <form class="flex max-w-[620px] flex-col gap-2.5" @submit.prevent="submit">
        <label for="room-code" class="text-sm font-semibold text-soft">Código de sala</label>
        <input
          id="room-code"
          v-model="code"
          :class="[input, 'tracking-[.2em] uppercase']"
          type="text"
          name="room"
          autocomplete="off"
          autocapitalize="characters"
          spellcheck="false"
          placeholder="Ej. K7MP"
          maxlength="8"
          required
        >
        <label for="player-name" class="mt-2 text-sm font-semibold text-soft">Tu nombre</label>
        <input
          id="player-name"
          v-model="name"
          :class="input"
          type="text"
          name="name"
          autocomplete="nickname"
          placeholder="Ej. Ana"
          maxlength="24"
          required
        >
        <button type="submit" class="btn-primary" :disabled="busy">
          Entrar en la sala <span aria-hidden="true">→</span>
        </button>
        <p class="notice">El código aparece en la pantalla principal.</p>
      </form>

      <p v-if="message" class="notice-error" role="alert">{{ message }}</p>
    </div>
  </section>
</template>
