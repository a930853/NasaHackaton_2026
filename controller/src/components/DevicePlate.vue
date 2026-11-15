<script setup>
// Placa de identidad del aparato: casco del color del rol, quién eres y el código de sala.
// Antes de tener rol, el casco va blanco y la placa lleva el nombre del juego.
defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  code: { type: String, default: '' },
})
</script>

<template>
  <header class="plate">
    <span class="helmet size-12" aria-hidden="true" />
    <div class="min-w-0 flex-1">
      <p class="display text-[clamp(12px,3.3vw,19px)] text-ink">{{ title }}</p>
      <p v-if="subtitle" class="truncate text-[15px] text-ink/75">{{ subtitle }}</p>
    </div>
    <span v-if="code" class="lcd" :aria-label="`Room ${code}`">{{ code }}</span>
  </header>
</template>
