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
</script>

<template>
  <div class="answer-area">
    <div class="question-note">
      <span aria-hidden="true">◆</span>
      <div>
        <strong>{{ view.title || 'DECISIÓN DE LA TRIPULACIÓN' }}</strong>
        <span v-if="view.prompt">{{ view.prompt }}</span>
      </div>
    </div>

    <p v-if="rejected" class="server-message error-message" role="alert">{{ rejectionText(choice.reason) }}</p>

    <div class="answer-grid" aria-label="Opciones de respuesta">
      <button
        v-for="(option, index) in view.options ?? []"
        :key="option.id"
        class="answer-button"
        :class="{ selected: sending && choice.optionId === option.id }"
        :disabled="sending"
        type="button"
        @click="emit('choose', option.id)"
      >
        <span class="answer-number">{{ index + 1 }}</span>
        <span>{{ option.label }}</span>
        <span class="answer-check" aria-hidden="true">{{ sending && choice.optionId === option.id ? '…' : '→' }}</span>
      </button>
    </div>

    <p v-if="sending" class="server-message" role="status">Enviando…</p>
  </div>
</template>
