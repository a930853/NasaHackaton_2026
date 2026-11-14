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
const answerColors = ['#f5235c', '#14b9ef', '#ffae16', '#8d4de8']
</script>

<template>
  <div class="answer-panel flex min-h-0 flex-1 flex-col justify-center gap-2">
    <p v-if="rejected" class="notice-error" role="alert">{{ rejectionText(choice.reason) }}</p>

    <div class="answer-grid grid grid-cols-2 gap-3.5" aria-label="Opciones de respuesta">
      <button
        v-for="(option, index) in view.options ?? []"
        :key="option.id"
        type="button"
        class="answer-button flex min-h-24 cursor-pointer items-center justify-center p-[clamp(18px,2.5vw,32px)] text-center font-mono text-[clamp(13px,1.5vw,18px)] font-medium tracking-[.04em] transition duration-200 enabled:hover:-translate-y-[3px] focus-visible:outline-none disabled:cursor-wait"
        :class="[isSelected(option) ? 'answer-button-selected' : '', option.disabled ? 'answer-button-blocked' : '']"
        :style="{ '--answer-color': answerColors[index % answerColors.length] }"
        :disabled="sending || option.disabled === true"
        @click="emit('choose', option.id)"
      >
        <span class="flex flex-col gap-1.5">
          <span>{{ option.label }}</span>
          <!-- Campos opcionales del contrato: coste de la opción y por qué está bloqueada -->
          <small v-if="option.detail" class="answer-detail">{{ option.detail }}</small>
          <small v-if="option.disabled && option.reason" class="answer-reason">{{ option.reason }}</small>
        </span>
      </button>
    </div>

    <p v-if="sending" class="notice" role="status">Enviando…</p>
  </div>
</template>
