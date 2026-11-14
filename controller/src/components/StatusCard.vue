<script setup>
// Tarjeta de estado: espera, decisión registrada, resultado, sala cerrada…
defineProps({
  mark: { type: String, default: '◷' },
  eyebrow: { type: String, default: '' },
  title: { type: String, required: true },
  text: { type: String, default: '' },
})
</script>

<template>
  <div class="waiting-screen" role="status" aria-live="polite">
    <div class="waiting-mark" aria-hidden="true">{{ mark }}</div>
    <p v-if="eyebrow" class="eyebrow">{{ eyebrow }}</p>
    <h2>{{ title }}</h2>
    <p v-if="text" class="status-text">{{ text }}</p>
    <slot />
  </div>
</template>
