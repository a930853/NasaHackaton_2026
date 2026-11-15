<script setup>
// Pregunta y opciones enviadas por Godot (controller_view con screen: "choice").
// `detail` (coste), `disabled` y `reason` son campos opcionales del contrato: se pintan tal cual.
import { computed } from 'vue'
import { rejectionText } from '../messages.js'

const props = defineProps({
  view: { type: Object, required: true },
  choice: { type: Object, required: true },
})
const emit = defineEmits(['choose'])

const sending = computed(() => props.choice.status === 'sending')
const rejected = computed(() => props.choice.status === 'rejected' && props.choice.eventId === props.view.eventId)
const isSelected = (option) => sending.value && props.choice.optionId === option.id

// Los cuatro colores de los botones del marco del juego, por orden.
const KEYS = ['var(--color-key-red)', 'var(--color-key-cyan)', 'var(--color-key-orange)', 'var(--color-key-purple)']
</script>

<template>
  <div class="flex flex-col gap-5">
    <div class="screen screen-padding">
      <h2 class="text-[clamp(21px,6vw,26px)] leading-tight font-bold text-glass">{{ view.title }}</h2>
      <p v-if="view.prompt" class="mt-1.5 text-glass-dim">{{ view.prompt }}</p>
    </div>

    <p v-if="rejected" class="alert" role="alert">{{ rejectionText(choice.reason) }}</p>

    <div class="flex flex-col gap-4 pb-1.5" role="group" :aria-label="view.prompt || view.title">
      <button
        v-for="(option, index) in view.options ?? []"
        :key="option.id"
        type="button"
        class="key flex items-start gap-3"
        :class="option.disabled ? 'key-off' : ''"
        :style="option.disabled ? null : { '--key': KEYS[index % KEYS.length] }"
        :aria-pressed="isSelected(option)"
        :disabled="sending || option.disabled === true"
        @click="emit('choose', option.id)"
      >
        <span
          class="grid size-8 shrink-0 place-items-center rounded-full border-[3px] border-ink bg-screen font-display text-xs text-glass"
          aria-hidden="true"
        >
          {{ index + 1 }}
        </span>
        <span class="flex min-w-0 flex-1 flex-col gap-1">
          <span class="text-[18px] leading-snug">{{ option.label }}</span>
          <span v-if="option.detail" class="text-[15px] leading-snug font-normal text-ink/80">{{ option.detail }}</span>
          <span v-if="option.disabled && option.reason" class="text-[15px] leading-snug font-normal">{{ option.reason }}</span>
        </span>
      </button>
    </div>

    <p v-if="sending" class="text-center font-bold text-ink" role="status">Sending your vote…</p>
  </div>
</template>
