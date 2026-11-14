<script setup>
// Pregunta y opciones enviadas por Godot (controller_view con screen: "choice").
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
</script>

<template>
  <div class="flex flex-col gap-6 py-[clamp(16px,3vh,32px)]">
    <div>
      <p class="eyebrow text-(--role-color)">◆ DECISIÓN DE LA TRIPULACIÓN</p>
      <h2 class="text-[clamp(24px,3vw,36px)] leading-tight font-bold">{{ view.title }}</h2>
      <p v-if="view.prompt" class="mt-2 text-[15px] text-muted">{{ view.prompt }}</p>
    </div>

    <p v-if="rejected" class="notice-error" role="alert">{{ rejectionText(choice.reason) }}</p>

    <div class="grid grid-cols-2 gap-3.5" aria-label="Opciones de respuesta">
      <button
        v-for="(option, index) in view.options ?? []"
        :key="option.id"
        type="button"
        class="flex min-h-24 cursor-pointer flex-col items-start justify-between gap-[5px] rounded-[5px] border border-t-[5px] border-[#314a64] border-t-(--role-color) p-[clamp(10px,1.5vw,18px)] text-left font-mono text-[clamp(11px,1.3vw,14px)] tracking-[.06em] transition duration-200 enabled:hover:-translate-y-[3px] enabled:hover:bg-(--role-pale) enabled:hover:text-(--role-dark) focus-visible:outline-none disabled:cursor-wait"
        :class="isSelected(option) ? 'bg-(--role-pale) text-(--role-dark)' : 'bg-panel text-ink disabled:opacity-45'"
        :disabled="sending"
        @click="emit('choose', option.id)"
      >
        <span class="grid size-[26px] place-items-center rounded-full bg-(--role-color) font-sans text-sm font-bold text-navy">
          {{ index + 1 }}
        </span>
        <span>{{ option.label }}</span>
        <span class="self-end text-[22px] text-(--role-color)" aria-hidden="true">{{ isSelected(option) ? '…' : '→' }}</span>
      </button>
    </div>

    <p v-if="sending" class="notice" role="status">Enviando…</p>
  </div>
</template>
