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

// Los mismos neones que los botones del marco del juego (rojo, cian, naranja, morado).
const NEONS = ['var(--color-neon-red)', 'var(--color-neon-cyan)', 'var(--color-neon-orange)', 'var(--color-neon-purple)']
</script>

<template>
  <div class="flex flex-col gap-6 py-[clamp(16px,3vh,32px)]">
    <div class="screen-panel px-6 py-5">
      <p class="eyebrow text-(--role-color)">◆ CREW DECISION</p>
      <h2 class="text-[clamp(22px,3vw,34px)] leading-tight font-bold">{{ view.title }}</h2>
      <p v-if="view.prompt" class="mt-2 text-[15px] text-muted">{{ view.prompt }}</p>
    </div>

    <p v-if="rejected" class="notice-error" role="alert">{{ rejectionText(choice.reason) }}</p>

    <div class="grid gap-4 sm:grid-cols-2" aria-label="Options">
      <button
        v-for="(option, index) in view.options ?? []"
        :key="option.id"
        type="button"
        class="neon-button flex min-h-20 flex-col items-start gap-1.5 p-[clamp(12px,1.8vw,18px)] text-left"
        :class="isSelected(option) ? 'bg-panel-hover' : ''"
        :style="{ '--neon': NEONS[index % NEONS.length] }"
        :disabled="sending || option.disabled === true"
        @click="emit('choose', option.id)"
      >
        <span class="flex w-full items-start gap-3">
          <span
            class="grid size-7 shrink-0 place-items-center rounded-full border-2 border-outline bg-(--neon) font-mono text-sm font-bold text-outline"
            aria-hidden="true"
          >
            {{ index + 1 }}
          </span>
          <span class="flex-1 text-[clamp(15px,1.6vw,18px)] leading-snug font-semibold">{{ option.label }}</span>
          <span v-if="isSelected(option)" class="text-(--neon)" aria-hidden="true">…</span>
        </span>
        <small v-if="option.detail" class="pl-10 font-mono text-[12px] leading-snug text-muted">{{ option.detail }}</small>
        <small v-if="option.disabled && option.reason" class="pl-10 font-mono text-[12px] leading-snug text-danger">
          {{ option.reason }}
        </small>
      </button>
    </div>

    <p v-if="sending" class="notice" role="status">Sending…</p>
  </div>
</template>
